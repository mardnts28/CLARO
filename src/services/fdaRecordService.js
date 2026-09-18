import {
  collection,
  getDocs,
  doc,
  updateDoc,
  Timestamp,
} from "firebase/firestore";
import { db } from "../firebase/firebase";
import { logActivity } from "./logService";

// Sanitize environment variables to prevent non-ASCII / ISO-8859-1 header errors in fetch
function sanitizeEnvValue(val, fallback = "") {
  if (!val) return fallback;
  return (
    String(val)
      .replace(/[\u2018\u2019\u201A\u201B\u2032\u2035]/g, "") // curly single quotes
      .replace(/[\u201C\u201D\u201E\u201F\u2033\u2036]/g, "") // curly double quotes
      .replace(/[\u200B-\u200D\uFEFF]/g, "") // zero-width spaces / BOM
      .replace(/[^\x20-\x7E]/g, "") // strip characters outside printable ASCII
      .trim() || fallback
  );
}

const CLOUDINARY_CLOUD_NAME = sanitizeEnvValue(import.meta.env.VITE_CLOUDINARY_CLOUD_NAME);
const CLOUDINARY_UPLOAD_PRESET = sanitizeEnvValue(import.meta.env.VITE_CLOUDINARY_UPLOAD_PRESET);
const GEMINI_API_KEY = sanitizeEnvValue(import.meta.env.VITE_GEMINI_API_KEY);
const GEMINI_MODEL = sanitizeEnvValue(import.meta.env.VITE_GEMINI_MODEL, "gemini-3.5-flash");

export const MAX_FDA_SCREENSHOT_SIZE_MB = 10;
const MAX_FDA_SCREENSHOT_BYTES = MAX_FDA_SCREENSHOT_SIZE_MB * 1024 * 1024;

// ---------------------------------------------------------------------------
// Upload FDA screenshot to Cloudinary
// Returns the secure public URL of the uploaded image.
// ---------------------------------------------------------------------------
export async function uploadFdaScreenshot(file) {
  if (file && file.size > MAX_FDA_SCREENSHOT_BYTES) {
    throw new Error(
      `Screenshot exceeds the maximum allowed size of ${MAX_FDA_SCREENSHOT_SIZE_MB} MB.`
    );
  }

  const formData = new FormData();
  formData.append("file", file);
  formData.append("upload_preset", CLOUDINARY_UPLOAD_PRESET);
  formData.append("folder", "claro-fda-screenshots");

  const res = await fetch(
    `https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/image/upload`,
    { method: "POST", body: formData }
  );

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error?.message || "Cloudinary upload failed.");
  }

  const data = await res.json();
  return data.secure_url;
}

// ---------------------------------------------------------------------------
// Convert a File/Blob to a base64 data string (without the data URL prefix)
// ---------------------------------------------------------------------------
function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const base64 = reader.result.split(",")[1];
      resolve(base64);
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

