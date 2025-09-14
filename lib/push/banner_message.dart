// lib/push/banner_message.dart
import 'package:flutter/material.dart';

/// Centered, modal-style banner:
/// - 80% screen width
/// - 20% screen height
/// - Title strip with its own background color
/// - Body area with different background color
///
/// Tapping the banner (or the VIEW button) shows a dialog with:
///  - "You have a new message from @sender"
///  - Optional subject
///  - OK button
/// After OK, the dialog closes and the banner disappears.
class BannerMessage extends StatelessWidget {
  final String title;         // e.g. "New message"
  final String sender;        // e.g. "hr@ud.com"
  final String? subject;      // optional subtitle / subject
  final VoidCallback onClose; // called after dialog OK (to remove banner)

  /// Colors (customize as you like)
  final Color titleBgColor;   // header strip background
  final Color bodyBgColor;    // card body background
  final Color textColor;      // text inside title strip
  final Color bodyTextColor;  // text inside body
  final Color accentColor;    // icon/button accents

  const BannerMessage({
    super.key,
    required this.title,
    required this.sender,
    required this.onClose,
    this.subject,
    this.titleBgColor = const Color(0xFF0D47A1), // deep blue header
    this.bodyBgColor = const Color(0xFFF7F9FC),  // light body
    this.textColor = Colors.white,
    this.bodyTextColor = const Color(0xFF0F172A), // slate-900-ish
    this.accentColor = const Color(0xFF0D47A1),
  });

  Future<void> _openDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: Text(
          'Message',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have a new message from @$sender',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if ((subject ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Subject:',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subject!,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    // After the dialog is dismissed, remove the banner.
    onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.8,  // 80% width
        heightFactor: 0.2, // 20% height
        child: Material(
          color: Colors.transparent,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: titleBgColor,
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        onPressed: onClose,
                        icon: Icon(Icons.close_rounded, color: textColor),
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: InkWell(
                    onTap: () => _openDialog(context),
                    child: Container(
                      color: bodyBgColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor.withOpacity(0.25)),
                            ),
                            child: Icon(Icons.mark_unread_chat_alt_rounded, color: accentColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'You have a new message from @$sender',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: bodyTextColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                if ((subject ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '“$subject” • tap to view',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: bodyTextColor.withOpacity(0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () => _openDialog(context),
                            style: TextButton.styleFrom(
                              foregroundColor: accentColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: const Text(
                              'VIEW',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
