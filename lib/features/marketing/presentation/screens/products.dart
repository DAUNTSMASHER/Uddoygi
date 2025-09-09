// lib/features/marketing/presentation/screens/products_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const Color _ink = Color(0xFF1D5DF1);

enum _Sort { newest, priceLowHigh, priceHighLow }

// ——— helpers (top-level so every widget can use them) ———
String _fmtDate(Timestamp? ts) =>
    ts == null ? '—' : DateFormat('dd MMM, yyyy').format(ts.toDate());
String _money(num n) => '৳${NumberFormat.decimalPattern().format(n)}';

class ProductsPage extends StatefulWidget {
  final String userEmail;
  const ProductsPage({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // ------- form state -------
  final _formKey = GlobalKey<FormState>();
  final _editFormKey = GlobalKey<FormState>();
  String? _gender;
  File? _pickedImage;
  final _picker = ImagePicker();

  final _model = TextEditingController();
  final _size = TextEditingController();
  final _density = TextEditingController();
  final _curl = TextEditingController();
  final _colour = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();
  final _time = TextEditingController();
  final _cost = TextEditingController();

  // ------- ui state -------
  int _currentTab = 0;
  String _search = '';
  String _genderFilter = 'All'; // All / Male / Female
  _Sort _sort = _Sort.newest;
  bool _gridMode = true;
  bool _hideArchived = true;

  @override
  void dispose() {
    _model.dispose();
    _size.dispose();
    _density.dispose();
    _curl.dispose();
    _colour.dispose();
    _price.dispose();
    _notes.dispose();
    _time.dispose();
    _cost.dispose();
    super.dispose();
  }

  // ——— UI theming helpers ———
  InputDecoration get _decoration => InputDecoration(
    filled: true,
    fillColor: Colors.grey.shade100,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(10),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _darkBlue, width: 1.2),
      borderRadius: BorderRadius.circular(10),
    ),
  );

