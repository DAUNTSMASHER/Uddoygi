# Uddoygi ERP — Complete Interconnected Workflow Map
> Compiled from full codebase scan. Every cross-departmental data touch point listed.

---

## 🔵 GROUP A: SALES & ORDER FULFILLMENT CHAIN
*(Marketing ↔ Factory ↔ Admin)*

| # | Workflow | Departments | Trigger | Outcome |
|---|----------|-------------|---------|---------|
| A1 | **New Work Order Creation** | Marketing → Factory | Marketing agent creates a Work Order (Add New WO screen) | `work_orders` doc created with `status: Pending`, Factory queue is updated |
| A2 | **Work Order Acceptance** | Factory | Factory floor supervisor sees WO in queue, taps "Accept" | WO `status` → `Accepted`; Factory Progress Update Screen now shows it |
| A3 | **Factory Stage Progression** | Factory → Marketing | Factory updates stage (Base Done → Hair Ready → Knotting → Molding) — forward-only | `workOrderTracking` log added; `currentStage` updated on WO doc |
| A4 | **Work Order Completion / Handoff** | Factory → Marketing | Factory reaches terminal stage "Submit to Head Office" | WO `completed: true`, `nextStage: 'Address Validation of the Customer'` written; Marketing Incoming Products screen shows it |
| A5 | **Address Validation** | Marketing | After factory handoff, agent validates customer delivery address | WO updated with `addressValidated: true`; shipping stage begins |
| A6 | **Shipping Agent Assignment** | Marketing | Agent assigns a courier from the Shipping Agent Directory | WO updated with courier info; Tracking Number issued |
| A7 | **Tracking Number Issued** | Marketing → Customer | Agent logs a tracking number for the order | WO `tracking_number` field set; Customer can trace via Order Progress Screen |
| A8 | **Order Delivery Confirmation** | Marketing | Agent marks delivery as confirmed | WO `status` → `Delivered`; Invoice eligible for Payment collection |
| A9 | **Admin monitors Factory Pipeline** | Admin | Admin views Orders Management screen | Reads `work_orders` in real-time; Bottleneck alerts triggered if stage unchanged >48h |

---

## 🟢 GROUP B: FINANCIAL COLLECTION CHAIN
*(Marketing ↔ HR/Accounts ↔ Admin)*

| # | Workflow | Departments | Trigger | Outcome |
|---|----------|-------------|---------|---------|
| B1 | **Invoice Creation** | Marketing | Agent creates a new invoice for a deal | `invoices` doc created with `status: Draft` or `Unpaid` |
| B2 | **Invoice Sent to Customer** | Marketing | Agent marks invoice as sent | `status` → `Sent`; Customer notified (if email integration active) |
| B3 | **Payment Slip Submission** | Marketing → HR | Customer pays; Agent uploads payment proof (image/PDF/PDF) via Payment Slip Screen | `payment_slips` doc created with `status: pending_hr`; `invoices.slipSubmitted: true`; **Notification sent to HR** |
| B4 | **HR Reviews Payment Slip** | HR | HR opens Payment Slip Approval screen; views document, checks amount | Can Approve or Reject |
| B5 | **HR Approves Slip** | HR → Admin → Marketing | HR confirms BDT amount and approves | `payment_slips.status` → `verified`; `invoices.status` → `Payment Taken`; `company_profile.cashIn` incremented; `cash_flow` entry created; `ledger` credit entry created; **Notification sent back to Marketing agent** |
| B6 | **HR Rejects Slip** | HR → Marketing | HR finds mismatch or fraud; rejects with reason | `payment_slips.status` → `rejected`; `invoices.slipStatus` → `rejected`; Proof file deleted from storage; **Notification sent to Marketing agent with rejection reason** |
| B7 | **HR Adjusts Amount on Approval** | HR | HR edits the confirmed BDT amount before approving (e.g. currency mismatch) | `amountEdited: true` flag stored; adjusted value goes to cashIn, not raw submitted value |
| B8 | **Foreign Currency Slip** | Marketing → HR | Slip submitted in USD/EUR/etc. | Auto-converted to BDT at submission; HR sees both original & converted; can override |
| B9 | **Cash Flow Updated** | Admin | After any HR approval | `cash_flow` collection updated; Admin Balance/Reports screen reflects in real-time |
| B10 | **General Ledger Entry** | HR → Admin | After HR approves payment | `ledger` collection gets a credit entry; Admin General Ledger screen shows it |
| B11 | **Payroll Reversal → cashOut decrement** | HR | HR reverses a payroll entry | `cashOut` decremented on `company_profile`; balance increases |
| B12 | **Manual Cash-In (Balance Update)** | HR | HR logs a manual cash receipt (not tied to invoice) | `company_profile.cashIn` incremented; `cash_flow` entry created |
| B13 | **Manual Cash-Out (Expense Log)** | HR | HR logs an expense | `company_profile.cashOut` incremented; `expenses` doc created |

