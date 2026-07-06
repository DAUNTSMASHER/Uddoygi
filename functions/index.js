/**
 * Uddyogi ERP Pro - AI Cloud Functions Suite
 * Uses Firebase Cloud Functions & Cloud Storage to read, aggregate, and analyze
 * company database metrics over recent months and generate strategic reports.
 */

const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { getStorage } = require("firebase-admin/storage");

admin.initializeApp();

const db = admin.firestore();
const fallbackApiKey = "AIzaSyBBsRLJ9Qoc80YrKTLx9blUlDFB0J5qpm8";

/**
 * Helper: Call Google Gemini API directly using native fetch (Node 18+)
 */
async function callGemini(prompt, apiKey) {
  const key = apiKey || process.env.GEMINI_API_KEY || fallbackApiKey;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${key}`;
  
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 2048,
      }
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Gemini API Error (${response.status}): ${errText}`);
  }

  const data = await response.json();
  return data?.candidates?.[0]?.content?.parts?.[0]?.text || "No AI insights generated.";
}

/**
 * Helper: Aggregate company database over recent months (Invoices, Work Orders, Expenses, Stock)
 */
async function aggregateCompanyData(companyId) {
  const root = db.collection("data").doc(companyId);

  // 1. Invoices & Sales Revenue (Last 90 days / 50 invoices)
  const invoicesSnap = await root.collection("invoices")
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  let totalRevenue = 0;
  let collectedRevenue = 0;
  let pendingRevenue = 0;
  let pendingInvoicesCount = 0;

  invoicesSnap.forEach((doc) => {
    const d = doc.data();
    const amt = parseFloat(d.totalAmount || d.amount || 0) || 0;
    totalRevenue += amt;
    const status = (d.status || "").toString().toLowerCase();
    if (status === "paid" || status === "completed") {
      collectedRevenue += amt;
    } else {
      pendingRevenue += amt;
      pendingInvoicesCount++;
    }
  });

  // 2. Work Orders & Production Efficiency
  const woSnap = await root.collection("work_orders")
    .orderBy("createdAt", "desc")
    .limit(30)
    .get();

  let totalOrders = woSnap.size;
  let completedOrders = 0;
  let runningOrders = 0;

  woSnap.forEach((doc) => {
    const d = doc.data();
    if (d.completed === true || (d.status || "").toLowerCase() === "completed") {
      completedOrders++;
    } else {
      runningOrders++;
    }
  });

  // 3. Products & Stock Warnings
  const prodSnap = await root.collection("products").limit(50).get();
  let totalProducts = prodSnap.size;
  const lowStockItems = [];

  prodSnap.forEach((doc) => {
    const d = doc.data();
    const stock = parseFloat(d.stock || d.quantity || 0) || 0;
    if (stock < 10) {
      lowStockItems.push(`${d.name || "Unknown Item"} (${stock} left)`);
    }
  });

  // 4. Operating Expenses
  const expSnap = await root.collection("expenses")
    .orderBy("date", "desc")
    .limit(30)
    .get();

  let totalExpenses = 0;
  expSnap.forEach((doc) => {
    const d = doc.data();
    totalExpenses += parseFloat(d.amount || d.total || 0) || 0;
  });

  return {
    companyId,
    timestamp: new Date().toISOString(),
    metrics: {
      totalRevenue: totalRevenue.toFixed(2),
      collectedRevenue: collectedRevenue.toFixed(2),
      pendingRevenue: pendingRevenue.toFixed(2),
      pendingInvoicesCount,
      totalOrders,
      completedOrders,
      runningOrders,
      totalProducts,
      lowStockItems: lowStockItems.slice(0, 10),
      totalExpenses: totalExpenses.toFixed(2),
      estimatedCashflow: (collectedRevenue - totalExpenses).toFixed(2),
    }
  };
}

/**
 * 1. HTTPS Callable Cloud Function: analyzeCompanyData
 * Triggered by the Flutter APK or Web Admin to generate an immediate CFO analysis report
 * and cache the results directly into Firebase Cloud Storage.
 */
