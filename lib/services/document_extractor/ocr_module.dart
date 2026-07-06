// lib/services/document_extractor/ocr_module.dart
//
// OCR Module — extracts raw text from images using ML Kit on-device OCR.
// For PDFs, falls back to byte-scanning (works for text-embedded PDFs).
// Returns a structured OcrResult with the full text and per-block lines.

import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;

// ── Result ────────────────────────────────────────────────────────────────────
class OcrResult {
  /// Full concatenated text from all blocks.
  final String fullText;

  /// Individual text blocks in reading order (top→bottom, left→right).
  final List<OcrBlock> blocks;

  /// Whether this came from real OCR (true) or fallback byte-scan (false).
  final bool isRealOcr;

  const OcrResult({
    required this.fullText,
    required this.blocks,
    required this.isRealOcr,
  });
}

class OcrBlock {
  final String text;
  final int topY;    // approximate vertical position (for layout parsing)
  final int leftX;   // approximate horizontal position
  final int width;
  final int height;

  const OcrBlock({
    required this.text,
    required this.topY,
    required this.leftX,
    required this.width,
    required this.height,
  });
}

// ── OCR Module ────────────────────────────────────────────────────────────────
class OcrModule {
  static final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Main entry point — auto-detects file type and picks the right strategy.
  static Future<OcrResult> extract(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.pdf') {
      return _extractFromPdf(file);
    }
    return _extractFromImage(file);
  }

  // ── Image OCR via ML Kit ──────────────────────────────────────────────────
  static Future<OcrResult> _extractFromImage(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final recognized = await _recognizer.processImage(inputImage);

      final blocks = <OcrBlock>[];
      final fullBuffer = StringBuffer();

      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final rect = line.boundingBox;
          blocks.add(OcrBlock(
            text:   line.text,
            topY:   rect.top.round(),
            leftX:  rect.left.round(),
            width:  rect.width.round(),
            height: rect.height.round(),
          ));
          fullBuffer.writeln(line.text);
        }
      }

      // Sort blocks top-to-bottom for layout-aware parsing
      blocks.sort((a, b) => a.topY.compareTo(b.topY));

      return OcrResult(
        fullText:  fullBuffer.toString(),
        blocks:    blocks,
        isRealOcr: true,
      );
    } catch (e) {
      // If ML Kit fails (e.g. unsupported format), fall back to byte scan
      return _byteFallback(file);
    }
  }

  // ── PDF text extraction (byte scan for text-embedded PDFs) ───────────────
  static Future<OcrResult> _extractFromPdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final text  = _extractTextFromPdfBytes(bytes);
      if (text.trim().length > 30) {
        final lines = text.split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        final blocks = lines.asMap().entries.map((e) => OcrBlock(
          text:   e.value,
          topY:   e.key * 20,
          leftX:  0,
          width:  400,
          height: 18,
        )).toList();
        return OcrResult(fullText: text, blocks: blocks, isRealOcr: false);
      }
    } catch (_) {}
    return _byteFallback(file);
  }

  // ── Generic byte fallback (printable ASCII from any file) ────────────────
  static Future<OcrResult> _byteFallback(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final text  = _extractPrintableAscii(bytes);
      final lines = text.split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final blocks = lines.asMap().entries.map((e) => OcrBlock(
        text:   e.value,
        topY:   e.key * 20,
        leftX:  0,
        width:  400,
        height: 18,
      )).toList();
      return OcrResult(fullText: text, blocks: blocks, isRealOcr: false);
    } catch (_) {
      return const OcrResult(fullText: '', blocks: [], isRealOcr: false);
    }
  }

  // ── PDF text stream extractor ─────────────────────────────────────────────
  // Extracts text from PDF BT/ET blocks (works for text-embedded PDFs).
  static String _extractTextFromPdfBytes(Uint8List bytes) {
    final raw = String.fromCharCodes(bytes);
    final buf = StringBuffer();

    // Extract text between BT and ET markers
    final btEt = RegExp(r'BT(.*?)ET', dotAll: true);
    for (final m in btEt.allMatches(raw)) {
      final block = m.group(1) ?? '';
      // Extract strings in parentheses: (text)
      final strPat = RegExp(r'\(([^)]*)\)');
      for (final sm in strPat.allMatches(block)) {
        final s = sm.group(1) ?? '';
        if (s.trim().isNotEmpty) buf.write('$s ');
      }
      buf.writeln();
    }

    // Also grab any readable strings not in BT/ET
    final fallback = _extractPrintableAscii(bytes);
    if (buf.isEmpty) return fallback;
    return buf.toString();
  }

  // ── Printable ASCII extractor ─────────────────────────────────────────────
  static String _extractPrintableAscii(Uint8List bytes) {
    final buf = StringBuffer();
    int run = 0;
    for (final b in bytes) {
      if ((b >= 32 && b < 127) || b == 10 || b == 13) {
        buf.writeCharCode(b);
        run++;
      } else {
        if (run > 3) buf.write(' ');
        run = 0;
      }
    }
    return buf.toString().substring(0, buf.length.clamp(0, 12000));
  }

  static void dispose() {
    _recognizer.close();
  }
}
