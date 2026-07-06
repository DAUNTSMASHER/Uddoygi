/**
 * diagnose_google_signin.js
 * ─────────────────────────────────────────────────────────────
 * Diagnoses ApiException: 10 (DEVELOPER_ERROR) for Google Sign-In
 * in a Flutter + Firebase Android project.
 *
 * Usage:
 *   node scripts/diagnose_google_signin.js
 *   (Run from the Flutter project root)
 *
 * What it checks:
 *   1.  google-services.json exists in android/app/
 *   2.  Package name in build.gradle.kts matches google-services.json
 *   3.  A web OAuth client (client_type: 3) exists — required for Android Sign-In
 *   4.  An Android OAuth client (client_type: 1) exists with a certificate_hash
 *   5.  google-services plugin version in settings.gradle.kts (warns if < 4.4.0)
 *   6.  Prints the exact SHA-1 command to run
 *   7.  Prints the Firebase Console URL to add SHA fingerprints
 *   8.  Prints the serverClientId your Flutter code must use
 * ─────────────────────────────────────────────────────────────
 */

'use strict';

const fs   = require('fs');
const path = require('path');

// ── ANSI colours ─────────────────────────────────────────────
const G = (s) => `\x1b[32m${s}\x1b[0m`; // green
const R = (s) => `\x1b[31m${s}\x1b[0m`; // red
const Y = (s) => `\x1b[33m${s}\x1b[0m`; // yellow
const B = (s) => `\x1b[36m${s}\x1b[0m`; // cyan/blue
const W = (s) => `\x1b[1m${s}\x1b[0m`;  // bold

const ROOT = process.cwd();
let errors   = 0;
let warnings = 0;

function ok(msg)   { console.log(`  ${G('✔')}  ${msg}`); }
function err(msg)  { console.log(`  ${R('✘')}  ${msg}`); errors++; }
function warn(msg) { console.log(`  ${Y('⚠')}  ${msg}`); warnings++; }
function info(msg) { console.log(`  ${B('ℹ')}  ${msg}`); }
function section(title) {
  console.log(`\n${W('─'.repeat(56))}`);
  console.log(W(` ${title}`));
  console.log(`${W('─'.repeat(56))}`);
}

// ─────────────────────────────────────────────────────────────
// 1. google-services.json
// ─────────────────────────────────────────────────────────────
section('1 · google-services.json');

const gsjPath = path.join(ROOT, 'android', 'app', 'google-services.json');
if (!fs.existsSync(gsjPath)) {
  err(`google-services.json NOT FOUND at android/app/google-services.json`);
  err('Download it from Firebase Console → Project Settings → Your Android App');
  process.exit(1);
}
ok('google-services.json found at android/app/');

let gsj;
try {
  gsj = JSON.parse(fs.readFileSync(gsjPath, 'utf8'));
} catch (e) {
  err(`google-services.json is not valid JSON: ${e.message}`);
  process.exit(1);
}
ok('google-services.json is valid JSON');

const projectId     = gsj.project_info?.project_id ?? '(unknown)';
const projectNumber = gsj.project_info?.project_number ?? '(unknown)';
info(`Firebase project: ${B(projectId)}  (number: ${projectNumber})`);

// ─────────────────────────────────────────────────────────────
// 2. Package name consistency
// ─────────────────────────────────────────────────────────────
section('2 · Package name consistency');

// Read applicationId from build.gradle.kts
const bgPath = path.join(ROOT, 'android', 'app', 'build.gradle.kts');
const bgPathGroovy = path.join(ROOT, 'android', 'app', 'build.gradle');
let gradleContent = '';
if (fs.existsSync(bgPath)) {
  gradleContent = fs.readFileSync(bgPath, 'utf8');
} else if (fs.existsSync(bgPathGroovy)) {
  gradleContent = fs.readFileSync(bgPathGroovy, 'utf8');
} else {
  warn('android/app/build.gradle(.kts) not found — cannot check applicationId');
}