exports.analyzeCompanyData = onCall({ cors: true }, async (request) => {
  const { companyId, prompt } = request.data || {};
  if (!companyId) {
    throw new Error("Missing required parameter: companyId");
  }

  try {
    // A. Read & aggregate Firestore database metrics
    const aggData = await aggregateCompanyData(companyId);

    // B. Build CFO Strategic Prompt
    const userPrompt = prompt || "How can we improve sales and operational efficiency this month based on our database records?";
    const aiPrompt = `
You are an expert AI CFO and Senior Management Consultant for Uddyogi ERP Pro.
Below is the real-time aggregated database snapshot for Company ID [${companyId}] over recent months:

FINANCIAL & OPERATIONAL SNAPSHOT:
- Total Invoiced Revenue: $${aggData.metrics.totalRevenue}
- Collected Cash Revenue: $${aggData.metrics.collectedRevenue}
- Unpaid / Pending Receivables: $${aggData.metrics.pendingRevenue} (${aggData.metrics.pendingInvoicesCount} invoices pending)
- Work Orders Performance: ${aggData.metrics.totalOrders} total orders (${aggData.metrics.completedOrders} completed, ${aggData.metrics.runningOrders} in production)
- Inventory SKU Count: ${aggData.metrics.totalProducts} active items
- Critical Low Stock Alerts: ${aggData.metrics.lowStockItems.length > 0 ? aggData.metrics.lowStockItems.join(", ") : "None"}
- Recent Operating Expenses: $${aggData.metrics.totalExpenses}
- Net Operating Cashflow: $${aggData.metrics.estimatedCashflow}

USER QUESTION / REQUEST: "${userPrompt}"

INSTRUCTIONS:
Analyze the figures above deeply. Provide structured, actionable recommendations:
1. Sales & Revenue Growth: Give concrete steps on collecting pending receivables and increasing sales volume.
2. Production & Work Order Speed: Identify bottlenecks or efficiency gains for active work orders.
3. Inventory & Cost Control: Address any stockout risks or expense optimization.
Format your response in clean, professional Markdown with bold bullet points.
`;

    // C. Call Gemini AI
    const aiAnalysis = await callGemini(aiPrompt);

    const reportPayload = {
      ...aggData,
      userPrompt,
      analysis: aiAnalysis,
      generatedAt: new Date().toISOString(),
    };

    // D. Cache / Save to Firebase Cloud Storage (gs://<bucket>/ai_reports/{companyId}/latest_strategy_report.json)
    try {
      const bucket = getStorage().bucket();
      const file = bucket.file(`ai_reports/${companyId}/latest_strategy_report.json`);
      await file.save(JSON.stringify(reportPayload, null, 2), {
        contentType: "application/json",
        metadata: {
          cacheControl: "public, max-age=3600",
        },
      });
    } catch (storageErr) {
      console.warn("Could not write report to Storage bucket:", storageErr.message);
    }

    return reportPayload;
  } catch (err) {
    console.error("Error in analyzeCompanyData:", err);
    throw new Error(`Failed to analyze company data: ${err.message}`);
  }
});

/**
 * 2. Scheduled Cron Function: generateMonthlyAIStrategyAudit
 * Runs on the 1st of every month to automatically audit all active companies
 * and generate stored CFO reports in Firebase Cloud Storage.
 */
exports.generateMonthlyAIStrategyAudit = onSchedule("0 2 1 * *", async (event) => {
  console.log("Starting monthly AI strategy audit for all companies...");
  try {
    const companiesSnap = await db.collection("companies").get();
    for (const doc of companiesSnap.docs) {
      const cid = doc.id;
      if (!cid) continue;
      
      console.log(`Auditing company: ${cid}`);
      const aggData = await aggregateCompanyData(cid);
      
      const aiPrompt = `
Generate a comprehensive Monthly Executive Performance Audit for Company [${cid}].
Total Revenue: $${aggData.metrics.totalRevenue}, Collected: $${aggData.metrics.collectedRevenue}, Pending: $${aggData.metrics.pendingRevenue}.
Orders: ${aggData.metrics.completedOrders} completed / ${aggData.metrics.runningOrders} running.
Expenses: $${aggData.metrics.totalExpenses}. Low stock items: ${aggData.metrics.lowStockItems.join(", ")}.
Provide 3 strategic action items for executive management this month.
`;
      const aiAnalysis = await callGemini(aiPrompt);
      const reportPayload = {
        ...aggData,
        analysis: aiAnalysis,
        generatedAt: new Date().toISOString(),
      };

      const bucket = getStorage().bucket();
      const file = bucket.file(`ai_reports/${cid}/monthly_audit_${new Date().toISOString().slice(0, 7)}.json`);
      await file.save(JSON.stringify(reportPayload, null, 2), {
        contentType: "application/json",
      });
    }
  } catch (err) {
    console.error("Monthly audit failed:", err);
  }
});
