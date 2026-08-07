import {
  collection,
  getDocs,
  doc,
  getDoc,
  updateDoc,
  setDoc,
  query,
  orderBy,
  limit,
  Timestamp,
} from "firebase/firestore";
import { db } from "../firebase/firebase";
import { logActivity } from "./logService";

export async function getAllReports() {
  const snapshot = await getDocs(collection(db, "reports"));
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
}

export async function getReportById(reportId) {
  const ref = doc(db, "reports", reportId);
  const snap = await getDoc(ref);
  if (!snap.exists()) throw { code: "report/not-found" };

  const data = snap.data();
  await logActivity("Viewed Report", reportId, "report", data.productName);

  return { id: snap.id, ...data };
}

// "Canned Fish" -> "canned_fish", matching fda_products.product_category's
// stored format -- FirestoreProductRepository._formatCategory (Flutter app)
// reverses this same transform for display, so it must stay snake_case here.
function slugifyCategory(category) {
  return category.trim().toLowerCase().replace(/\s+/g, "_");
}

// Promotes an approved report into the live catalog -- this is what
// actually makes the product visible/scannable to end users, since
// FirestoreProductRepository (Flutter app) only ever reads from
// fda_products + product_nutrition_data, never from `reports` or
// `approved_unknown_product_reports`.
//
// Creates a NEW fda_products document (this was never a recognized
// product, so there's no existing doc id to update) and a matching
// product_nutrition_data document sharing that same generated id -- the
// same id-sharing convention tools/bulk-import/import.js uses.
//
// Note on the recognition model: promoting here makes the product
// immediately findable via search/browse (no dependency on retraining),
// but it won't be recognizable via camera scan until the image recognition
// model is retrained on a batch including this product's photos and a new
// app build ships -- see the earlier phased-plan discussion on why those
// two are intentionally decoupled.
async function promoteToLiveCatalog(finalData) {
  const ed = finalData.extractedData || {};
  const nutrition = ed.nutrition || {};

  const productRef = doc(collection(db, "fda_products"));
  const newProductId = productRef.id;

  await setDoc(productRef, {
    product_name: ed.productName || finalData.productName || "",
    brand: ed.brand || "",
    product_category: ed.category ? slugifyCategory(ed.category) : "",
    registration_status: false, // not FDA-verified through this pipeline
    cpr_number: "",
    available_sizes: ed.size ? [ed.size] : [],
    imageURL: finalData.frontImageUrl || "",
    source: "admin_approved_report",
    approvedFromReportId: finalData.id,
    promoted_at: Timestamp.now(),
  });

  await setDoc(doc(db, "product_nutrition_data", newProductId), {
    serving_size: ed.servingSize || "",
    calories_kcal: nutrition.calories_kcal ?? 0,
    protein_g: nutrition.protein_g ?? 0,
    carbs_g: nutrition.carbs_g ?? 0,
    fat_total_g: nutrition.fat_total_g ?? 0,
    fat_saturated_g: nutrition.fat_saturated_g ?? 0,
    fat_trans_g: nutrition.fat_trans_g ?? 0,
    sodium_mg: nutrition.sodium_mg ?? 0,
    potassium_mg: nutrition.potassium_mg ?? 0,
    calcium_mg: nutrition.calcium_mg ?? 0,
    iron_mg: nutrition.iron_mg ?? 0,
    fiber_g: nutrition.fiber_g ?? 0,
    sugars_g: nutrition.sugars_g ?? 0,
    added_sugars_g: nutrition.added_sugars_g ?? 0,
    allergens: ed.allergens || [],
    ingredients: ed.ingredients || [],
    source: "admin_approved_report",
    approvedFromReportId: finalData.id,
    promoted_at: Timestamp.now(),
  });

  return newProductId;
}

/// Approves a report, promoting it into `approved_unknown_product_reports`
/// AND into the live catalog (fda_products + product_nutrition_data) so it
/// actually becomes visible/usable in the app -- see promoteToLiveCatalog().
/// [correctedData] is whatever the admin edited on the review screen (see
/// ReportDetails.jsx) -- typically `{ extractedData: {...} }` with the
/// reviewer's corrections applied on top of Gemini's original extraction.
/// Fields not touched by the admin keep whatever extraction produced;
/// fields the admin did edit override it. Also writes the correction back
/// onto the `reports` doc itself, not just the approved copy, so the
/// report's record reflects what was actually verified.
export async function approveReport(reportId, correctedData = {}) {
  const reportRef = doc(db, "reports", reportId);
  const reportSnap = await getDoc(reportRef);
  if (!reportSnap.exists()) throw { code: "report/not-found" };

  const reportData = reportSnap.data();
  const finalData = { id: reportId, ...reportData, ...correctedData };

  const promotedProductId = await promoteToLiveCatalog(finalData);

  await updateDoc(reportRef, {
    ...correctedData,
    status: "Approve",
    promotedProductId,
  });

  await setDoc(doc(db, "approved_unknown_product_reports", reportId), {
    ...finalData,
    status: "Approve",
    promotedProductId,
    approvedAt: Timestamp.now(),
  });

  await logActivity("Approved Report", reportId, "report", finalData.productName);

  return { promotedProductId };
}

export async function rejectReport(reportId) {
  const reportRef = doc(db, "reports", reportId);
  const reportSnap = await getDoc(reportRef);
  const reportData = reportSnap.exists() ? reportSnap.data() : {};

  await updateDoc(reportRef, { status: "Rejected" });

  await logActivity("Rejected Report", reportId, "report", reportData.productName);
}


export async function getDashboardStats() {
  const reports = await getAllReports();
  const totalReports = reports.length;
  const pendingReports = reports.filter((r) => r.status === "Pending").length;
  return { totalReports, pendingReports };
}

export async function getRecentReports(count = 5) {
  const q = query(
    collection(db, "reports"),
    orderBy("dateSubmitted", "desc"),
    limit(count)
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
}