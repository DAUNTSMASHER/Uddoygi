# How to Run the Fix Script

## Step 1 — Get your Firebase Service Account Key

1. Open [Firebase Console](https://console.firebase.google.com)
2. Click the **gear icon** → **Project Settings**
3. Click the **Service Accounts** tab
4. Click **"Generate new private key"** → **Generate Key**
5. A JSON file will download — rename it to `serviceAccountKey.json`
6. Place it in this `scripts/` folder:
   ```
   scripts/serviceAccountKey.json   ← here
   scripts/fix_company_data.js
   scripts/package.json
   ```

> ⚠️ Never commit serviceAccountKey.json to git. It gives full admin access to your Firebase project.

---

## Step 2 — Install dependencies

Open a terminal, go to the scripts folder:

```powershell
cd scripts
npm install
```

---

## Step 3 — Run a dry run first (safe, writes nothing)

```powershell
node fix_company_data.js --dry-run
```

This will show you exactly what is broken and what would be fixed, without touching any data.

---

## Step 4 — Run the actual fix

```powershell
node fix_company_data.js
```

This fixes:
- Companies missing from the `companies` collection (causes "forgot company ID" to say "not found")
- Users with missing or wrong `companyId` field
- `companies` docs with missing `email` or `phone` fields
- `company/main` singleton not linked to the right company

---

## Step 5 — Also stamp all existing data with companyId

If you have existing invoices, payrolls, etc. that don't have a `companyId` field
(meaning they would show up for every company), run:

```powershell
node fix_company_data.js --stamp-all
```

If you have multiple companies and only want to fix one:

```powershell
node fix_company_data.js --company 12345678 --stamp-all
```

---

## Step 6 — Run again to verify

```powershell
node fix_company_data.js --dry-run
```

Should show: **0 fixes needed, 0 errors**

---

## What each problem means

| Problem | Cause | Fix |
|---|---|---|
| "Email already registered" on registration | Firebase Auth has the email but `companies` collection doesn't | Script creates/repairs the `companies` doc |
| "No company found" on Forgot Company ID | `companies` doc missing `email` field | Script patches the `email` field |
| Data from one company showing in another | Documents missing `companyId` field | `--stamp-all` adds `companyId` to all docs |
| Login says "account doesn't belong to this company" | `users` doc has wrong or missing `companyId` | Script patches `users` doc |
