// lib/features/marketing/presentation/screens/products_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/drive_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/features/marketing/presentation/screens/new_invoices_screen.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const Color _ink = Color(0xFF1D5DF1);
const Color _okGreen = Color(0xFF10B981);
const Color _lowRed = Color(0xFFE11D48);

enum _Sort { newest, priceLowHigh, priceHighLow }

// ——— helpers (top-level so every widget can use them) ———
String _fmtDate(Timestamp? ts) =>
    ts == null ? '—' : DateFormat('dd MMM, yyyy').format(ts.toDate());
String _money(num n) => '৳${NumberFormat.decimalPattern().format(n)}';

// Soft color dots shown in the “active” card state
List<Color> _paletteFromColourField(String? colourText) {
  final t = (colourText ?? '').toLowerCase();
  Color base;
  if (t.contains('black')) base = Colors.black87;
  else if (t.contains('brown')) base = Colors.brown;
  else if (t.contains('blonde') || t.contains('gold')) {
    base = const Color(0xFFD4AF37);
  } else if (t.contains('dark')) {
    base = const Color(0xFF222222);
  } else if (t.contains('red')) {
    base = Colors.redAccent;
  } else if (t.contains('blue')) {
    base = Colors.blueAccent;
  } else if (t.contains('ash')) {
    base = const Color(0xFFF3F3F3);
  } else {
    base = _darkBlue;
  }
  return [
    base.withOpacity(.9),
    Colors.tealAccent.shade700,
    Colors.cyan.shade400,
    Colors.pinkAccent.shade100,
  ];
}