---

## 🟡 GROUP C: HR & WORKFORCE MANAGEMENT CHAIN
*(Employees ↔ HR ↔ Admin)*

| # | Workflow | Departments | Trigger | Outcome |
|---|----------|-------------|---------|---------|
| C1 | **Employee Loan Request** | Employee (Factory/Marketing) → HR | Employee submits loan request from Loan Request Screen | `loan_requests` doc created with `status: pending` |
| C2 | **HR Approves/Rejects Loan** | HR → Employee | HR reviews request on Loan Approval Screen | If Approved: `loans` doc created, `cashOut` debited, repayment schedule created; If Rejected: notification sent |
| C3 | **Loan Repayment Deduction** | HR | Monthly payroll run detects active loans | Repayment amount auto-deducted from salary; `repayments` subcollection updated |
| C4 | **Leave Request Submission** | Employee → HR | Employee submits leave on Leave Management Screen | `leave_requests` doc created |
| C5 | **HR Approves/Rejects Leave** | HR → Employee | HR acts on leave request | `leave_requests.status` updated; **Admin Workforce Efficiency screen** recalculates staffing ratio |
| C6 | **Payroll Processing** | HR → All Employees | HR runs monthly payroll | `payrolls` docs created per employee; `salaries` updated; `cashOut` incremented on company profile |
| C7 | **Payslip Generation** | HR → Employee | After payroll run | `payslips` auto-generated; employee can view their payslip |
| C8 | **Salary Certificate** | HR → Employee | Employee requests certificate | HR generates and can email the salary certificate |
| C9 | **Attendance Logging** | Employee → HR | Daily attendance marked (Factory Attendance, HR Attendance screens) | `attendance` docs created; HR dashboard shows attendance rate |
| C10 | **Attendance → Payroll** | HR | End of month | HR payroll screen reads attendance records to calculate working days and salary |
| C11 | **Attendance → Admin Efficiency** | Admin | Real-time | Admin HR Efficiency screen reads `users` + `work_orders` to detect Overstaffed/Understaffed |
| C12 | **Benefit/Compensation Update** | HR → Employee | HR adds or modifies a benefit | `benefits` doc updated; reflected in next payroll cycle |
| C13 | **Tax Calculation** | HR → Admin | End of fiscal period | HR runs tax calculation; `taxes` collection updated; Admin Reports include tax data |
| C14 | **Employee Promotion/Transition** | Admin → HR | Admin approves a promotion from Transitions Page | `promotions` doc created; employee's `users` doc updated with new role/salary |
| C15 | **Recruitment → Hiring** | HR → Admin | HR receives applicant; Admin approves hire | `applicants` doc → `users` doc created upon hire; system access provisioned |
| C16 | **Disciplinary Punishment Log** | HR → Admin | HR logs a punishment against an employee | `punishments` doc created; can impact salary/benefits |
| C17 | **Incentive Calculation** | HR ← Marketing | HR calculates Marketing incentives | Reads `invoices` to calculate commission; `marketing_incentives` updated |

---

## 🟣 GROUP D: PROCUREMENT & SUPPLY CHAIN
*(Factory ↔ HR/Accounts ↔ Suppliers ↔ Admin)*

