import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const Color _darkBlue = Color(0xFF0D47A1);
const String _driveFolderId = '14Qws-stNhY1966KoPECG95nyY1c4bITw';

class DrivePage extends StatefulWidget {
  final String uid;
  final String field;      // 'profilePhotoUrl' or 'cvUrl'
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
  _DrivePageState createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  bool _loading = false;
  double _uploadProgress = 0.0;

  static const String _webClientId =
      '308795588138-e197ov8m7988apulm8fq99nngkkga07m.apps.googleusercontent.com';
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
    serverClientId: _webClientId,
  );
  GoogleSignInAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((acct) => _currentUser = acct);
    _googleSignIn.signInSilently().then((acct) => _currentUser = acct).catchError((_) {});
  }

  Future<auth.AuthClient> _getAuthClient() async {
    if (_currentUser == null) {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) throw Exception('Google Sign‑In cancelled');
    }
    final headers = await _currentUser!.authHeaders;
    final token = headers['Authorization']!.substring(7);
    final creds = auth.AccessCredentials(
      auth.AccessToken('Bearer', token, DateTime.now().toUtc().add(const Duration(hours: 1))),
      null,
      _googleSignIn.scopes,
    );
    return auth.authenticatedClient(http.Client(), creds);
  }

  /// Delete any existing files in the Drive folder matching our naming prefix
  Future<void> _deleteExisting(drive.DriveApi api, String prefix) async {
    // search for files in the folder with names starting with prefix
    final q = "'$_driveFolderId' in parents and name contains '$prefix' and trashed = false";
    final list = await api.files.list(
      q: q,
      spaces: 'drive',
      supportsAllDrives: true,
      includeItemsFromAllDrives: true,
    );
    if (list.files == null) return;
    for (var f in list.files!) {
      if (f.id != null) {
        await api.files.delete(f.id!, supportsAllDrives: true);
      }
    }
  }

  Future<String?> _uploadToDrive(File file) async {
    setState(() => _uploadProgress = 0);
    final client = await _getAuthClient();
    final api = drive.DriveApi(client);

    final ext = p.extension(file.path);
    final prefix = widget.employeeId;
    final filename = widget.field == 'profilePhotoUrl'
        ? '${prefix}_profile_picture$ext'
        : widget.field == 'cvUrl'
        ? '${prefix}_cv$ext'
        : '${prefix}_${widget.field}_${DateTime.now().millisecondsSinceEpoch}$ext';

    // 1) Remove old files with same prefix
    await _deleteExisting(api, '${prefix}_${widget.field == 'profilePhotoUrl' ? 'profile_picture' : 'cv'}');

    // 2) Upload the new one
    final total = file.lengthSync();
    int sent = 0;
    final media = drive.Media(
      file.openRead().map((chunk) {
        sent += chunk.length;
        setState(() => _uploadProgress = sent / total);
        return chunk;
      }),
      total,
    );

    final created = await api.files.create(
      drive.File()
        ..name = filename
        ..parents = [_driveFolderId],
      uploadMedia: media,
      supportsAllDrives: true,
    );

    // 3) Make publicly readable
    await api.permissions.create(
      drive.Permission()
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
            ? Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(value: _uploadProgress),
          const SizedBox(height: 12),
          Text('${(_uploadProgress * 100).toStringAsFixed(1)}%'),
        ])
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