class ProductsPage extends StatefulWidget {
  final String userEmail;
  const ProductsPage({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String _cid = '';
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
  int _currentTab = 1; // 0 = Add Product, 1 = All Products
  String _search = '';
  String _genderFilter = 'All'; // All / Male / Female
  _Sort _sort = _Sort.newest;
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
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _darkBlue, width: 1.2),
    ),
  );

  // ——— image helpers ———
  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 80);
      if (x != null) setState(() => _pickedImage = File(x.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<String> _uploadImage(File image) async {
    try {
      final result = await DriveStorageService.instance.uploadFile(
        image,
        pathPrefix: 'product_images',
        customName: '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      return result.viewUrl;
    } catch (e) {
      rethrow;
    }
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
    try {
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

      await DB.colSync(_cid, C.products).add(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Product added')),
      );
      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product: $e')));
      }
    }
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
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _size,
                          decoration: _decoration.copyWith(labelText: 'Size'),
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
                          decoration: _decoration.copyWith(labelText: 'Curl'),
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
                          decoration:
                          _decoration.copyWith(labelText: 'Unit Price'),
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
              style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
              onPressed: () async {
                if (!_editFormKey.currentState!.validate()) return;
                try {
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
                    'production_cost': double.tryParse(_cost.text) ?? 0,
                    if (imageUrl != null) 'imageUrl': imageUrl,
                  };
                  await DB.colSync(_cid, C.products)
                      .doc(doc.id)
                      .update(data);
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Product updated')));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update product: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ======= Stock movement helpers (for the bottom sheet) =======

  Future<void> _openMovement(BuildContext context, {required bool isIn}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _StockMovementSheet(
          isIn: isIn,
          onSubmit: (docId, data, amount, note) async {
            final delta = isIn ? amount : -amount;
            await _applyStockMovement(docId, data, delta, note);
          },
          onAddNew: _createProductAndStock, // returns new stock docId
        ),
      ),
    );
  }

  /// Update stock qty and write a daily log: stocks/{id}/logs/{yyyy-MM-dd}
  Future<void> _applyStockMovement(
      String docId,
      Map<String, dynamic> existing,
      int delta,
      String note,
      ) async {
    final prevQty = (existing['qty'] as int?) ?? 0;
    final newQty = prevQty + delta;

    final ref = DB.colSync(_cid, C.stocks).doc(docId);
    await DB.firestore.runTransaction((tx) async {
      tx.update(ref, {
        'qty': newQty,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      final today = DateTime.now();
      final yyyyMmDd =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      tx.set(ref.collection('logs').doc(yyyyMmDd), {
        'date': yyyyMmDd,
        'delta': delta,
        'newQty': newQty,
        'note': note,
        'ts': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stock ${delta >= 0 ? 'in' : 'out'} saved')),
    );
  }

  /// Creates BOTH: a product in `products` and a stock doc in `stocks`.
  /// Returns the created stock document ID.
  Future<String?> _createProductAndStock({
    required String name,
    required String sku,
    required String unit,
    double? unitPrice,
  }) async {
    try {
      // 1) create product (minimal fields)
      final products = DB.colSync(_cid, C.products);
      await products.add({
        'model_name': name,
        'unit_price': unitPrice ?? 0.0,
        'gender': null,
        'size': '',
        'density': '',
        'curl': '',
        'colour': '',
        'notes': '',
        'production_time': '',
        'production_cost': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.userEmail,
        'archived': false,
      });

      // 2) create stock
      final stocks = DB.colSync(_cid, C.stocks);
      final ref = await stocks.add({
        'name': name,
        'sku': sku,
        'unit': unit,
        'qty': 0,
        'minThreshold': 100,
        'maxThreshold': 500,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return ref.id;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add product: $e')),
      );
      return null;
    }
  }

  // ——— Build ———
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 480;

    if (_currentTab == 0) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          title: Text('Add Product', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentTab = 1)),
        ),
        backgroundColor: const Color(0xFFF7F9FC),
        body: isMobile ? _addFormMobile() : _addFormDesktop(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: Text('Product Catalog', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Stock In',
            onPressed: () => _openMovement(context, isIn: true),
            icon: const Icon(Icons.call_received_rounded),
          ),
          IconButton(
            tooltip: 'Stock Out',
            onPressed: () => _openMovement(context, isIn: false),
            icon: const Icon(Icons.call_made_rounded),
          ),
          IconButton(
            tooltip: 'Add Product',
            onPressed: () => setState(() => _currentTab = 0),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _productsGrid()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _search = val),
            decoration: InputDecoration(
              hintText: 'Search by model name or category...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.search, color: const Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                    DropdownMenuItem(value: _Sort.newest, child: Text('Newest')),
                    DropdownMenuItem(value: _Sort.priceLowHigh, child: Text('Price ↑')),
                    DropdownMenuItem(value: _Sort.priceHighLow, child: Text('Price ↓')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ——— Add form: Desktop/Tablet (two-column wrap) ———
  Widget _addFormDesktop() {
    final colW = (MediaQuery.of(context).size.width - 48) / 2;

    return SingleChildScrollView(
      key: const ValueKey('form-desktop'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      child: Form(
        key: _formKey,
        child: Wrap(
          runSpacing: 12,
          spacing: 12,
          children: [
            SizedBox(width: colW, child: _imagesCard()),
            SizedBox(width: colW, child: _productInfoCard()),
            SizedBox(width: colW, child: _pricingCard()),
            SizedBox(width: colW, child: _variantsCard()),
            SizedBox(width: double.infinity, child: _submitRow()),
          ],
        ),
      ),
    );
  }

  // ——— Add form: Mobile (sectioned cards; 1 per row) ———
  Widget _addFormMobile() {
    return SingleChildScrollView(
      key: const ValueKey('form-mobile'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _imagesCard(),
            const SizedBox(height: 12),
            _productInfoCard(),
            const SizedBox(height: 12),
            _variantsCard(),
            const SizedBox(height: 12),
            _pricingCard(),
            const SizedBox(height: 12),
            _notesCard(),
            const SizedBox(height: 12),
            _submitRow(),
          ],
        ),
      ),
    );
  }

  // ——— section cards used by both layouts ———
  Widget _card({required String title, required Widget child, IconData? icon}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null)
                Icon(icon, size: 16, color: Colors.grey.shade600),
              if (icon != null) const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700)),
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _imagesCard() {
    return _card(
      title: 'Product Images',
      icon: Icons.photo_camera_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _pickImage(source: ImageSource.gallery),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.grey.shade400.withOpacity(.6),
                    width: 2,
                    style: BorderStyle.solid),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, size: 20, color: _darkBlue),
                    SizedBox(width: 6),
                    Text('Add image',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: _darkBlue)),
                  ],
                ),
              ),
            ),
          ),
          if (_pickedImage != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(_pickedImage!, height: 120, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 6),
          Text('Add up to 5 images. First image will be the main photo.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _productInfoCard() {
    return _card(
      title: 'Product Information',
      icon: Icons.inventory_2_outlined,
      child: Column(
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
          const SizedBox(height: 10),
          TextFormField(
            controller: _model,
            decoration: _decoration.copyWith(labelText: 'Model Name *'),
            validator: (v) => v!.trim().isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _variantsCard() {
    return _card(
      title: 'Variants',
      icon: Icons.tune_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _size,
                  decoration: _decoration.copyWith(labelText: 'Size'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _density,
                  decoration: _decoration.copyWith(labelText: 'Density'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _curl,
                  decoration: _decoration.copyWith(labelText: 'Curl'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _colour,
                  decoration: _decoration.copyWith(labelText: 'Colour'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pricingCard() {
    return _card(
      title: 'Pricing',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: _decoration.copyWith(labelText: 'Unit Price *'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _cost,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                  _decoration.copyWith(labelText: 'Production Cost'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _time,
            decoration: _decoration.copyWith(labelText: 'Production Time'),
          ),
        ],
      ),
    );
  }

  Widget _notesCard() {
    return _card(
      title: 'Notes',
      icon: Icons.notes_rounded,
      child: TextFormField(
        controller: _notes,
        maxLines: 3,
        decoration: _decoration.copyWith(labelText: 'Notes'),
      ),
    );
  }

  Widget _submitRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _addProduct,
            child: const Text('Submit'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _resetForm,
          child: const Text('Reset'),
        ),
      ],
    );
  }

  // ——— All Products: GRID ONLY (adaptive; 1-per-row when needed; no overflow) ———
  Widget _productsGrid() {
    if (_cid.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: const ValueKey('grid'),
      stream: DB.colSync(_cid, C.products).snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error loading products: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data!.docs;

        // Apply filters in-memory
        if (_hideArchived) {
          docs = docs.where((d) => (d.data()['archived'] ?? false) == false).toList();
        }
        if (_genderFilter != 'All') {
          docs = docs.where((d) => (d.data()['gender'] ?? '') == _genderFilter).toList();
        }
        if (_search.trim().isNotEmpty) {
          final s = _search.toLowerCase();
          docs = docs.where((d) {
            final m = d.data();
            final a = (m['model_name'] ?? '').toString().toLowerCase();
            final b = (m['colour'] ?? '').toString().toLowerCase();
            return a.contains(s) || b.contains(s);
          }).toList();
        }

        // Apply sorting in-memory
        docs.sort((a, b) {
          final ma = a.data();
          final mb = b.data();
          
          if (_sort == _Sort.priceLowHigh || _sort == _Sort.priceHighLow) {
            final pa = (ma['unit_price'] as num?)?.toDouble() ?? 0.0;
            final pb = (mb['unit_price'] as num?)?.toDouble() ?? 0.0;
            final comp = pa.compareTo(pb);
            return _sort == _Sort.priceLowHigh ? comp : -comp;
          } else {
            // Sort by newest (createdAt)
            final ta = ma['createdAt'] as Timestamp?;
            final tb = mb['createdAt'] as Timestamp?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta); // descending
          }
        });

        if (docs.isEmpty) {
          return const Center(child: Text('No products found'));
        }

        final w = MediaQuery.of(ctx).size.width;
        final crossAxisCount = w < 420 ? 1 : w < 720 ? 2 : w < 1024 ? 3 : 4;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.65,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) => _ModernProductCard(
            doc: docs[i],
            cid: _cid,
            onEdit: () => _showEditDialog(docs[i]),
            onDetails: () => _showProductDetails(context, docs[i].data()),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, DocumentSnapshot<Map<String, dynamic>> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete')),
        ],
      ),
    ) ?? false;
    if (ok) {
      await d.reference.delete();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🗑️ Product deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              // To fully support undo, keep a temp snapshot before delete.
            },
          ),
        ),
      );
    }
    return ok;
  }
}

