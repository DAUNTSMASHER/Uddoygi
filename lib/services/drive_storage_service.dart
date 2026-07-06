// lib/services/drive_storage_service.dart
//
// Google Drive as cloud storage for images and files.
// Uploads files to a shared Drive folder and returns a direct view/download URL
// (https://drive.google.com/uc?id=FILE_ID) so they can be loaded in Image.network
// or opened in browser (PDFs).
//

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Default folder ID for Uddoygi app uploads. Create a folder in Google Drive,
/// share it with the account that signs in, and put its ID here.
/// Get ID from the folder URL: drive.google.com/drive/folders/FOLDER_ID
const String kDriveStorageFolderId = '14Qws-stNhY1966KoPECG95nyY1c4bITw';

/// Injects Google auth headers into HTTP requests for Drive API.
class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

/// Result of uploading a file to Google Drive.
class DriveUploadResult {
  const DriveUploadResult({
    required this.viewUrl,
    required this.fileId,
  });
  /// URL suitable for Image.network or opening in browser (e.g. PDF).
  final String viewUrl;
  /// Drive file ID (useful for delete or future reference).
  final String fileId;
}

/// Service for uploading and referencing files in Google Drive.
/// Uses Google Sign-In with Drive scopes; user may be prompted to sign in
/// when first uploading.
class DriveStorageService {
  DriveStorageService._();
  static final DriveStorageService instance = DriveStorageService._();

  gsi.GoogleSignIn? _gsi;
  gsi.GoogleSignInAccount? _currentUser;

  gsi.GoogleSignIn get _signIn {
    _gsi ??= gsi.GoogleSignIn(
      scopes: <String>[
        gdrive.DriveApi.driveFileScope,
        gdrive.DriveApi.driveMetadataScope,
      ],
    );
    return _gsi!;
  }

  /// Get Drive API client (triggers sign-in if needed).
  Future<gdrive.DriveApi> _getDriveApi() async {
    _currentUser ??= await _signIn.signInSilently();
    _currentUser ??= await _signIn.signIn();
    if (_currentUser == null) throw Exception('Google Sign-In required for Drive upload');
    final headers = await _currentUser!.authHeaders;
    final client = _GoogleAuthClient(headers);
    return gdrive.DriveApi(client);
  }

  /// Upload a file to the configured Drive folder and make it viewable by link.
  /// [pathPrefix] e.g. 'payment_slips' or 'notice_files' — used in the file name.
  /// Returns view URL (https://drive.google.com/uc?id=...) and file ID.
  /// Throws on cancel or API error.
  Future<DriveUploadResult> uploadFile(
    File file, {
    required String pathPrefix,
    String? customName,
    void Function(double progress)? onProgress,
  }) async {
    final api = await _getDriveApi();
    final ext = p.extension(file.path);
    final name = customName ?? '${pathPrefix}_${DateTime.now().millisecondsSinceEpoch}$ext';

    final total = await file.length();
    var sent = 0.0;

    final media = gdrive.Media(
      file.openRead().map((chunk) {
        sent += chunk.length;
        onProgress?.call(total > 0 ? sent / total : 0);
        return chunk;
      }),
      total,
    );

    final created = await api.files.create(
      gdrive.File()
        ..name = name
        ..parents = <String>[kDriveStorageFolderId],
      uploadMedia: media,
      supportsAllDrives: true,
    );

    final fileId = created.id!;

    await api.permissions.create(
      gdrive.Permission()
        ..type = 'anyone'
        ..role = 'reader',
      fileId,
      supportsAllDrives: true,
    );

    final viewUrl = 'https://drive.google.com/uc?id=$fileId';
    return DriveUploadResult(viewUrl: viewUrl, fileId: fileId);
  }

  /// Upload from bytes (e.g. FilePicker withData). Writes to temp file then uploads.
  Future<DriveUploadResult> uploadFromBytes(
    List<int> bytes, {
    required String pathPrefix,
    String? customName,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final ext = customName != null && customName.contains('.')
        ? '.${customName.split('.').last}'
        : '';
    final tmp = File('${dir.path}/upload_${DateTime.now().millisecondsSinceEpoch}$ext');
    await tmp.writeAsBytes(bytes);
    try {
      return await uploadFile(
        tmp,
        pathPrefix: pathPrefix,
        customName: customName ?? 'upload$ext',
        onProgress: onProgress,
      );
    } finally {
      try { await tmp.delete(); } catch (_) {}
    }
  }

  /// Build a view URL from a Drive file ID (for loading when you only have ID stored).
  static String viewUrlFromId(String fileId) {
    return 'https://drive.google.com/uc?id=$fileId';
  }

  /// Delete a file from Drive by ID (e.g. when slip is rejected).
  Future<void> deleteFile(String fileId) async {
    final api = await _getDriveApi();
    await api.files.delete(fileId, supportsAllDrives: true);
  }

  /// Delete all files in the app folder whose name contains [prefix].
  /// Used by profile/CV and product image flows to replace old file before upload.
  Future<void> deleteFilesWithNameContaining(String prefix) async {
    final api = await _getDriveApi();
    final q = "'$kDriveStorageFolderId' in parents and name contains '$prefix' and trashed = false";
    final list = await api.files.list(
      q: q,
      spaces: 'drive',
      supportsAllDrives: true,
      includeItemsFromAllDrives: true,
    );
    for (final f in list.files ?? const <gdrive.File>[]) {
      if (f.id != null) {
        try {
          await api.files.delete(f.id!, supportsAllDrives: true);
        } catch (_) {}
      }
    }
  }

  /// Whether the stored URL is a Google Drive URL (uc?id=...).
  static bool isDriveUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('drive.google.com') && url.contains('id=');
  }

  /// Extract Drive file ID from view URL (e.g. https://drive.google.com/uc?id=FILE_ID).
  /// Returns null if not a Drive view URL.
  static String? fileIdFromViewUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    return uri.queryParameters['id'];
  }
}
