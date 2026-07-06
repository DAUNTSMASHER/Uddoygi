# deploy_rules_token.ps1
# ─────────────────────────────────────────────────────────────
# Deploys Firestore rules using a Firebase CI token.
#
# HOW TO USE:
#   1. On any machine where you ARE logged in to Firebase CLI, run:
#        firebase login:ci
#      Copy the token it prints (starts with "1//0g...")
#
#   2. Run this script with that token:
#        .\deploy_rules_token.ps1 -Token "1//0g..."
#
# OR — just paste the rules directly in Firebase Console:
#   https://console.firebase.google.com/project/uddyogi/firestore/rules
# ─────────────────────────────────────────────────────────────
param(
    [Parameter(Mandatory=$false)]
    [string]$Token = ""
)

if ($Token -eq "") {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  OPTION A: Deploy via CI token" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. On a machine where Firebase CLI is logged in, run:" -ForegroundColor White
    Write-Host "       firebase login:ci" -ForegroundColor Green
    Write-Host ""
    Write-Host "  2. Copy the token and run:" -ForegroundColor White
    Write-Host "       .\deploy_rules_token.ps1 -Token `"YOUR_TOKEN_HERE`"" -ForegroundColor Green
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  OPTION B: Paste rules in Firebase Console (easiest)" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Open this URL in your browser:" -ForegroundColor White
    Write-Host "  https://console.firebase.google.com/project/uddyogi/firestore/rules" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Then paste the contents of: firestore.rules" -ForegroundColor White
    Write-Host "  and click 'Publish'" -ForegroundColor White
    Write-Host ""
    exit 0
}

Write-Host "Deploying Firestore rules with CI token..." -ForegroundColor Cyan
$env:FIREBASE_TOKEN = $Token
firebase deploy --only firestore:rules --token $Token
Write-Host "Done!" -ForegroundColor Green