/* ========================= Header stats (responsive GRID — min 2 cols) ========================= */

class _HeaderStats extends StatefulWidget {

  final bool hideArchived;
  const _HeaderStats({required this.hideArchived});
  @override
  State<_HeaderStats> createState() => _HeaderStatsState();
}

class _HeaderStatsState extends State<_HeaderStats> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    Query<Map<String, dynamic>> q =
    DB.colSync(_cid, C.products);
    if (widget.hideArchived) q = q.where('archived', isEqualTo: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (_, s) {
        final docs = s.data?.docs ?? [];

        final total = docs.length;
        final males =
            docs.where((d) => (d.data()['gender'] ?? '') == 'Male').length;
        final females =
            docs.where((d) => (d.data()['gender'] ?? '') == 'Female').length;
        final prices = docs
            .map((d) => (d.data()['unit_price'] as num?)?.toDouble() ?? 0)
            .toList();
        final avg =
        prices.isEmpty ? 0 : prices.reduce((a, b) => a + b) / prices.length;

        final items = <_StatItem>[
          _StatItem('Total', '$total', Icons.inventory_2_rounded, _darkBlue),
          _StatItem('Male', '$males', Icons.male_rounded, Colors.teal),
          _StatItem('Female', '$females', Icons.female_rounded, Colors.pink),
          _StatItem(
              'Avg price', _money(avg.round()), Icons.payments_rounded, _ink),
        ];

        // Always ≥2 columns for a true grid look
        final w = MediaQuery.of(context).size.width;
        final cols = (w / 220).floor().clamp(2, 4);

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3.6,
          ),
          itemBuilder: (_, i) => _StatCard(item: items[i]),
        );
      },
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.color.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: _darkBlue)),
                Text(item.label,
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
    );
  }
}

