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
const GEMINI_PROXY_URL = sanitizeEnvValue(import.meta.env.VITE_GEMINI_PROXY_URL);
const APP_SHARED_SECRET = sanitizeEnvValue(import.meta.env.VITE_APP_SHARED_SECRET);
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
// Download image from URL and convert to base64
// ---------------------------------------------------------------------------
async function urlToBase64(url) {
  try {
    const response = await fetch(url);
    const blob = await response.blob();
    return await fileToBase64(blob);
  } catch (error) {
    console.error("Failed to download image:", error);
    throw new Error("Failed to download image for extraction");
  }
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
  if (!GEMINI_PROXY_URL || !APP_SHARED_SECRET) {
    throw new Error(
      "Gemini proxy is not configured. Please set VITE_GEMINI_PROXY_URL and VITE_APP_SHARED_SECRET in your environment variables, or enter CPR details manually."
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
    GEMINI_PROXY_URL,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-App-Secret": APP_SHARED_SECRET,
      },
      body: JSON.stringify({
        model: GEMINI_MODEL,
        ...body,
      }),
    }
  );

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const errorMsg = err.error?.message || "";

    if (res.status === 401 || res.status === 403) {
      throw new Error(
        `Gemini proxy authentication failed: ${errorMsg || "Please verify your VITE_GEMINI_PROXY_URL and VITE_APP_SHARED_SECRET in .env, or use manual entry below."}`
      );
    }

    if (res.status === 429 || res.status === 503) {
      throw new Error(
        `Gemini service is temporarily busy (${res.status}): ${errorMsg || "Please wait a moment and try again, or enter CPR details manually."}`
      );
    }

    throw new Error(errorMsg || "Gemini proxy request failed. Please try again or enter details manually.");
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

// ---------------------------------------------------------------------------
// Retry OCR extraction for a report using its image URLs
// ---------------------------------------------------------------------------
export async function retryReportExtraction(reportId, frontImageUrl, backImageUrl, additionalBackImageUrls = []) {
  if (!GEMINI_PROXY_URL || !APP_SHARED_SECRET) {
    throw new Error(
      "Gemini proxy is not configured. Please set VITE_GEMINI_PROXY_URL and VITE_APP_SHARED_SECRET in your environment variables."
    );
  }

  try {
    // Download images and convert to base64
    let frontBytes = "";
    let backBytes = "";
    let additionalBackBytesList = [];

    if (frontImageUrl) {
      frontBytes = await urlToBase64(frontImageUrl);
    }

    if (backImageUrl) {
      backBytes = await urlToBase64(backImageUrl);
    }

    for (const url of additionalBackImageUrls) {
      if (url) {
        const bytes = await urlToBase64(url);
        additionalBackBytesList.push(bytes);
      }
    }

    // Build prompt for product extraction
    const prompt = `You are reading two photos of a packaged food product sold in the Philippines: the FRONT of the package (first image) and the BACK/nutrition label (second image). Extract the following as strict JSON -- no markdown fences, no commentary, just the JSON object.

Return exactly this shape:
{
  "brand": "",
  "product_name": "",
  "size": "",
  "serving_size": "",
  "ingredients": [],
  "nutrition_per_100g": {
    "energy_kcal": null,
    "protein_g": null,
    "carbs_g": null,
    "fat_total_g": null,
    "fat_saturated_g": null,
    "fat_trans_g": null,
    "sodium_mg": null,
    "potassium_mg": null,
    "calcium_mg": null,
    "iron_mg": null,
    "fiber_g": null,
    "sugars_g": null,
    "added_sugars_g": null
  },
  "allergens": [],
  "confidence_notes": ""
}

Rules:
- "ingredients": split the ingredients list into individual items, in the order printed on the package. Keep each item as printed (don't translate).
- "nutrition_per_100g": read values as printed. If the label states values per serving rather than per 100g, convert using the stated serving size. If a field is genuinely not visible/printed, use null -- do NOT guess or estimate a plausible-looking number.
- "allergens": only choose from: Milk, Eggs, Fish, Shellfish, Tree Nuts, Peanuts, Wheat, Soy, Sesame based on TWO sources only: 1) The actual ingredients list, and 2) "May contain" or "May contain traces of" statements. DO NOT include allergens from facility warnings. If the label mentions an allergen-relevant ingredient not on this list, note it in "confidence_notes" instead.
- "confidence_notes": briefly flag anything unclear, blurry, or ambiguous in either photo that a human reviewer should double-check against the actual package. Leave empty if nothing stood out.
- If the back label is missing, blurry, or unreadable, still fill in what the front photo gives you (brand, product_name, size), leave nutrition/ingredients/allergens empty, and say so in "confidence_notes".`;

    // Build request body
    const parts = [{ text: prompt }];

    if (frontBytes) {
      parts.push({
        inline_data: {
          mime_type: "image/jpeg",
          data: frontBytes,
        },
      });
    }

    if (backBytes) {
      parts.push({
        inline_data: {
          mime_type: "image/jpeg",
          data: backBytes,
        },
      });
    }

    for (const extraBytes of additionalBackBytesList) {
      if (extraBytes) {
        parts.push({
          inline_data: {
            mime_type: "image/jpeg",
            data: extraBytes,
          },
        });
      }
    }

    const body = {
      model: GEMINI_MODEL,
      contents: [
        { parts: parts },
      ],
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.1,
        maxOutputTokens: 8192,
      },
    };

    // Call Cloudflare worker
    const res = await fetch(GEMINI_PROXY_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-App-Secret": APP_SHARED_SECRET,
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const errorMsg = await res.text();
      throw new Error(`Gemini proxy request failed: ${errorMsg}`);
    }

    const data = await res.json();
    const candidates = data?.candidates;
    const content = candidates?.[0]?.content;
    const resultParts = content?.parts;
    const text = resultParts?.[0]?.text;

    if (!text) {
      throw new Error("No response text from Gemini");
    }

    // Parse the JSON response
    const cleaned = text.replace(/```json/gi, "").replace(/```/g, "").trim();
    let parsed;
    try {
      parsed = JSON.parse(cleaned);
    } catch (e) {
      throw new Error("Failed to parse Gemini response as JSON");
    }

    // Convert to the expected format for Firestore
    const extractedData = {
      brand: parsed.brand || "",
      productName: parsed.product_name || "",
      size: parsed.size || "",
      servingSize: parsed.serving_size || "",
      ingredients: parsed.ingredients || [],
      allergens: parsed.allergens || [],
      nutrition: parsed.nutrition_per_100g || {},
      hasNutritionData: Object.keys(parsed.nutrition_per_100g || {}).length > 0,
      confidenceNotes: parsed.confidence_notes || "",
    };

    // Update the report in Firestore
    const reportRef = doc(db, "reports", reportId);
    await updateDoc(reportRef, {
      extractedData: extractedData,
    });

    return extractedData;
  } catch (error) {
    console.error("Retry extraction error:", error);
    throw error;
  }
}
