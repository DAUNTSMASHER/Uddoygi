# PipraPay & Salary Payment System — Setup Guide

> **Audience:** Anyone on the team who needs to configure, test, or use the salary payment system.
> No technical background required to follow Steps 1–5.

---

## How the System Works (Simple Overview)

```
Employee adds receive account  →  HR adds company payout account
        ↓                                    ↓
     HR creates Payroll  →  HR reviews  →  HR sends payment
                                              ↓
                                  PipraPay processes (bKash/Nagad/Bank)
                                              ↓
                                  Transaction saved + payslip generated
```

---

## Step 1 — Employee Adds Their Salary Receive Account

**Who does this:** Every employee who wants to receive salary digitally.

1. Open the app and go to **My Salary** (from your department dashboard).
2. Tap the **wallet icon** (top right of the Salary screen).
3. Tap **+ Add Method**.
4. Choose your payment type: bKash / Nagad / Rocket / Upay / Bank Transfer / Cash.
5. Enter your wallet number or bank account number.
6. Enter your account holder name (exactly as registered).
7. For Bank Transfer, also enter: Bank Name, Branch Name, Routing Number.
8. Toggle **Set as Default** if this is your primary receive method.
9. Tap **Add Method** to save.

> **Note:** HR must verify your account before salary can be sent to it.
> After any edit, verification resets and HR needs to re-verify.

---

## Step 2 — HR Adds Company Payout Accounts

**Who does this:** HR Manager.

1. Open the HR Dashboard.
2. Tap **Accounts** (in the dashboard grid or Finance section of the drawer).
3. Tap **+ Add Account** (floating button).
4. Choose account type: bKash / Nagad / Rocket / Bank / Cash.
5. Enter account label (e.g. "Company bKash"), account number, holder name.
6. For Bank: also enter bank name, branch, routing number.
7. Toggle **Default Payroll Source** if this is the main account used for salary.
8. Tap **Save**.

> You can add multiple accounts. Only one can be the default at a time.

---

## Step 3 — HR Creates Payroll

1. Go to HR Dashboard → **Payroll** tile.
2. Select the month and department.
3. Tap **Generate Payroll** to create records for all employees.
4. Review each record (salary, deductions, bonuses, net pay).
5. Tap **Approve** to finalize the payroll run.

---

## Step 4 — HR Sends Salary Payment

### Option A: Manual Payment (No PipraPay configured yet)

1. Go to **Payroll** → select the approved payroll run.
2. For each employee, tap **Mark as Paid**.
3. Enter the transaction reference number (from your bank/bKash app).
4. The system saves the payment record and generates a payslip.

> This keeps the exact same data structure as live payments.
> When you connect PipraPay later, nothing needs to change.

### Option B: Via PipraPay (when configured)

1. Go to **Payroll** → select the approved payroll run.
2. For each employee, tap **Send via PipraPay**.
3. The system shows the employee's default receive account.
4. Confirm the amount and tap **Send**.
5. A PipraPay checkout link opens — complete the payment there.
6. The transaction is automatically logged and the payslip is generated.

---

## Step 5 — Configure PipraPay (When You Have API Credentials)

### 5a. Backend Setup (Node.js server)

> **Important:** API keys must NEVER be put in the Flutter app.
> They must go in the backend server only.

1. Go to the `piprapay-backend/` folder in the project.
2. Copy `.env.example` to `.env`:
   ```
   cp .env.example .env
   ```
3. Open `.env` and fill in:
   ```
   PIPRAPAY_API_KEY=your_api_key_here
   PIPRAPAY_SANDBOX=true          # true for testing, false for live
   BACKEND_SECRET_TOKEN=any_long_random_string_you_choose
   PORT=3000
   ```
4. Install dependencies:
   ```
   npm install
   ```
5. Start the server:
   ```
   npm start
   ```
6. Note your server URL (e.g. `https://your-server.com` or `http://localhost:3000`).

### 5b. Connect Flutter App to Backend

1. In the HR Dashboard, tap **Accounts** → then tap **PipraPay Settings** (or go via drawer → Finance → PipraPay Settings).
2. Toggle **Enable PipraPay** to ON.
3. Enter your **Backend URL** (from step 5a above).
4. Toggle **Sandbox Mode** ON for testing, OFF for live.
5. Tap **Test Connection** — it should show "Connected".
6. Tap **Save Settings**.

### 5c. Test a Payment (Sandbox Mode)

1. Make sure Sandbox Mode is ON in PipraPay Settings.
2. Add a test employee with a bKash number.
3. Create a small test payroll (e.g. ৳100).
4. Tap **Send via PipraPay** and complete the checkout.
5. Check the transaction appears in **Transactions** screen.

### 5d. Switch to Live Mode

1. In PipraPay Settings, toggle **Sandbox Mode** to OFF.
2. Make sure your backend `.env` has `PIPRAPAY_SANDBOX=false`.
3. Restart the backend server.
4. Tap **Test Connection** again to confirm.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| "Test Connection" fails | Check backend URL is correct and server is running |
| Employee account shows "Unverified" | HR needs to verify the account in Employee Details |
| Payment shows "Failed" | Check PipraPay dashboard for error details; retry from Transactions screen |
| Wrong amount sent | Use the Payroll Reversal feature to reverse and re-send |
| Can't see payment methods | Employee needs to add their account first (Step 1) |
| Backend error 401 | Check BACKEND_SECRET_TOKEN matches between .env and app settings |

---

## Data Structure (For Developers)

```
Firestore:
  data/{companyId}/
    users/{employeeUid}/
      payment_methods/{methodId}     ← Employee receive accounts (multi-method)
        type, accountNumber, accountName, bankName, isDefault, isVerifiedByHr
    
    money_sources/{sourceId}         ← Company payout accounts (HR)
      type, label, accountNumber, accountName, isDefault, isActive
    
    payment_settings/piprapay        ← PipraPay configuration
      enabled, sandboxMode, backendBaseUrl, connectionStatus
    
    payrolls/{payrollId}             ← Payroll records
      employeeUid, period, netSalary, status, paymentMethod
    
    pipra_transactions/{txnId}       ← Payment transaction log
      beneficiaryId, amount, status, ppId, invoiceId
    
    beneficiaries/{beneficiaryId}    ← PipraPay beneficiary registry
      name, emailOrMobile, accountNumber, type
```

---

## Adding a Real bKash-to-bKash Payment (Minimum Working Flow)

When you have PipraPay credentials:

1. Employee adds their bKash number as a payment method (Step 1).
2. HR adds company bKash as a payout source (Step 2).
3. HR configures PipraPay with backend URL + API key (Step 5).
4. HR creates payroll and taps **Send via PipraPay**.
5. System creates a PipraPay charge request via the backend.
6. Backend calls PipraPay API with the bKash numbers and amount.
7. Employee receives money on their bKash.
8. Webhook confirms payment → system marks payroll as Paid.

---

*Last updated: February 2026*