  // ——— image helpers ———
  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    final x = await _picker.pickImage(source: source, imageQuality: 80);
    if (x != null) setState(() => _pickedImage = File(x.path));
  }

  Future<String> _uploadImage(File image) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('product_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  // ——— form helpers ———
  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _gender = null;
      _pickedImage = null;
    });
    _model.clear();
    _size.clear();
    _density.clear();
    _curl.clear();
    _colour.clear();
    _price.clear();
    _notes.clear();
    _time.clear();
    _cost.clear();
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;
    String? imageUrl;
    if (_pickedImage != null) imageUrl = await _uploadImage(_pickedImage!);

    final data = {
      'gender': _gender,
      'model_name': _model.text.trim(),
      'size': _size.text.trim(),
      'density': _density.text.trim(),
      'curl': _curl.text.trim(),
      'colour': _colour.text.trim(),
      'unit_price': double.tryParse(_price.text) ?? 0,
      'notes': _notes.text.trim(),
      'production_time': _time.text.trim(),
      'production_cost': double.tryParse(_cost.text) ?? 0,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': widget.userEmail,
      'archived': false,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };

    await FirebaseFirestore.instance.collection('products').add(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Product added')),
    );
    _resetForm();
  }

  void _prefillForm(Map<String, dynamic> p) {
    setState(() {
      _currentTab = 0;
      _gender = p['gender'] as String?;
      _model.text = p['model_name'] ?? '';
      _size.text = p['size'] ?? '';
      _density.text = p['density'] ?? '';
      _curl.text = p['curl'] ?? '';
      _colour.text = p['colour'] ?? '';
      _price.text = ((p['unit_price'] ?? 0).toString());
      _notes.text = p['notes'] ?? '';
      _time.text = p['production_time'] ?? '';
      _cost.text = ((p['production_cost'] ?? 0).toString());
      _pickedImage = null;
    });
  }

  // ——— edit dialog ———
  Future<void> _showEditDialog(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final p = doc.data()!;
    setState(() {
      _gender = p['gender'] as String?;
      _model.text = p['model_name'] ?? '';
      _size.text = p['size'] ?? '';
      _density.text = p['density'] ?? '';
      _curl.text = p['curl'] ?? '';
      _colour.text = p['colour'] ?? '';
      _price.text = (p['unit_price'] ?? '').toString();
      _notes.text = p['notes'] ?? '';
      _time.text = p['production_time'] ?? '';
      _cost.text = (p['production_cost'] ?? '').toString();
      _pickedImage = null;
    });

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Product'),
          content: SingleChildScrollView(
            child: Form(
              key: _editFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: _decoration.copyWith(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _model,
                    decoration:
                    _decoration.copyWith(labelText: 'Model Name'),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _size,
                          decoration:
                          _decoration.copyWith(labelText: 'Size'),
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _density,
                          decoration:
                          _decoration.copyWith(labelText: 'Density'),
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _curl,
                          decoration:
                          _decoration.copyWith(labelText: 'Curl'),
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _colour,
                          decoration:
                          _decoration.copyWith(labelText: 'Colour'),
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: _decoration.copyWith(
                              labelText: 'Unit Price'),
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _cost,
                          keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: _decoration.copyWith(
                              labelText: 'Production Cost'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _time,
                    decoration:
                    _decoration.copyWith(labelText: 'Production Time'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notes,
                    decoration: _decoration.copyWith(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        onPressed: () =>
                            _pickImage(source: ImageSource.gallery),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Camera'),
                        onPressed: () =>
                            _pickImage(source: ImageSource.camera),
                      ),
                    ],
                  ),
                  if (_pickedImage != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_pickedImage!,
                          height: 110, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style:
              ElevatedButton.styleFrom(backgroundColor: _darkBlue),
              onPressed: () async {
                if (!_editFormKey.currentState!.validate()) return;
                String? imageUrl;
                if (_pickedImage != null) {
                  imageUrl = await _uploadImage(_pickedImage!);
                }
                final data = {
                  'gender': _gender,
                  'model_name': _model.text.trim(),
                  'size': _size.text.trim(),
                  'density': _density.text.trim(),
                  'curl': _curl.text.trim(),
                  'colour': _colour.text.trim(),
                  'unit_price': double.tryParse(_price.text) ?? 0,
                  'notes': _notes.text.trim(),
                  'production_time': _time.text.trim(),
                  'production_cost':
                  double.tryParse(_cost.text) ?? 0,
                  if (imageUrl != null) 'imageUrl': imageUrl,
                };
                await FirebaseFirestore.instance
                    .collection('products')
                    .doc(doc.id)
                    .update(data);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('✅ Product updated')));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ——— Build ———
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 600;

    return DefaultTabController(
      length: 2,
      initialIndex: _currentTab,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _darkBlue,
          title:
          const Text('Products', style: TextStyle(color: Colors.white)),
          bottom: TabBar(
            onTap: (i) => setState(() => _currentTab = i),
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'Add Product'), Tab(text: 'All Products')],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _HeaderStats(hideArchived: _hideArchived),
            ),
            if (_currentTab == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _toolbar(),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _currentTab == 0
                    ? _addForm(isWide)
                    : _productsList(grid: _gridMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ——— Add form (responsive with Wrap) ———
  Widget _addForm(bool wide) {
    final colW = wide ? (MediaQuery.of(context).size.width - 48) / 2
        : MediaQuery.of(context).size.width - 32;

    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      child: Form(
        key: _formKey,
        child: Wrap(
          runSpacing: 12,
          spacing: 12,
          children: [
            SizedBox(
              width: colW,
              child: DropdownButtonFormField<String>(
                value: _gender,
                decoration: _decoration.copyWith(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                ],
                onChanged: (v) => setState(() => _gender = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: colW,
              child: TextFormField(
                controller: _model,
                decoration: _decoration.copyWith(labelText: 'Model Name'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: colW,
              child: TextFormField(
                controller: _size,
                decoration: _decoration.copyWith(labelText: 'Size'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: colW,
              child: TextFormField(
                controller: _density,
                decoration: _decoration.copyWith(labelText: 'Density'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: colW,
              child: TextFormField(
                controller: _curl,
                decoration: _decoration.copyWith(labelText: 'Curl'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: colW,
              child: TextFormField(
                controller: _colour,
                decoration: _decoration.copyWith(labelText: 'Colour'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: colW,
              child: TextFormField(
                controller: _price,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoration.copyWith(labelText: 'Unit Price'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: colW,
              child: TextFormField(
                controller: _cost,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoration.copyWith(
                    labelText: 'Production Cost (optional)'),
              ),
            ),
            SizedBox(
              width: colW,
              child: TextFormField(
                controller: _time,
                decoration:
                _decoration.copyWith(labelText: 'Production Time'),
              ),
            ),
            SizedBox(
              width: colW,
              child: TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: _decoration.copyWith(labelText: 'Notes'),
              ),
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  onPressed: () => _pickImage(source: ImageSource.gallery),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                  onPressed: () => _pickImage(source: ImageSource.camera),
                ),
              ],
            ),
            if (_pickedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                Image.file(_pickedImage!, height: 120, fit: BoxFit.cover),
              ),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _darkBlue,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _addProduct,
                      child: const Text('Submit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _resetForm, child: const Text('Reset')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ——— Toolbar / Filters ———
  Widget _toolbar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search model / colour…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: _gridMode ? 'List view' : 'Grid view',
              onPressed: () => setState(() => _gridMode = !_gridMode),
              icon: Icon(
                _gridMode
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                color: _darkBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _genderFilter == 'All',
                onSelected: (_) => setState(() => _genderFilter = 'All'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Male'),
                selected: _genderFilter == 'Male',
                onSelected: (_) => setState(() => _genderFilter = 'Male'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Female'),
                selected: _genderFilter == 'Female',
                onSelected: (_) => setState(() => _genderFilter = 'Female'),
              ),
              const SizedBox(width: 12),
              DropdownButton<_Sort>(
                value: _sort,
                underline: const SizedBox.shrink(),
                onChanged: (v) => setState(() => _sort = v ?? _Sort.newest),
                items: const [
                  DropdownMenuItem(
                      value: _Sort.newest, child: Text('Newest')),
                  DropdownMenuItem(
                      value: _Sort.priceLowHigh, child: Text('Price ↑')),
                  DropdownMenuItem(
                      value: _Sort.priceHighLow, child: Text('Price ↓')),
                ],
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Hide archived'),
                selected: _hideArchived,
                onSelected: (v) => setState(() => _hideArchived = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ——— Query builder ———
  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q =
    FirebaseFirestore.instance.collection('products');

    if (_hideArchived) q = q.where('archived', isEqualTo: false);
    if (_genderFilter != 'All') {
      q = q.where('gender', isEqualTo: _genderFilter);
    }

    switch (_sort) {
      case _Sort.newest:
        q = q.orderBy('createdAt', descending: true);
        break;
      case _Sort.priceLowHigh:
        q = q.orderBy('unit_price').orderBy('createdAt', descending: true);
        break;
      case _Sort.priceHighLow:
        q = q
            .orderBy('unit_price', descending: true)
            .orderBy('createdAt', descending: true);
        break;
    }
    return q;
  }

  // ——— Products list/grid (adaptive, no overflow) ———
  Widget _productsList({required bool grid}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: const ValueKey('list'),
      stream: _query().snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data!.docs;

        // client-side search
        if (_search.trim().isNotEmpty) {
          final s = _search.toLowerCase();
          docs = docs.where((d) {
            final m = d.data();
            final a =
            (m['model_name'] ?? '').toString().toLowerCase();
            final b = (m['colour'] ?? '').toString().toLowerCase();
            return a.contains(s) || b.contains(s);
          }).toList();
        }

        if (docs.isEmpty) {
          return const Center(child: Text('No products found'));
        }

        if (grid) {
          // Adaptive grid: tiles resize up to this width → no overflow
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            gridDelegate:
            const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360, // ~2 cols on phones, 3–4 on tablets
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82, // tile height breathing room
            ),
            itemCount: docs.length,
            itemBuilder: (_, i) => _ProductCard(
              doc: docs[i],
              onEdit: _showEditDialog,
              onDuplicate: (p) => _prefillForm(p),
              onArchiveToggle: _toggleArchive,
              onDelete: _confirmDelete,
            ),
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            itemCount: docs.length,
            itemBuilder: (_, i) => _ProductRow(
              doc: docs[i],
              onEdit: _showEditDialog,
              onDuplicate: (p) => _prefillForm(p),
              onArchiveToggle: _toggleArchive,
              onDelete: _confirmDelete,
            ),
          );
        }
      },
    );
  }

  Future<void> _toggleArchive(
      DocumentSnapshot<Map<String, dynamic>> d) async {
    final v = (d.data()?['archived'] as bool?) ?? false;
    await d.reference.update({'archived': !v});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(v ? 'Restored' : 'Archived')),
    );
  }

  Future<void> _confirmDelete(
      DocumentSnapshot<Map<String, dynamic>> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
            'Are you sure you want to delete this product?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    ) ??
        false;
    if (ok) {
      await d.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🗑️ Product deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              // No snapshot of doc content to restore in this view.
              // (To fully undo, keep a temp copy before delete.)
            },
          ),
        ),
      );
    }
  }
}

/* ========================= Header stats (wraps; never overflows) ========================= */

class _HeaderStats extends StatelessWidget {
  final bool hideArchived;
  const _HeaderStats({required this.hideArchived});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q =
    FirebaseFirestore.instance.collection('products');
    if (hideArchived) q = q.where('archived', isEqualTo: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (_, s) {
        final docs = s.data?.docs ?? [];
        final total = docs.length;
        final males = docs
            .where((d) => (d.data()['gender'] ?? '') == 'Male')
            .length;
        final females = docs
            .where((d) => (d.data()['gender'] ?? '') == 'Female')
            .length;
        final prices = docs
            .map((d) =>
        (d.data()['unit_price'] as num?)?.toDouble() ?? 0)
            .toList();
        final avg =
        prices.isEmpty ? 0 : prices.reduce((a, b) => a + b) / prices.length;

        Widget chip(String label, String value, IconData icon, Color color) {
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12.withOpacity(.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: color.withOpacity(.12),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _darkBlue)),
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('Total', '$total', Icons.inventory_2_rounded, _darkBlue),
            chip('Male', '$males', Icons.male_rounded, Colors.teal),
            chip('Female', '$females', Icons.female_rounded, Colors.pink),
            chip('Avg price', _money(avg.round()),
                Icons.payments_rounded, _ink),
          ],
        );
      },
    );
  }
}

/* ========================= Card / Row ========================= */

class _ProductCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(
      DocumentSnapshot<Map<String, dynamic>>)
  onEdit;
  final void Function(Map<String, dynamic>) onDuplicate;
  final Future<void> Function(
      DocumentSnapshot<Map<String, dynamic>>)
  onArchiveToggle;
  final Future<void> Function(
      DocumentSnapshot<Map<String, dynamic>>)
  onDelete;

  const _ProductCard({
    required this.doc,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = doc.data();
    final price = (p['unit_price'] as num?)?.toDouble() ?? 0;
    final cost = (p['production_cost'] as num?)?.toDouble() ?? 0;
    final profit = price - cost;
    final profitPct = price > 0 ? (profit / price * 100) : 0;
    final archived = (p['archived'] as bool?) ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _viewDetails(context, p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
                child: p['imageUrl'] == null
                    ? Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                      child: Icon(Icons.image, color: _darkBlue)),
                )
                    : Image.network(p['imageUrl'], fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['model_name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _darkBlue),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: -4,
                            children: [
                              _chip(p['gender'] ?? '—'),
                              _chip('Color: ${p['colour'] ?? '—'}'),
                              if ((p['size'] ?? '').toString().isNotEmpty)
                                _chip('Size: ${p['size']}'),
                            ],
                          ),
                        ]),
                  ),
                  _MenuButton(
                    archived: archived,
                    onEdit: () => onEdit(doc),
                    onDuplicate: () => onDuplicate(p),
                    onArchiveToggle: () => onArchiveToggle(doc),
                    onDelete: () => onDelete(doc),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Text(_money(price),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: _darkBlue)),
                  const SizedBox(width: 10),
                  if (price > 0 && cost > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (profit >= 0 ? Colors.green : Colors.red)
                            .withOpacity(.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${profit >= 0 ? '+' : ''}${profitPct.toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: profit >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w800,
                            fontSize: 11),
                      ),
                    ),
                  const Spacer(),
                  Text(_fmtDate(p['createdAt'] as Timestamp?),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String t) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _darkBlue.withOpacity(.06),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      t,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: _darkBlue),
    ),
  );

  void _viewDetails(BuildContext context, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p['model_name'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _darkBlue)),
                const SizedBox(height: 10),
                if (p['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(p['imageUrl'],
                        height: 160, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 12),
                _kv('Gender', p['gender'] ?? '—'),
                _kv('Colour', p['colour'] ?? '—'),
                _kv('Size', p['size'] ?? '—'),
                _kv('Density', p['density'] ?? '—'),
                _kv('Curl', p['curl'] ?? '—'),
                _kv('Unit price', _money((p['unit_price'] ?? 0) as num)),
                _kv('Prod. cost', _money((p['production_cost'] ?? 0) as num)),
                _kv('Prod. time', p['production_time'] ?? '—'),
                _kv('Notes', p['notes'] ?? '—'),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
            width: 110,
            child: Text(k,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(v,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _darkBlue))),
      ],
    ),
  );
}

class _ProductRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(
      DocumentSnapshot<Map<String, dynamic>>)
  onEdit;
  final void Function(Map<String, dynamic>) onDuplicate;
  final Future<void> Function(
      DocumentSnapshot<Map<String, dynamic>>)
  onArchiveToggle;
  final Future<void> Function(
      DocumentSnapshot<Map<String, dynamic>>)
  onDelete;

  const _ProductRow({
    required this.doc,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = doc.data();
    final price = (p['unit_price'] as num?)?.toDouble() ?? 0;
    final archived = (p['archived'] as bool?) ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () => _ProductCard(
          doc: doc,
          onEdit: onEdit,
          onDuplicate: onDuplicate,
          onArchiveToggle: onArchiveToggle,
          onDelete: onDelete,
        )._viewDetails(context, p),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: p['imageUrl'] == null
              ? Container(
            width: 56,
            height: 56,
            color: Colors.grey.shade100,
            child: const Icon(Icons.image, color: _darkBlue),
          )
              : Image.network(p['imageUrl'],
              width: 56, height: 56, fit: BoxFit.cover),
        ),
        title: Text(p['model_name'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
            const TextStyle(fontWeight: FontWeight.w800, color: _darkBlue)),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: -4,
          children: [
            _miniChip(p['gender'] ?? '—'),
            _miniChip('Color: ${p['colour'] ?? '—'}'),
            Text(
              DateFormat('dd MMM').format(
                (p['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              ),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_money(price),
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: _darkBlue)),
            const SizedBox(width: 6),
            _MenuButton(
              archived: archived,
              onEdit: () => onEdit(doc),
              onDuplicate: () => onDuplicate(p),
              onArchiveToggle: () => onArchiveToggle(doc),
              onDelete: () => onDelete(doc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String t) => Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: _darkBlue.withOpacity(.06),
          borderRadius: BorderRadius.circular(999)),
      child: Text(t,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: _darkBlue)));
}

/* ========================= Menus ========================= */

class _MenuButton extends StatelessWidget {
  final bool archived;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onArchiveToggle;
  final VoidCallback onDelete;

  const _MenuButton({
    required this.archived,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (v) {
        switch (v) {
          case 'edit':
            onEdit();
            break;
          case 'duplicate':
            onDuplicate();
            break;
          case 'archive':
            onArchiveToggle();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'edit',
            child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
        const PopupMenuItem(
            value: 'duplicate',
            child: ListTile(
                leading: Icon(Icons.copy_rounded),
                title: Text('Duplicate to form'))),
        PopupMenuItem(
          value: 'archive',
          child: ListTile(
            leading: Icon(
                archived ? Icons.unarchive_rounded : Icons.archive_rounded),
            title: Text(archived ? 'Restore' : 'Archive'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.redAccent),
            title:
            Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.more_horiz_rounded, color: _darkBlue),
      ),
    );
  }
}
