// lib/storage/drive.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

// ✅ Always alias the plugin so nothing can shadow it.
import 'package:google_sign_in/google_sign_in.dart' as gsi;

// Google Drive REST API
import 'package:googleapis/drive/v3.dart' as gdrive;

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const Color _darkBlue = Color(0xFF0D47A1);

// TODO: replace with your real Drive folder ID
const String _driveFolderId = '14Qws-stNhY1966KoPECG95nyY1c4bITw';

/// Injects Google auth headers into every HTTP request.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class DrivePage extends StatefulWidget {
  final String uid;
  /// 'profilePhotoUrl' or 'cvUrl' (or your own custom field)
  final String field;
  final String userEmail;
  final String employeeId; // e.g. '1514'

  const DrivePage({
    super.key,
    required this.uid,
    required this.field,
    required this.userEmail,
    required this.employeeId,
  });

  @override
  State<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  bool _loading = false;
  double _uploadProgress = 0.0;

  // Request only the scopes you need.
  final gsi.GoogleSignIn _gsi = gsi.GoogleSignIn(
    scopes: <String>[
      gdrive.DriveApi.driveFileScope,      // create/update files used by this app
      gdrive.DriveApi.driveMetadataScope,  // list/search for cleanup
    ],
  );

  gsi.GoogleSignInAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    _gsi.onCurrentUserChanged.listen((acct) => _currentUser = acct);
    _gsi.signInSilently().then((acct) => _currentUser = acct).catchError((_) {});
  }

  /// Build DriveApi using the account's auth headers (no googleapis_auth needed).
  Future<gdrive.DriveApi> _getDriveApi() async {
    _currentUser ??= await _gsi.signIn();
    if (_currentUser == null) throw Exception('Google Sign-In cancelled');

    final headers = await _currentUser!.authHeaders;
    final client = GoogleAuthClient(headers);
    return gdrive.DriveApi(client);
  }

  /// Delete existing files in the folder whose names contain [prefix].
  Future<void> _deleteExisting(gdrive.DriveApi api, String prefix) async {
    final q = "'$_driveFolderId' in parents and name contains '$prefix' and trashed = false";
    final list = await api.files.list(
      q: q,
      spaces: 'drive',
      supportsAllDrives: true,
      includeItemsFromAllDrives: true,
    );
    for (final f in list.files ?? const <gdrive.File>[]) {
      final id = f.id;
      if (id != null) {
        await api.files.delete(id, supportsAllDrives: true);
      }
    }
  }

  Future<String?> _uploadToDrive(File file) async {
    setState(() => _uploadProgress = 0);

    final api = await _getDriveApi();

    final ext = p.extension(file.path);
    final prefix = widget.employeeId;
    final filename = switch (widget.field) {
      'profilePhotoUrl' => '${prefix}_profile_picture$ext',
      'cvUrl'           => '${prefix}_cv$ext',
      _                 => '${prefix}_${widget.field}_${DateTime.now().millisecondsSinceEpoch}$ext',
    };

    // Remove old files with same logical prefix
    final cleanPrefix = widget.field == 'profilePhotoUrl' ? 'profile_picture' : 'cv';
    await _deleteExisting(api, '${prefix}_$cleanPrefix');

    final total = await file.length();
    var sent = 0;

    final media = gdrive.Media(
      file.openRead().map((chunk) {
        sent += chunk.length;
        setState(() => _uploadProgress = sent / total);
        return chunk;
      }),
      total,
    );

    final created = await api.files.create(
      gdrive.File()
        ..name = filename
        ..parents = <String>[_driveFolderId],
      uploadMedia: media,
      supportsAllDrives: true,
    );

    // Public read (adjust if you want restricted sharing)
    await api.permissions.create(
      gdrive.Permission()
        ..type = 'anyone'
        ..role = 'reader',
      created.id!,
      supportsAllDrives: true,
    );

    return 'https://drive.google.com/uc?id=${created.id}';
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _loading = true;
      _uploadProgress = 0;
    });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final url = await _uploadToDrive(file);
      if (mounted && url != null) Navigator.pop(context, url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload File'), backgroundColor: _darkBlue),
      body: Center(
        child: _loading
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 12),
            Text('${(_uploadProgress * 100).toStringAsFixed(1)}%'),
          ],
        )
            : ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text('Select & Upload'),
          style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
          onPressed: _pickAndUpload,
        ),
      ),
    );
  }
}