| # | Workflow | Departments | Trigger | Outcome |
|---|----------|-------------|---------|---------|
| D1 | **Procurement Request** | Factory/HR | HR or Factory logs a material purchase need | `procurements` doc created with `status: pending` |
| D2 | **Purchase Order Created** | HR → Supplier | HR finalises purchase from a supplier | `purchase_orders` doc created; `payables` entry created |
| D3 | **Supplier Purchase → Stock Increase** | Factory | Goods received from supplier | `stocks` doc incremented for the material received |
| D4 | **Supplier Purchase → Budget Decrease** | Admin | Same purchase event | `expenses` doc created; Admin Budget screen reflects the spend |
| D5 | **Supplier Purchase → Payable Created** | HR/Accounts | Same purchase event | `payables` doc created with due date; Accounts Payable screen shows it |
| D6 | **Supplier Rating Updated (QC Fail)** | Factory → Supplier | Factory logs QC failure linked to a supplier's material | Supplier `rating` decremented; `failure_logs` array updated |
| D7 | **Low Stock Alert** | Factory → HR/Admin | Stock screen detects quantity below threshold | Local notification pushed; `notifications` doc created for Admin |
| D8 | **Supplier Deal Status Change** | Common (Supplier Mgmt) | Any user changes deal status | `suppliers` doc `dealStatus` updated; history log written |
| D9 | **Supplier Balance Tracked** | Admin/HR | After every purchase | Supplier `totalPurchases`, `amountPaid`, `balance` recalculated |

---

## 🔬 GROUP E: R&D INNOVATION CHAIN
*(Marketing/Factory ↔ R&D ↔ Admin)*

| # | Workflow | Departments | Trigger | Outcome |
|---|----------|-------------|---------|---------|
| E1 | **R&D Project Request (Marketing)** | Marketing → R&D | Marketing agent submits R&D request for a new product/custom buyer requirement | `rnd_requests` doc created with `status: Submitted`; **Admin notified** |
| E2 | **R&D Project Request (Factory)** | Factory → R&D | Factory identifies quality issue and submits a fix request | Same as E1 — `requestingDept: factory` |
| E3 | **Admin Approves R&D Request** | Admin → R&D | Admin reviews on R&D Approval Screen | `rnd_requests.status` → `Approved`; **R&D team notified**; budget allocation logged |
| E4 | **Admin Rejects R&D Request** | Admin → Requester | Admin rejects with note | `rnd_requests.status` → `Rejected`; requester notified with reason |
| E5 | **R&D Project Created** | R&D | After approval | `rnd_projects` doc created; milestone planning begins |
| E6 | **R&D Daily Progress Update** | R&D | Team member submits daily update | `rnd_updates` doc added; Admin R&D screen shows progress % |
| E7 | **R&D Milestone Reached** | R&D → Admin | Milestone completed | `rnd_milestones` doc updated; Admin notified; budget spend tracked |
| E8 | **R&D BOM Delivered to Factory** | R&D → Factory | Prototype approved | BOM (Bill of Materials) available; Factory R&D sync shows "In Sync" |
| E9 | **QC Failure → R&D Red Flag** | Factory → R&D | Factory logs QC fail | R&D screen shows "Design Feedback Loop" red alert; R&D team must investigate |
| E10 | **Product Cost Optimization** | R&D → Admin | R&D logs cost reduction progress | Admin R&D dashboard shows % target achieved (e.g., reduce plastic waste 10%) |
| E11 | **New Product → Marketing Launch** | R&D → Marketing | Prototype gets "Sample Approved" | Marketing notified to create campaigns; product added to `products` collection |

---

## 🔔 GROUP F: NOTICES, COMPLAINTS & COMMUNICATION
*(Any Department ↔ Any Department)*

