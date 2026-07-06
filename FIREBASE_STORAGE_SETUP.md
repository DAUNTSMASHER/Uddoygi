# Firebase Storage Setup (Uddoygi)

**Quick start:**  
1. **Enable Storage** in [Firebase Console](https://console.firebase.google.com/project/uddyogi/storage) (click **Get started**).  
2. From project root run: `firebase deploy --only storage`.

---

This project uses **Firebase Storage** for:

| Path | Use |
|------|-----|
| `payment_slips/*` | Payment proof uploads (Marketing) and viewing (HR) |
| `notice_files/*` | Notice attachments |
| `notice_attachments/*` | Admin notice attachments |
| `applicants/*` | Recruitment / applicant files |
| Other paths | Product images, task attachments, etc. |

---

## 1. Enable Storage in Firebase Console (do this first)

Storage must be enabled once in the Firebase project before you can deploy rules or use it from the app.

1. Open: **[Firebase Console → Storage for uddyogi](https://console.firebase.google.com/project/uddyogi/storage)**  
2. Click **Get started** to create the default bucket.
3. Choose **production mode** (we use custom rules in step 2).
4. Pick a location (e.g. same as Firestore: `nam5` or your region) and confirm.

After this, the default bucket (e.g. `uddyogi.appspot.com`) exists and the Flutter app can use it.

---

## 2. Deploy Storage Rules

Rules are in `storage.rules`. They allow **read/write for any signed-in user** so that:

- Marketing can upload payment proofs.
- HR can view proofs and delete files on reject/expiry.
- Notice and recruitment uploads work for authenticated users.

From the project root (where `firebase.json` and `storage.rules` are):

```bash
firebase deploy --only storage
```

You should see:

```
✔  Deploy complete!
```

---

## 3. Verify in the App

- **Marketing**: Submit a payment slip with an attached proof (image/PDF).  
  Check Firestore: the slip document should have `fileUrl` and `filePath`.
- **HR**: Open that slip in Payment Slip Approvals. The proof should load in the “Attached Document” section.

If the proof does not load:

- Confirm Storage is enabled and the default bucket exists.
- Confirm rules are deployed: in Console → Storage → Rules, you should see `allow read, write: if request.auth != null;`.
- Ensure the user is **signed in** (rules require `request.auth != null`).

---

## 4. Current Rules Reference

```hcl
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

To restrict by path or role later, you can narrow the `match` (e.g. `match /payment_slips/{path}`) and add Firestore-based checks.

---

## 5. Flutter / Firebase Config

- **Dependency**: `firebase_storage: ^13.0.3` in `pubspec.yaml`.
- **Initialization**: No extra call needed; `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` in `main.dart` is enough. The app uses the default Storage bucket via `FirebaseStorage.instance`.
- **Config**: `firebase.json` already includes `"storage": { "rules": "storage.rules" }`.

No code changes are required for basic setup once Storage is enabled and rules are deployed.
