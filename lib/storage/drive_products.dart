// lib/drive_product.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _darkBlue = Color(0xFF0D47A1);
// your target Drive folder
const String _driveFolderId = '14Qws-stNhY1966KoPECG95nyY1c4bITw';

class DriveProductPage extends StatefulWidget {
  /// the Firestore ID of the product document
  final String productId;
  /// the model name (used in the filename)
  final String modelName;
  /// the colour (used in the filename)
  final String colour;

  const DriveProductPage({
    Key? key,
    required this.productId,
    required this.modelName,
    required this.colour,
  }) : super(key: key);

  @override
  _DriveProductPageState createState() => _DriveProductPageState();
}

class _DriveProductPageState extends State<DriveProductPage> {
  bool _loading = false;
  double _progress = 0.0;

  // replace with your OAuth client ID
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
    _googleSignIn.onCurrentUserChanged.listen((acct) {
      _currentUser = acct;
    });
    _googleSignIn.signInSilently().then((acct) {
      _currentUser = acct;
    }).catchError((_) {});
  }

  Future<auth.AuthClient> _getClient() async {
    if (_currentUser == null) {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) {
        throw Exception('Google sign‑in cancelled');
      }
    }
    final headers = await _currentUser!.authHeaders;
    final token = headers['Authorization']!.split(' ').last;
    final creds = auth.AccessCredentials(
      auth.AccessToken('Bearer', token, DateTime.now().toUtc().add(const Duration(hours: 1))),
      null,
      _googleSignIn.scopes,
    );
    return auth.authenticatedClient(http.Client(), creds);
  }

  Future<void> _deleteOld(drive.DriveApi api, String prefix) async {
    final q = "'$_driveFolderId' in parents and name contains '$prefix' and trashed=false";
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

  Future<void> _pickAndUpload() async {
    setState(() {
      _loading = true;
      _progress = 0;
    });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final client = await _getClient();
      final api = drive.DriveApi(client);

      // build filename
      final ext = p.extension(file.path);
      final prefix = '${widget.modelName}_${widget.colour}';
      final filename = '$prefix$ext';

      // delete any old
      await _deleteOld(api, prefix);

      // upload with progress
      final total = await file.length();
      int sent = 0;
      final media = drive.Media(
        file.openRead().map((chunk) {
          sent += chunk.length;
          setState(() => _progress = sent / total);
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

      // make public
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        created.id!,
        supportsAllDrives: true,
      );

      final url = 'https://drive.google.com/uc?id=${created.id}';

      // update Firestore
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({'imageUrl': url});

      if (mounted) Navigator.pop(context, url);
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
      appBar: AppBar(
        title: const Text('Upload Product Image'),
        backgroundColor: _darkBlue,
      ),
      body: Center(
        child: _loading
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _progress),
            const SizedBox(height: 12),
            Text('${(_progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: _darkBlue)),
          ],
        )
            : ElevatedButton.icon(
          icon: const Icon(Icons.photo_camera, color: Colors.white),
          label: const Text('Select & Upload',
              style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor: _darkBlue, padding: const EdgeInsets.all(14)),
          onPressed: _pickAndUpload,
        ),
      ),
    );
  }
}