| # | Workflow | Departments | Trigger | Outcome |
|---|----------|-------------|---------|---------|
| F1 | **Admin Posts Notice** | Admin → All | Admin creates notice on Notice Screen | `notices` doc created; visible to all departments (HR, Marketing, Factory, R&D) |
| F2 | **HR Posts Notice** | HR → Employees | HR creates department notice | `notices` doc with `targetDept: hr`; employees see it on their dashboard |
| F3 | **Marketing Posts Notice** | Marketing → Team | Marketing manager posts notice | `notices` doc visible to marketing team |
| F4 | **Factory Posts Notice** | Factory → Workers | Factory supervisor posts notice | `factory_notices` doc visible to factory workers |
| F5 | **Employee Submits Complaint** | Employee → HR/Admin | Employee submits complaint via Common Complaints Screen | `complaints` doc created; HR/Admin notified |
| F6 | **Admin Resolves Complaint** | Admin → Employee | Admin marks complaint resolved | `complaints.status` → `resolved`; employee notified |
| F7 | **Internal Message Sent** | Any → Any | Any user sends a direct message | `messages` doc created; recipient sees notification badge |
| F8 | **Welfare Request Submission** | Employee → HR | Employee submits welfare request | `welfare_requests` doc created; HR reviews |
| F9 | **HR Approves Welfare Scheme** | HR → Employee | HR approves welfare benefit | `welfare_schemes` doc updated; benefit reflected in next payroll |
| F10 | **Appointment Letter Generated** | HR → Employee | HR generates appointment letter | PDF generated from HR Appointment Letter Screen; can be emailed |

---

## 📊 GROUP G: ADMIN ANALYTICS & CROSS-SYNC
*(Admin reads from All Departments)*

| # | Workflow | Departments | Data Source | Admin View |
|---|----------|-------------|-------------|------------|
| G1 | **Net Profitability Dashboard** | Admin ← All | `invoices` + `salaries` + `expenses` | Profit = Revenue − (Labor + Production + Marketing Spend) |
| G2 | **Workforce Efficiency** | Admin ← HR + Factory | `users` + `work_orders` | Staffing ratio; Overstaffed/Understaffed/Balanced verdict |
| G3 | **Revenue Pipeline** | Admin ← Marketing | `tasks` (active leads) + `invoices` | Ongoing Deal Value vs. Completed Sales; Conversion Rate |
| G4 | **Operational Health** | Admin ← Factory + Supplier | `work_orders` + `suppliers` | Supplier quality %, R&D alignment, Actual vs. Planned variance |
| G5 | **Product Optimization** | Admin ← R&D + Factory | `rnd_projects` + production data | Waste redesign impact, failure rate reduction, cost vs. design |
| G6 | **Campaign ROI** | Admin ← Marketing | `campaigns` + `invoices` | Spend vs. Revenue generated per campaign |
| G7 | **QC Report Cross-View** | Admin ← Factory + Marketing | `qc_reports` + `suppliers` | Which supplier's materials cause QC failures, which customer orders are at risk |
| G8 | **Team Sales Leaderboard** | Admin ← Marketing | `invoices` + `users` + `tasks` | Per-agent sales total, meetings logged, collections made |
| G9 | **Budget vs. Actual** | Admin ← HR | `budgets` + `expenses` | Departmental budget utilization tracking |
| G10 | **General Ledger** | Admin ← HR | `ledger` | All debit/credit entries across the company |
| G11 | **Cash Flow Timeline** | Admin ← HR | `cash_flow` | Every cash-in/cash-out event with source |
| G12 | **ROI Calculation** | Admin ← Marketing | Payroll cost vs. revenue | Marketing team ROI analysis |
| G13 | **Customer Tiering** | Admin ← Marketing | `invoices` grouped by customer | Gold/Silver/Bronze ranking by purchase volume |

---

## 🏭 GROUP H: FACTORY-SPECIFIC INTERNAL WORKFLOWS

| # | Workflow | Trigger | Outcome |
|---|----------|---------|---------|
| H1 | **Work Order Priority Queue** | New WO received | Factory sees orders sorted by priority; accepts/rejects |
| H2 | **Stage Forward-Only Enforcement** | Factory progress update | System prevents going back to a previous stage; enforces linear flow |
| H3 | **Average Completion Time Tracking** | Orders completed | Factory dashboard calculates avg time per order; shown to Admin |
| H4 | **Machine Downtime Log** | Admin Monitoring | Manually flagged machines shown as Down in status grid |
| H5 | **Daily Production Counter** | Factory daily update | Units produced vs. daily goal; shown as live counter with % progress |
| H6 | **Utility Consumption Alert** | Monitoring screen | Electricity/Water/Fuel usage tracked; spikes flagged |
| H7 | **Safety Incident Log** | Any factory user | Incident reported; Admin Safety Alerts section updated |

