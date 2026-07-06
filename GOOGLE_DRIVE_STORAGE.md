# Google Drive as Cloud Storage

The app uses **Google Drive** for storing and loading images and files (e.g. payment slip proofs, with more flows to follow). Files are uploaded to a shared Drive folder and made viewable via direct links so they load in the app and in browsers.

---

## 1. One-time setup: Drive folder

1. In [Google Drive](https://drive.google.com), create a folder (e.g. **Uddoygi uploads**).
2. Open the folder and copy its ID from the URL:
   - URL format: `https://drive.google.com/drive/folders/<FOLDER_ID>`
3. Put that ID in the app:
   - **`lib/services/drive_storage_service.dart`**  
     Update the constant:
     ```dart
     const String kDriveStorageFolderId = 'YOUR_FOLDER_ID_HERE';
     ```
   - Existing placeholder: `14Qws-stNhY1966KoPECG95nyY1c4bITw` (replace with your folder ID if different).

4. **Google Cloud / OAuth**
   - The app uses **Google Sign-In** with Drive scopes. Ensure your Firebase/Google project has the **Drive API** enabled and OAuth consent configured so the app can upload and set sharing.
   - In [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Enable **Google Drive API** for the project used by the app.

---

## 2. How it works

- **Upload:** User picks a file → app uses `DriveStorageService.instance.uploadFile(...)` → file is uploaded to the folder, shared as “anyone with the link can view”, and the app gets a **view URL** (`https://drive.google.com/uc?id=FILE_ID`).
- **Loading:** That URL is stored in Firestore (e.g. `fileUrl`). The app loads images with `Image.network(fileUrl)` and opens PDFs in the browser; Drive’s `uc?id=...` URLs work for both.
- **Delete (e.g. on slip reject):** If the stored reference is a Drive file ID, the app calls `DriveStorageService.instance.deleteFile(fileId)`.

---

## 3. Where Drive is used (all file/image uploads)

| Feature              | Use                                    |
|----------------------|----------------------------------------|
| Payment slip proof   | Marketing upload → HR view / delete    |
| Notices              | Admin, HR, Marketing, Factory attachments |
| Products             | Product images                         |
| Company profile      | Logo, signature, seal images           |
| Recruitment          | Applicant PDFs/files                   |
| Task assignments     | Task submission attachments            |

All of these now store files in Google Drive and use the view URL for loading. Legacy Firebase Storage URLs/paths are still supported for loading and delete where applicable (e.g. HR slip approval).

---

## 4. Using Drive from other screens

```dart
import 'package:uddoygi/services/drive_storage_service.dart';

// Upload
final result = await DriveStorageService.instance.uploadFile(
  file,
  pathPrefix: 'notice_files',  // or 'products', 'company_logo', etc.
  customName: 'optional_name.pdf',
  onProgress: (p) => setState(() {}),
);
// result.viewUrl  → use in Image.network() or open in browser
// result.fileId   → store if you need to delete later

// Build URL from stored file ID (e.g. when fileUrl is missing)
final url = DriveStorageService.viewUrlFromId(storedFileId);

// Delete (e.g. on reject)
await DriveStorageService.instance.deleteFile(fileId);
```

The user may be prompted to sign in with Google the first time they upload (Drive scope). Same account is reused for subsequent uploads in that session.
