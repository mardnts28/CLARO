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

export async function approveReport(reportId) {
  const reportRef = doc(db, "reports", reportId);
  const reportSnap = await getDoc(reportRef);
  if (!reportSnap.exists()) throw { code: "report/not-found" };

  const reportData = reportSnap.data();

  await updateDoc(reportRef, { status: "Approve" });

  await setDoc(doc(db, "approved_unknown_product_reports", reportId), {
    ...reportData,
    status: "Approve",
    approvedAt: Timestamp.now(),
  });

  await logActivity("Approved Report", reportId, "report", reportData.productName);
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