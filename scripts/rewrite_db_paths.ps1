# rewrite_db_paths.ps1
# ─────────────────────────────────────────────────────────────
# Rewrites all Dart files in lib/ to use the new DB helper
# instead of hardcoded FirebaseFirestore.instance.collection('...')
#
# Run from project root:
#   powershell -ExecutionPolicy Bypass -File scripts\rewrite_db_paths.ps1
# ─────────────────────────────────────────────────────────────

$libPath = "lib"
$dartFiles = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | Where-Object { $_.FullName -notmatch "\\services\\db\.dart" }

$totalChanged = 0

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $original = $content

    # ── 1. Add import for DB helper if file uses cloud_firestore ──
    if ($content -match "cloud_firestore" -and $content -notmatch "services/db\.dart") {
        # Add import after the cloud_firestore import line
        $content = $content -replace "(import 'package:cloud_firestore/cloud_firestore\.dart';)", "`$1`nimport 'package:uddoygi/services/db.dart';"
    }

    # ── 2. Replace FirebaseFirestore.instance with DB.firestore ──
    $content = $content -replace "FirebaseFirestore\.instance(?!\.collection\('companies'\))(?!\.collection\('users'\)\.doc\([^)]+\)\.collection\('fcmTokens'\))(?!\.collection\('users'\)\.doc\([^)]+\)\.collection\('devices'\))", "DB.firestore"

    # ── 3. Replace DB.firestore.collection('X') with await DB.col('X') ──
    # (for top-level collections that are company-scoped)
    $companyScoped = @(
        'users','notifications','messages','notices','complaints','alerts',
        'alert_dispatch','welfare','welfare_requests','welfare_schemes',
        'employees','payrolls','salaries','leaves','leave_requests','shifts',
        'benefits','attendance','loans','loan_requests','taxes','procurements',
        'applicants','promotions','recommendation','hr_documents',
        'marketing_incentives','punishments','invoices','payment_slips',
        'cash_flow','expenses','ledger','budgets','budget','accounts','targets',
        'customers','products','product_prices','campaigns','tasks','qc_reports',
        'address_validations','work_orders','work_order_tracking','tracking_index',
        'daily_production','purchase_orders','stocks','rnd_requests','rnd_projects',
        'rnd_updates','rnd_milestones','rnd_scores','company_profile',
        'salaries','orders','clients','rnd_scores'
    )

    foreach ($col in $companyScoped) {
        # DB.firestore.collection('col') → await DB.col('col')
        $content = $content -replace "DB\.firestore\.collection\('$col'\)", "await DB.col('$col')"
        # _db.collection('col') → await DB.col('col')
        $content = $content -replace "_db\.collection\('$col'\)", "await DB.col('$col')"
        # _firestore.collection('col') → await DB.col('col')
        $content = $content -replace "_firestore\.collection\('$col'\)", "await DB.col('$col')"
        # firestore.collection('col') → await DB.col('col')
        $content = $content -replace "(?<![_A-Za-z])firestore\.collection\('$col'\)", "await DB.col('$col')"
        # fs.collection('col') → await DB.col('col')
        $content = $content -replace "fs\.collection\('$col'\)", "await DB.col('$col')"
        # db.collection('col') → await DB.col('col')
        $content = $content -replace "(?<![_A-Za-z])db\.collection\('$col'\)", "await DB.col('$col')"
    }

    # ── 4. Fix company/main → company_profile/main ──
    $content = $content -replace "await DB\.col\('company'\)\.doc\('main'\)", "await DB.doc('company_profile', 'main')"
    $content = $content -replace "DB\.firestore\.collection\('company'\)\.doc\('main'\)", "await DB.doc('company_profile', 'main')"
    $content = $content -replace "_db\.collection\('company'\)\.doc\('main'\)", "await DB.doc('company_profile', 'main')"
    $content = $content -replace "db\.collection\('company'\)\.doc\('main'\)", "await DB.doc('company_profile', 'main')"

    # ── 5. companies collection stays root-level ──
    $content = $content -replace "DB\.firestore\.collection\('companies'\)", "DB.companiesCol"
    $content = $content -replace "_db\.collection\('companies'\)", "DB.companiesCol"
    $content = $content -replace "db\.collection\('companies'\)", "DB.companiesCol"

    # ── 6. smtp_config stays root-level ──
    $content = $content -replace "await DB\.col\('smtp_config'\)", "DB.firestore.collection('smtp_config')"

    # ── 7. users/{uid}/fcmTokens and devices stay root-level ──
    # These are handled by DB.fcmTokensCol(uid) and DB.devicesCol(uid)

    if ($content -ne $original) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  Updated: $($file.FullName.Replace((Get-Location).Path + '\', ''))"
        $totalChanged++
    }
}

Write-Host "`n✅  Done. $totalChanged file(s) updated."