---

## 🔐 GROUP I: AUTHENTICATION & COMPANY SETUP

| # | Workflow | Trigger | Outcome |
|---|----------|---------|---------|
| I1 | **Company Registration** | New company signs up | `companies` doc created; all base collections initialized (invoices, notifications, users, etc.) |
| I2 | **Company ID Recovery** | User forgets company ID | Recovery screen queries `companies` by admin email; sends ID |
| I3 | **Employee Login → Role-Based Access** | Login | Session stored locally; role determines which dashboard loads (Admin/HR/Marketing/Factory/R&D) |
| I4 | **SMTP Configuration** | Admin sets up email | SMTP settings stored; enables email sending for payslips, letters |
| I5 | **Company Profile Update** | Admin edits profile | `company_profile/main` updated; all department headers pull from this |

---

## 📦 GROUP J: STOCK & INVENTORY WORKFLOWS

| # | Workflow | Trigger | Outcome |
|---|----------|---------|---------|
| J1 | **Stock Level Update** | Supplier purchase received | Stock quantity incremented for specific material |
| J2 | **Stock Threshold Alert** | Stock screen monitors levels | If below minimum threshold: local push notification + Firestore notification to admin |
| J3 | **Stale Stock Alert** | Stock last-updated timestamp check | If stock not updated in X days: "Stale" alert pushed |
| J4 | **BOM Cross-Check** | R&D delivers BOM for new product | Factory checks stock levels against required materials in BOM |
| J5 | **Product Pricing** | Marketing sets price | `product_prices` collection updated; all invoice creation reads this |

---

## 💳 GROUP K: PAYMENT PLATFORM (PipraPay)

| # | Workflow | Trigger | Outcome |
|---|----------|---------|---------|
| K1 | **Money Source Registration** | HR adds a bank/mobile account | `money_sources` doc created; available for transactions |
| K2 | **Beneficiary Added** | HR registers a payee | `beneficiaries` doc created |
| K3 | **Transaction Executed** | HR initiates a transfer | `pipra_transactions` doc created with status; linked to expense |

---

## 📋 SUMMARY COUNTS

| Group | Name | # of Workflows |
|-------|------|----------------|
| A | Sales & Fulfillment | 9 |
| B | Financial Collection | 13 |
| C | HR & Workforce | 17 |
| D | Procurement & Supply | 9 |
| E | R&D Innovation | 11 |
| F | Communication & Notices | 10 |
| G | Admin Analytics | 13 |
| H | Factory Internal | 7 |
| I | Auth & Setup | 5 |
| J | Stock & Inventory | 5 |
| K | Payments (PipraPay) | 3 |
| **TOTAL** | | **102 workflows** |

---

## ⚠️ GAPS IDENTIFIED (Needs Implementation for Full Sync)

| Gap | What's Missing | Recommended Fix |
|-----|---------------|-----------------|
| **A4 → Marketing Notification** | Factory completion doesn't yet auto-notify Marketing to start Address Validation | Add Firestore trigger / `DataSyncService.triggerOrderCompletion()` |
| **C3 → Payroll Auto-deduction** | Loan repayments are tracked but not yet auto-deducted during payroll run | Payroll processing screen should query `loans` and deduct |
| **D6 → Marketing Delay Flag** | QC failure doesn't yet flag the linked Customer in Marketing | `DataSyncService.triggerQCFailure()` exists — needs wiring to customer record |
| **E8 → Factory BOM Sync** | R&D delivering a BOM doesn't yet create a Stock Requirements check in Factory | Needs a `rnd_projects` completion trigger that writes to `stock_requirements` |
| **G2 → Absence Impact** | Leave approvals don't update the Efficiency calculation in real-time | Admin Efficiency screen should also read `leave_requests` approved count |
| **J4 → BOM Cross-Check UI** | No UI to compare BOM requirements vs. current stock levels | Needs a screen in Factory or Admin Products Inventory |
