// lib/storage/drive_products.dart
//
// Product image upload via Google Drive. Uses the shared DriveStorageService
// so all app uploads use the same folder and view URL format for image showing.
//

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/drive_storage_service.dart';
import 'package:uddoygi/services/local_storage_service.dart';

const Color _darkBlue = Color(0xFF2A0A4B);

class DriveProductPage extends StatefulWidget {
  final String productId;
  final String modelName;
  final String colour;

  const DriveProductPage({
    super.key,
    required this.productId,
    required this.modelName,
    required this.colour,
  });

  @override
  State<DriveProductPage> createState() => _DriveProductPageState();
}

class _DriveProductPageState extends State<DriveProductPage> {
  String _cid = '';
  bool _loading = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
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
      final prefix = '${widget.modelName}_${widget.colour}';
      await DriveStorageService.instance.deleteFilesWithNameContaining(prefix);

      final ext = p.extension(file.path);
      final customName = '$prefix$ext';

      final driveResult = await DriveStorageService.instance.uploadFile(
        file,
        pathPrefix: 'product_images',
        customName: customName,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p.clamp(0.0, 1.0));
        },
      );
      final url = driveResult.viewUrl;

      await DB.colSync(_cid, C.products)
          .doc(widget.productId)
          .update({'imageUrl': url});

      if (mounted) Navigator.pop(context, url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Product Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
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
          label: const Text('Select & Upload', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor: _darkBlue, padding: const EdgeInsets.all(14)),
          onPressed: _pickAndUpload,
        ),
      ),
    );
  }
}
