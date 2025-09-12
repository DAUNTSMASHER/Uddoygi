// lib/widgets/notice_6.dart
import 'package:flutter/material.dart';

class NoticeComposerInlineLarge extends StatelessWidget {
  final String avatarUrl;
  final String hintText;
  final VoidCallback onStartCompose;
  final VoidCallback onAddMedia;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;

  const NoticeComposerInlineLarge({
    super.key,
    required this.avatarUrl,
    this.hintText = 'Ask a question or start a post',
    required this.onStartCompose,
    required this.onAddMedia,
    required this.categories,
    this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatarUrl)),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onStartCompose,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      height: 46,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F6),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFD5DBE7)),
                      ),
                      child: Text(
                        hintText,
                        style: const TextStyle(color: Color(0xFF98A2B3), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ghost(
                  icon: Icons.perm_media_outlined,
                  label: 'Add media',
                  onTap: onAddMedia,
                ),
                const SizedBox(width: 12),
                _categoryDropdown(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD5DBE7)),
        ),
        child: DropdownButton<String>(
          value: selectedCategory,
          hint: const Text('Add Category'),
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: onCategoryChanged,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
          dropdownColor: Colors.white,
        ),
      ),
    );
  }

  static Widget _ghost({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD5DBE7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1D5DF1)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