// ---------------------------------------------------------------------------
// Use Gemini Vision to extract CPR number, validity date, and verify alignment
// with the selected target product from an FDA Philippine Verification Portal screenshot.
//
// Returns: {
//   cprNumber: string,
//   validityDate: string,
//   detectedProduct: string,
//   aligns: boolean,
//   mismatchReason: string,
//   lowConfidence: boolean
// }
// ---------------------------------------------------------------------------
export async function extractFdaDataWithGemini(imageFile, targetProduct = null) {
  if (!GEMINI_API_KEY) {
    throw new Error(
      "Gemini API key is not configured. Please set VITE_GEMINI_API_KEY in your environment variables, or enter CPR details manually."
    );
  }

  if (imageFile && imageFile.size > MAX_FDA_SCREENSHOT_BYTES) {
    throw new Error(
      `Screenshot exceeds the maximum allowed size of ${MAX_FDA_SCREENSHOT_SIZE_MB} MB.`
    );
  }

  const base64 = await fileToBase64(imageFile);

  const productName =
    typeof targetProduct === "object"
      ? targetProduct?.name || targetProduct?.product_name || ""
      : (targetProduct || "");
  const productBrand =
    typeof targetProduct === "object" ? targetProduct?.brand || "" : "";

  const targetContext = productName
    ? `Target Product to update: "${productName}"${productBrand ? ` (Brand: "${productBrand}")` : ""}
Task: The screenshot may contain ONE row or a table with MULTIPLE rows of FDA registration records.
1. Scan all rows in the table.
2. Locate the row that matches or best corresponds to the target product ("${productName}").
3. Extract the CPR Number and Validity Date from that specific matching row.
4. If a matching row is found, set "aligns": true and "detectedProduct" to the matching row description.
5. If NONE of the rows in the screenshot match the target product, set "aligns": false and describe what products were found in "mismatchReason".`
    : `Task: Identify the product record shown in the screenshot. If multiple rows exist, extract the first valid product registration.`;

  const prompt = `You are analyzing a screenshot from the FDA Philippines Verification Portal (verification.fda.gov.ph).

${targetContext}

Extraction Rules:
1. CPR Number: Certificate of Product Registration number (e.g. starting with FR-...) from the matching row.
2. Validity Date: Expiry or validity date from the matching row; format strictly as YYYY-MM-DD.
3. Detected Product: The exact product name and brand as shown in the matching row.
4. Alignment Check:
   - Set "aligns": true if a row in the screenshot matches or is a valid packaging/export/flavor variant of the target product (e.g. "SARDINES IN TOMATO SAUCE - FOR EXPORT" matches "555 Sardines in Tomato Sauce").
   - Set "aligns": false if no row in the screenshot corresponds to the target product (e.g. screenshot contains only Tuna or other brands).
   - If no target product was provided or text is too unreadable, set "aligns": true and "lowConfidence": true.
5. Mismatch Reason: If "aligns" is false, provide a concise explanation (e.g. "The screenshot shows sardine products under brands MEGA, LIGO, SAYANG, but no record for 'Century Tuna Flakes'."). If "aligns" is true, provide an empty string "".

Return your answer as a JSON object with this exact shape:
{
  "cprNumber": "<the CPR number from the matching row, or empty string>",
  "validityDate": "<date in YYYY-MM-DD format from the matching row, or empty string>",
  "detectedProduct": "<product and brand text from the matching row>",
  "aligns": <true or false>,
  "mismatchReason": "<explanation if aligns is false, else empty string>",
  "lowConfidence": <true if text is blurry or uncertain, false otherwise>
}

Return ONLY the JSON object. Do not include markdown code block backticks or explanation.`;

  const body = {
    contents: [
      {
        parts: [
          {
            inlineData: {
              mimeType: imageFile.type || "image/png",
              data: base64,
            },
          },
          { text: prompt },
        ],
      },
    ],
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 8192,
      thinkingConfig: {
        thinkingLevel: "MINIMAL",
      },
    },
  };

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const errorMsg = err.error?.message || "";

    if (res.status === 401 || res.status === 403) {
      throw new Error(
        `Gemini API authentication failed: ${errorMsg || "Please verify your VITE_GEMINI_API_KEY in .env, or use manual entry below."}`
      );
    }

    if (res.status === 429 || res.status === 503) {
      throw new Error(
        `Gemini service is temporarily busy (${res.status}): ${errorMsg || "Please wait a moment and try again, or enter CPR details manually."}`
      );
    }

    throw new Error(errorMsg || "Gemini OCR request failed. Please try again or enter details manually.");
  }

  const data = await res.json();
  const parts = data?.candidates?.[0]?.content?.parts || [];
  // In Gemini 3.5 Flash, parts[0] may contain the internal reasoning ({ thought: true }).
  // Extract the actual final output part.
  const contentPart = parts.find((p) => !p.thought && p.text) || parts[parts.length - 1];
  const rawText = contentPart?.text || "";

  const cleaned = rawText
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    return {
      cprNumber: "",
      validityDate: "",
      detectedProduct: "",
      aligns: true,
      mismatchReason: "",
      lowConfidence: true,
    };
  }

  return {
    cprNumber: (parsed.cprNumber || "").trim(),
    validityDate: (parsed.validityDate || "").trim(),
    detectedProduct: (parsed.detectedProduct || "").trim(),
    aligns: parsed.aligns !== false,
    mismatchReason: (parsed.mismatchReason || "").trim(),
    lowConfidence: Boolean(parsed.lowConfidence),
  };
}

// ---------------------------------------------------------------------------
// Fetch all catalog products from `fda_products` for the FDA Records management.
// ---------------------------------------------------------------------------
export async function getAllProducts() {
  const snapshot = await getDocs(collection(db, "fda_products"));
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
}