let gradlePackage = null;
const appIdMatch = gradleContent.match(/applicationId\s*[=:]\s*["']([^"']+)["']/);
if (appIdMatch) {
  gradlePackage = appIdMatch[1];
  ok(`applicationId in build.gradle: ${B(gradlePackage)}`);
} else {
  warn('Could not parse applicationId from build.gradle');
}

// Collect all package names from google-services.json
const clients = gsj.client ?? [];
const gsjPackages = clients.map(c => c.client_info?.android_client_info?.package_name).filter(Boolean);
info(`Packages in google-services.json: ${gsjPackages.map(p => B(p)).join(', ')}`);

if (gradlePackage) {
  if (gsjPackages.includes(gradlePackage)) {
    ok(`Package ${B(gradlePackage)} found in google-services.json ✔`);
  } else {
    err(`Package ${R(gradlePackage)} is NOT in google-services.json!`);
    err(`  google-services.json has: ${gsjPackages.join(', ')}`);
    err(`  → Add Android app with package "${gradlePackage}" in Firebase Console`);
    err(`    or change applicationId to match an existing entry.`);
  }
}

// ─────────────────────────────────────────────────────────────
// 3. OAuth clients — web client (required for Android Sign-In)
// ─────────────────────────────────────────────────────────────
section('3 · OAuth clients in google-services.json');

let webClientId = null;
let androidClientFound = false;

for (const client of clients) {
  const pkg = client.client_info?.android_client_info?.package_name;
  const oauthClients = client.oauth_client ?? [];

  for (const oc of oauthClients) {
    if (oc.client_type === 3) {
      webClientId = oc.client_id;
      ok(`Web OAuth client (type 3) found: ${B(webClientId)}`);
      info(`  → This is the serverClientId your Flutter code must use`);
    }
    if (oc.client_type === 1) {
      const hash = oc.android_info?.certificate_hash ?? '(no hash)';
      androidClientFound = true;
      ok(`Android OAuth client (type 1) for ${B(pkg ?? '?')}: hash=${B(hash)}`);
    }
  }
}

if (!webClientId) {
  err('No web OAuth client (client_type: 3) found in google-services.json!');
  err('  → This is the #1 cause of ApiException: 10 on Android.');
  err('  → Fix: Firebase Console → Authentication → Sign-in method → Google → Enable');
  err('    Enabling Google Sign-In auto-creates the web client.');
}

if (!androidClientFound) {
  err('No Android OAuth client (client_type: 1) found in google-services.json!');
  err('  → You must add your SHA-1 fingerprint in Firebase Console first.');
  err('  → Then re-download google-services.json.');
}

// ─────────────────────────────────────────────────────────────
// 4. google-services plugin version
// ─────────────────────────────────────────────────────────────
section('4 · Gradle plugin version');

const sgPath = path.join(ROOT, 'android', 'settings.gradle.kts');
const sgPathGroovy = path.join(ROOT, 'android', 'settings.gradle');
let sgContent = '';
if (fs.existsSync(sgPath)) sgContent = fs.readFileSync(sgPath, 'utf8');
else if (fs.existsSync(sgPathGroovy)) sgContent = fs.readFileSync(sgPathGroovy, 'utf8');

