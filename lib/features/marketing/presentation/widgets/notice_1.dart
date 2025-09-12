import 'package:flutter/material.dart';

class NoticeComposerBar extends StatelessWidget {
  /// NEW: pass both name & photo (instead of only a URL)
  final String displayName;
  final String? photoUrl;

  final String hintText;
  final VoidCallback onStartCompose;
  final VoidCallback onAddMedia;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;

  const NoticeComposerBar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.hintText = 'Ask a question or start a post',
    required this.onStartCompose,
    required this.onAddMedia,
    required this.categories,
    this.selectedCategory,
    required this.onCategoryChanged,
  });

  static const _brandBlue = Color(0xFF1D5DF1);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Avatar with initials fallback (like AllEmployeesPage)
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _brandBlue,
                  backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? Text(
                    _initials(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onStartCompose,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      height: 44,
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ghostButton(
                  icon: Icons.perm_media_outlined,
                  label: 'Add media',
                  onTap: onAddMedia,
                ),
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
          isDense: true,
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

  static Widget _ghostButton({
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
            const Icon(Icons.perm_media_outlined, size: 18, color: _brandBlue),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// same helper you used in AllEmployeesPage
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
