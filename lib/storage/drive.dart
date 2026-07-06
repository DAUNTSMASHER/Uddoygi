// lib/storage/drive.dart
//
// Profile photo and CV upload via Google Drive. Uses the shared DriveStorageService
// so all app uploads (images, files, payment proofs, notices, etc.) go to the same
// Drive folder and return the same view URL format for image showing.
//

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uddoygi/services/drive_storage_service.dart';

const Color _darkBlue = Color(0xFF2A0A4B);

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

  Future<String?> _uploadToDrive(File file) async {
    setState(() => _uploadProgress = 0);

    final prefix = widget.employeeId;
    final cleanPrefix = widget.field == 'profilePhotoUrl' ? 'profile_picture' : 'cv';
    await DriveStorageService.instance.deleteFilesWithNameContaining('${prefix}_$cleanPrefix');

    final ext = p.extension(file.path);
    final customName = switch (widget.field) {
      'profilePhotoUrl' => '${prefix}_profile_picture$ext',
      'cvUrl'           => '${prefix}_cv$ext',
      _                 => '${prefix}_${widget.field}_${DateTime.now().millisecondsSinceEpoch}$ext',
    };

    final result = await DriveStorageService.instance.uploadFile(
      file,
      pathPrefix: 'profile_cv',
      customName: customName,
      onProgress: (p) {
        if (mounted) setState(() => _uploadProgress = p.clamp(0.0, 1.0));
      },
    );
    return result.viewUrl;
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
      appBar: AppBar(
        title: const Text('Upload File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
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
