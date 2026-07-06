# deploy_rules.ps1
# Run this script to deploy the Firestore security rules.
# Usage: .\deploy_rules.ps1

Write-Host "Logging in to Firebase..." -ForegroundColor Cyan
firebase login --reauth

Write-Host "Deploying Firestore rules..." -ForegroundColor Cyan
firebase deploy --only firestore:rules

Write-Host "Done!" -ForegroundColor Green