/* ========================= Card / Row ========================= */

class _ProductCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>>) onEdit;
  final void Function(Map<String, dynamic>) onDuplicate;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>>)
  onArchiveToggle;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>>) onDelete;

  const _ProductCard({
    required this.doc,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _active = false;

  void _toggleActive() => setState(() => _active = !_active);

  @override
  Widget build(BuildContext context) {
    final p = widget.doc.data();
    final price = (p['unit_price'] as num?)?.toDouble() ?? 0;
    final cost = (p['production_cost'] as num?)?.toDouble() ?? 0;
    final profit = price - cost;
    final profitPct = price > 0 ? (profit / price * 100) : 0;
    final archived = (p['archived'] as bool?) ?? false;

    final dots = _paletteFromColourField(p['colour']);

    return AnimatedScale(
      scale: _active ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _active
                  ? _darkBlue.withOpacity(.18)
                  : Colors.black12.withOpacity(.06)),
          boxShadow: [
            BoxShadow(
              color: _active ? const Color(0x22000000) : const Color(0x0F000000),
              blurRadius: _active ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _toggleActive, // first tap: show active state
            onLongPress: () {
              _showProductDetails(context, p);
            },
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
                        child: p['imageUrl'] == null
                            ? Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                              child: Icon(Icons.image,
                                  color: _darkBlue)),
                        )
                            : Image.network(p['imageUrl'], fit: BoxFit.cover),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
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
                                      if ((p['size'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        _chip('Size: ${p['size']}'),
                                    ],
                                  ),
                                ]),
                          ),
                          _MenuButton(
                            archived: archived,
                            onEdit: () => widget.onEdit(widget.doc),
                            onDuplicate: () => widget.onDuplicate(p),
                            onArchiveToggle: () =>
                                widget.onArchiveToggle(widget.doc),
                            onDelete: () => widget.onDelete(widget.doc),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Row(
                        children: [
                          Text(_money(price),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: _darkBlue)),
                          const SizedBox(width: 10),
                          if (price > 0 && cost > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (profit >= 0
                                    ? Colors.green
                                    : Colors.red)
                                    .withOpacity(.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${profit >= 0 ? '+' : ''}${profitPct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    color: profit >= 0
                                        ? Colors.green
                                        : Colors.red,
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

                // Plus circle — bottom-right
                Positioned(
                  right: 14,
                  bottom: 18,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 8,
                            offset: Offset(0, 4))
                      ],
                      border: Border.all(
                          color: Colors.black12.withOpacity(.06)),
                    ),
                    child: const Icon(Icons.add, color: Colors.black87),
                  ),
                ),

                // Active overlay: color dots + add-to-cart pill
                Positioned(
                  left: 16,
                  bottom: 18,
                  child: AnimatedOpacity(
                    opacity: _active ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Row(
                      children: [
                        Row(
                          children: dots
                              .map((c) => Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                          ))
                              .toList(),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Added "${p['model_name'] ?? 'Item'}"')),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add to Cart'),
                        ),
                      ],
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

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
}

// Quick details sheet
void _showProductDetails(BuildContext context, Map<String, dynamic> p) {
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
            child:
            ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
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

/* ========================= Stock Movement Bottom Sheet ========================= */

class _StockMovementSheet extends StatefulWidget {
  final bool isIn;
  final Future<void> Function(
      String docId, Map<String, dynamic> data, int amount, String note)
  onSubmit;
  final Future<String?> Function(
      {required String name,
      required String sku,
      required String unit,
      double? unitPrice})
  onAddNew;

  const _StockMovementSheet({
    Key? key,
    required this.isIn,
    required this.onSubmit,
    required this.onAddNew,
  }) : super(key: key);

  @override
  State<_StockMovementSheet> createState() => _StockMovementSheetState();
}

class _StockMovementSheetState extends State<_StockMovementSheet> {
  String _cid = '';
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }
  final _formKey = GlobalKey<FormState>();
  String? _selectedStockId;
  Map<String, dynamic>? _selectedData;
  final _amountCtl = TextEditingController(text: '1');
  final _noteCtl = TextEditingController();

  static const _kAddNewSentinel = '__ADD_NEW__';

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isIn ? 'Stock In' : 'Stock Out';
    final accent = widget.isIn ? _okGreen : _lowRed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // grab handle
          Container(
            width: 42,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              Icon(widget.isIn ? Icons.call_received_rounded : Icons.call_made_rounded,
                  color: accent),
            ],
          ),
          const SizedBox(height: 12),

          Form(
            key: _formKey,
            child: Column(
              children: [
                // Products dropdown (from stocks) + "Add new…"
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: DB.colSync(_cid, C.stocks)
                      .orderBy('name')
                      .snapshots(),
                  builder: (ctx, snap) {
                    final docs = snap.data?.docs ?? [];
                    final items = <DropdownMenuItem<String>>[
                      const DropdownMenuItem(
                        value: _kAddNewSentinel,
                        child: Text('➕ Add new product…',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      ...docs.map((d) {
                        final m = d.data();
                        final name = (m['name'] as String?) ?? 'Unnamed';
                        final sku = (m['sku'] as String?) ?? '';
                        return DropdownMenuItem<String>(
                          value: d.id,
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(name,
                                      overflow: TextOverflow.ellipsis)),
                              if (sku.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text('($sku)',
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                ),
                            ],
                          ),
                        );
                      }),
                    ];

                    return DropdownButtonFormField<String>(
                      value: _selectedStockId,
                      items: items,
                      decoration: const InputDecoration(
                        labelText: 'Select product',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Select or add a product'
                          : null,
                      onChanged: (v) async {
                        if (v == _kAddNewSentinel) {
                          final createdId =
                          await _showAddNewProductDialog(context);
                          if (createdId != null) {
                            setState(() => _selectedStockId = createdId);
                            final doc = await DB.colSync(_cid, C.stocks)
                                .doc(createdId)
                                .get();
                            _selectedData = doc.data();
                          }
                        } else if (v != null) {
                          setState(() => _selectedStockId = v);
                          final doc = await DB.colSync(_cid, C.stocks)
                              .doc(v)
                              .get();
                          _selectedData = doc.data();
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Amount + unit chip
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountCtl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                              widget.isIn ? Icons.add : Icons.remove,
                              color: accent),
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0) {
                            return 'Enter a positive number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_selectedData != null)
                      _unitPill((_selectedData!['unit'] as String?) ?? 'pcs'),
                  ],
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _noteCtl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.save_rounded),
                    label: Text(widget.isIn ? 'Save Stock In' : 'Save Stock Out'),
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      if (_selectedStockId == null || _selectedData == null) {
                        return;
                      }
                      final amount = int.parse(_amountCtl.text.trim());
                      final note = _noteCtl.text.trim().isEmpty
                          ? (widget.isIn
                          ? 'Quick Stock In'
                          : 'Quick Stock Out')
                          : _noteCtl.text.trim();

                      await widget.onSubmit(
                          _selectedStockId!, _selectedData!, amount, note);

                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitPill(String unit) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.05),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(unit, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  /// Small dialog used when "➕ Add new product…" is picked
  Future<String?> _showAddNewProductDialog(BuildContext context) async {
    final nameCtl = TextEditingController();
    final skuCtl = TextEditingController();
    String unit = 'pcs';
    final priceCtl = TextEditingController();

    String? createdId;

    await showDialog(
      context: context,
      builder: (_) {
        final localKey = GlobalKey<FormState>();
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New Product'),
          content: Form(
            key: localKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtl,
                  decoration: const InputDecoration(
                      labelText: 'Name *', border: OutlineInputBorder()),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: skuCtl,
                  decoration: const InputDecoration(
                      labelText: 'SKU / Code', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: unit,
                  items: const [
                    DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'm', child: Text('m')),
                    DropdownMenuItem(value: 'box', child: Text('box')),
                  ],
                  onChanged: (v) => unit = v ?? 'pcs',
                  decoration: const InputDecoration(
                      labelText: 'Unit', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: priceCtl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Unit Price (optional)',
                      border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!(localKey.currentState?.validate() ?? false)) return;
                final price = double.tryParse(priceCtl.text.trim());
                createdId = await widget.onAddNew(
                  name: nameCtl.text.trim(),
                  sku: skuCtl.text.trim(),
                  unit: unit,
                  unitPrice: price,
                );
                if (createdId != null && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    return createdId;
  }
}


class _ModernProductCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String cid;
  final VoidCallback onEdit;
  final VoidCallback onDetails;

  const _ModernProductCard({
    required this.doc,
    required this.cid,
    required this.onEdit,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final p = doc.data();
    final name = (p['model_name'] ?? 'Unnamed').toString();
    final gender = (p['gender'] ?? '—').toString();
    final colour = (p['colour'] ?? '—').toString();
    final size = (p['size'] ?? '').toString();
    final price = (p['unit_price'] as num?)?.toDouble() ?? 0.0;
    final imgUrl = p['imageUrl'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: imgUrl != null
                  ? Image.network(imgUrl, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFFE2E8F0),
                      child: const Center(child: Icon(Icons.image, size: 40, color: Color(0xFF94A3B8))),
                    ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _chip(gender),
                    const SizedBox(width: 4),
                    Expanded(child: _chip(colour)),
                    if (size.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      _chip(size),
                    ]
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('৳${price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF2563EB))),
                    _StockBadge(cid: cid, skuOrName: name),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 20, color: Color(0xFF64748B)),
                          onPressed: onDetails,
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)),
                          onPressed: onEdit,
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      icon: const Icon(Icons.receipt_long, size: 14),
                      label: Text('Invoice', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewInvoicesScreen(
                              initialProductModel: name,
                              initialProductColour: colour,
                              initialProductSize: size,
                              initialProductPrice: price,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final String cid;
  final String skuOrName;

  const _StockBadge({required this.cid, required this.skuOrName});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(cid, 'stocks').where('name', isEqualTo: skuOrName).limit(1).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _badge('Out of Stock', const Color(0xFFE11D48));
        }
        final qty = (snap.data!.docs.first.data() as Map<String, dynamic>)['qty'] as int? ?? 0;
        if (qty <= 0) return _badge('Out of Stock', const Color(0xFFE11D48));
        if (qty < 10) return _badge('Low Stock: $qty', Colors.orange.shade700);
        return _badge('In Stock: $qty', const Color(0xFF10B981));
      },
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
