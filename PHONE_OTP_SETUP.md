# Firebase Phone Auth OTP Setup Checklist

## Why OTP SMS was not arriving — Root Causes Fixed

### 1. Code Bug (FIXED) — Race condition in admin_settings_screen.dart
`_loadCompanyPhone()` was called before `_cid` was loaded from local storage.
This meant it fetched from `data//company_profile/main` (empty path) → found nothing → phone was blank → OTP send was blocked.

**Fix applied:** Now loads `_cid` first, then calls `_loadCompanyPhone(cid)`.

### 2. Code Bug (FIXED) — Wrong phone number format
Bangladesh numbers stored as `01XXXXXXXXX` were being sent as `+01XXXXXXXXX` (invalid).

**Fix applied:** `_toE164()` now converts:
- `01XXXXXXXXX` → `+8801XXXXXXXXX`  ✅
- `8801XXXXXXXXX` → `+8801XXXXXXXXX`  ✅
- `+8801XXXXXXXXX` → unchanged  ✅

### 3. Code Bug (FIXED) — verificationFailed didn't reset loading state
If Firebase rejected the number, the spinner kept spinning forever.

**Fix applied:** `verificationFailed` now resets `_sendingOtp = false`.

---

## Firebase Console Steps (YOU MUST DO THESE)

### Step 1 — Enable Phone Authentication
1. Go to https://console.firebase.google.com
2. Select project **uddyogi**
3. Go to **Authentication → Sign-in method**
4. Click **Phone** → Enable it → Save

### Step 2 — Add SHA-1 and SHA-256 fingerprints
Firebase Phone Auth on Android requires your app's SHA fingerprints.

Run this in your terminal (from project root):
```
cd android
gradlew signingReport
```

Copy the **SHA1** and **SHA-256** from the **debug** section.

Then:
1. Firebase Console → **Project Settings** (gear icon)
2. Scroll to **Your apps** → click your Android app (`com.example.uddoygi`)
3. Click **Add fingerprint**
4. Paste SHA1 → Save
5. Click **Add fingerprint** again
6. Paste SHA-256 → Save
7. **Download the new `google-services.json`**
8. Replace `android/app/google-services.json` with the new one

### Step 3 — Verify phone number format in My Company
1. Open the app → Admin Dashboard → My Company
2. Check the phone number stored
3. It must be in one of these formats:
   - `01XXXXXXXXX` (11 digits, Bangladesh local)
   - `+8801XXXXXXXXX` (E.164 international)
4. The app will auto-convert to E.164 before sending OTP

### Step 4 — Test phone numbers (optional, for testing without real SMS)
In Firebase Console → Authentication → Sign-in method → Phone:
- Scroll down to **Phone numbers for testing**
- Add: `+8801799499092` with test code `123456`
- This lets you test without real SMS charges

### Step 5 — Rebuild the app
```
flutter clean
flutter pub get
flutter run
```

---

## How to verify it's working
When you tap "Send OTP", check the debug console for:
- `OTP codeSent: verificationId=...` → SMS was sent ✅
- `OTP verificationFailed: ...` → See error code for diagnosis ❌

Common error codes:
- `invalid-phone-number` → Phone format wrong (check E.164)
- `quota-exceeded` → Too many OTPs sent (wait or use test numbers)
- `app-not-authorized` → SHA fingerprint not added in Firebase Console
- `missing-client-identifier` → SHA fingerprint issue
