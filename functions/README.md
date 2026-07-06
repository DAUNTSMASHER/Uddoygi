# Uddyogi ERP Pro - AI Cloud Functions & Storage Suite

This directory contains production-ready Firebase Cloud Functions that integrate **Firestore**, **Google Gemini AI**, and **Firebase Cloud Storage** to power intelligent executive analytics for any company in Uddyogi ERP.

## 🚀 What This Does
1. **`analyzeCompanyData` (Callable Cloud Function)**:
   - Reads the last several months of **Invoices**, **Work Orders**, **Operating Expenses**, and **Inventory Stock** from Firestore for a specific `companyId`.
   - Performs statistical aggregation (Total Revenue, Unpaid Receivables, Work Order Completion Velocity, Critical Low Stock Alerts).
   - Feeds this live financial snapshot into **Google Gemini 3 Flash** with your custom question (e.g., *"How to improve sales this month?"*).
   - Generates an actionable CFO/COO strategy report and **caches it directly into Firebase Cloud Storage** (`gs://<bucket>/ai_reports/{companyId}/latest_strategy_report.json`).

2. **`generateMonthlyAIStrategyAudit` (Scheduled Cron Job)**:
   - Runs automatically on the 1st of every month at 2:00 AM.
   - Audits all active company databases and archives a structured executive audit report into Firebase Storage.

---

## 🛠 How to Deploy (Requires Firebase Blaze Plan)

Since you have already enabled the **Blaze (Pay as you go)** plan in your Firebase Console, deploying takes only a minute:

1. Open a terminal in the `functions` directory (or root project):
   ```bash
   cd functions
   npm install
   ```

2. Deploy the functions to Firebase:
   ```bash
   firebase deploy --only functions
   ```

3. **Verify in Firebase Console**:
   - Go to **Firebase Console → Functions**. You will see `analyzeCompanyData` and `generateMonthlyAIStrategyAudit` live and active.
   - Go to **Firebase Console → Storage**. Reports will automatically be created in the `ai_reports/` folder when triggered!
