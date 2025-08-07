const admin = require("firebase-admin");
const fs = require("fs");

// 🔐 Replace with your Firebase service account path
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function initializeTodayAttendance() {
  const today = new Date();
  const formattedDate = today.toISOString().split("T")[0]; // yyyy-mm-dd
  const attendanceRef = db.collection("attendance").doc(formattedDate).collection("records");

  const usersSnapshot = await db.collection("users").get();
  const batch = db.batch();

  let addedCount = 0;

  usersSnapshot.forEach((doc) => {
    const user = doc.data();
    const empId = user.employeeId;
    if (!empId) return;

    const ref = attendanceRef.doc(empId);

    batch.set(ref, {
      employeeId: empId,
      email: user.email || "",
      name: user.name || "",
      department: user.department || "",
      status: "present", // ✅ Default can be "present"
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      markedBy: "system", // or HR email if available
    });

    console.log(`✅ Prepared attendance record for ${empId}`);
    addedCount++;
  });

  if (addedCount === 0) {
    console.log("⚠️ No users found to initialize attendance.");
  } else {
    await batch.commit();
    console.log(`✅ Attendance initialized for ${addedCount} employees on ${formattedDate}`);
  }
}

initializeTodayAttendance().catch(console.error);