// ---------------------------------------------------------------------------
// Update a product's FDA registration details with screenshot and OCR data.
// ---------------------------------------------------------------------------
export async function updateProductFdaRecord(
  productId,
  { cprNumber, validityDate, screenshotFile, productName = "" }
) {
  let fdaScreenshotUrl = "";
  if (screenshotFile) {
    fdaScreenshotUrl = await uploadFdaScreenshot(screenshotFile);
  }

  const validityTimestamp = validityDate
    ? Timestamp.fromDate(new Date(validityDate))
    : null;

  const productRef = doc(db, "fda_products", productId);
  const updatePayload = {
    cpr_number: (cprNumber || "").trim(),
    validity_date: validityTimestamp,
    registration_status: Boolean(cprNumber?.trim() && validityTimestamp),
    updated_at: Timestamp.now(),
  };

  if (fdaScreenshotUrl) {
    updatePayload.fda_screenshot_url = fdaScreenshotUrl;
  }

  await updateDoc(productRef, updatePayload);

  try {
    await logActivity(
      "Updated FDA Record",
      productId,
      "product",
      productName || cprNumber
    );
  } catch (e) {
    console.warn("Could not log activity:", e);
  }

  return { ...updatePayload, fdaScreenshotUrl };
}

// Backward compatibility alias
export const getAllFdaRecords = getAllProducts;

// ---------------------------------------------------------------------------
// Calculate the FDA CPR expiration status for a product.
// Threshold defaults to 60 days.
// ---------------------------------------------------------------------------
export function getProductCprExpiration(product, daysThreshold = 60) {
  if (!product) {
    return {
      status: "needs_cpr",
      label: "Needs CPR",
      daysLeft: null,
      isExpired: false,
      isExpiringSoon: false,
      isVerified: false,
      urgency: "none",
    };
  }

  const hasCpr = Boolean(product.cpr_number?.trim());
  const rawDate = product.validity_date;

  if (!hasCpr || !rawDate) {
    return {
      status: "needs_cpr",
      label: "Needs CPR",
      daysLeft: null,
      isExpired: false,
      isExpiringSoon: false,
      isVerified: false,
      urgency: "none",
    };
  }

  const dateObj = rawDate.toDate ? rawDate.toDate() : new Date(rawDate);
  if (isNaN(dateObj.getTime())) {
    return {
      status: "needs_cpr",
      label: "Needs CPR",
      daysLeft: null,
      isExpired: false,
      isExpiringSoon: false,
      isVerified: false,
      urgency: "none",
    };
  }

  const now = new Date();
  const targetMidnight = new Date(
    dateObj.getFullYear(),
    dateObj.getMonth(),
    dateObj.getDate()
  );
  const nowMidnight = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate()
  );
  const diffDays = Math.ceil(
    (targetMidnight.getTime() - nowMidnight.getTime()) / (1000 * 60 * 60 * 24)
  );

  if (diffDays < 0) {
    return {
      status: "expired",
      label: "Expired",
      daysLeft: diffDays,
      daysAgo: Math.abs(diffDays),
      isExpired: true,
      isExpiringSoon: false,
      isVerified: false,
      urgency: "critical",
    };
  }

  if (diffDays <= daysThreshold) {
    return {
      status: "expiring_soon",
      label: "Expiring Soon",
      daysLeft: diffDays,
      isExpired: false,
      isExpiringSoon: true,
      isVerified: true,
      urgency: diffDays <= 15 ? "critical" : diffDays <= 30 ? "warning" : "notice",
    };
  }

  return {
    status: "verified",
    label: "Verified",
    daysLeft: diffDays,
    isExpired: false,
    isExpiringSoon: false,
    isVerified: true,
    urgency: "ok",
  };
}

// ---------------------------------------------------------------------------
// Summarize CPR expiration statuses across a list of products.
// ---------------------------------------------------------------------------
export function getCprExpirationSummary(products = [], daysThreshold = 60) {
  let expired = [];
  let expiringSoon = [];
  let verified = [];
  let needsCpr = [];

  for (const p of products) {
    const exp = getProductCprExpiration(p, daysThreshold);
    if (exp.status === "expired") {
      expired.push({ ...p, expiration: exp });
    } else if (exp.status === "expiring_soon") {
      expiringSoon.push({ ...p, expiration: exp });
    } else if (exp.status === "verified") {
      verified.push({ ...p, expiration: exp });
    } else {
      needsCpr.push({ ...p, expiration: exp });
    }
  }

  // Sort expiring and expired by urgency (earliest expiration first)
  expiringSoon.sort((a, b) => a.expiration.daysLeft - b.expiration.daysLeft);
  expired.sort((a, b) => a.expiration.daysLeft - b.expiration.daysLeft);

  const attentionList = [...expired, ...expiringSoon];

  return {
    total: products.length,
    expired,
    expiringSoon,
    verified,
    needsCpr,
    attentionList,
    attentionCount: attentionList.length,
    hasAttentionNeeded: attentionList.length > 0,
  };
}