const gmsMatch = sgContent.match(/com\.google\.gms\.google-services['"]\s*\)?\s*version\s*\(?["']([^"']+)["']/);
if (gmsMatch) {
  const ver = gmsMatch[1];
  const [major, minor, patch] = ver.split('.').map(Number);
  if (major > 4 || (major === 4 && minor >= 4)) {
    ok(`google-services plugin version: ${B(ver)} ✔`);
  } else {
    warn(`google-services plugin version ${Y(ver)} is outdated.`);
    warn(`  → Upgrade to 4.4.2 in settings.gradle.kts:`);
    warn(`    id("com.google.gms.google-services") version("4.4.2") apply false`);
  }
} else {
  warn('Could not detect google-services plugin version in settings.gradle.kts');
}

// ─────────────────────────────────────────────────────────────
// 5. SHA fingerprint instructions
// ─────────────────────────────────────────────────────────────
section('5 · SHA fingerprint — action required');

console.log(`
  Run this command in your project root to get SHA keys:

  ${B('Windows (PowerShell):')}
    cd android
    .\\gradlew signingReport

  ${B('Mac / Linux:')}
    cd android && ./gradlew signingReport

  Look for the ${W('debug')} store section and copy:
    ${G('SHA1:')}   paste into Firebase Console
    ${G('SHA-256:')} paste into Firebase Console

  ${B('Where to add them:')}
    Firebase Console
      → Project Settings (gear icon)
      → Your Apps → Android app (${gradlePackage ?? 'com.example.uddoygi'})
      → Add fingerprint
      → Paste SHA1, then add again for SHA-256

  ${B('After adding SHA keys:')}
    1. Download new google-services.json
    2. Replace android/app/google-services.json
    3. Run:  flutter clean && flutter pub get && flutter run
`);

// ─────────────────────────────────────────────────────────────
// 6. serverClientId for Flutter code
// ─────────────────────────────────────────────────────────────
section('6 · Flutter code — serverClientId');

if (webClientId) {
  console.log(`
  Your Flutter GoogleSignIn() call must include serverClientId:

  ${B('GoogleSignIn(')}
    ${B('scopes: [\'email\', \'profile\'],')}
    ${B(`serverClientId: '${webClientId}',`)}
  ${B(')')}

  Without serverClientId, Android throws ApiException: 10.
`);
} else {
  warn('Cannot print serverClientId — no web client found (see error above).');
}

// ─────────────────────────────────────────────────────────────
// 7. Summary
// ─────────────────────────────────────────────────────────────
section('Summary');

if (errors === 0 && warnings === 0) {
  console.log(`\n  ${G('All checks passed!')} Config looks correct.\n`);
  console.log(`  ${Y('Still getting ApiException: 10?')}`);
  console.log(`  → The SHA-1 in google-services.json must match your debug keystore.`);
  console.log(`  → Run: cd android && .\\gradlew signingReport  (Windows)`);
  console.log(`  → Add SHA-1 to Firebase Console and re-download google-services.json.\n`);
} else {
  console.log(`\n  ${R(`${errors} error(s)`)}  ${Y(`${warnings} warning(s)`)}`);
  console.log(`  Fix the errors above, then re-run this script.\n`);
}

// ─────────────────────────────────────────────────────────────
// 8. Why ApiException: 10 happens — quick reference
// ─────────────────────────────────────────────────────────────
section('Why ApiException: 10 (DEVELOPER_ERROR) happens');
console.log(`
  This error means Google Play Services rejected the sign-in request
  because the app's identity could not be verified. Causes (in order
  of frequency):

  ${R('1.')} SHA-1 fingerprint NOT added to Firebase Console
      → Most common cause. Your debug keystore SHA-1 must be registered.

  ${R('2.')} Google Sign-In NOT enabled in Firebase Authentication
      → Firebase Console → Auth → Sign-in method → Google → Enable

  ${R('3.')} google-services.json is stale (downloaded before SHA was added)
      → Re-download after adding SHA fingerprints.

  ${R('4.')} Package name mismatch
      → applicationId in build.gradle ≠ package in Firebase Console.

  ${R('5.')} Missing serverClientId in GoogleSignIn() constructor
      → Required on Android. Use the web client ID (client_type: 3).

  ${R('6.')} google-services plugin too old (< 4.4.0)
      → Upgrade to 4.4.2 in settings.gradle.kts.

  ${R('7.')} ProGuard/R8 stripping Play Services classes in release builds
      → Add keep rules for com.google.android.gms.** in proguard-rules.pro.
`);
