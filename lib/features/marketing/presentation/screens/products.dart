// lib/features/marketing/presentation/screens/products_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  int _currentTab = 0; // 0 = Add Product, 1 = All Products
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
                await FirebaseFirestore.instance
                    .collection('products')
                    .doc(doc.id)
                    .update(data);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Product updated')));
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

    final ref = FirebaseFirestore.instance.collection('stocks').doc(docId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
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
      final products = FirebaseFirestore.instance.collection('products');
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
      final stocks = FirebaseFirestore.instance.collection('stocks');
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
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 480;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _darkBlue,
        title: const Text('Products', style: TextStyle(color: Colors.white)),
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
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        selectedItemColor: _darkBlue,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box),
            label: 'Add Product',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'All Products',
          ),
        ],
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
              child: _toolbar(), // search + filters visible only on All
            ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _currentTab == 0
                  ? (isMobile ? _addFormMobile() : _addFormDesktop())
                  : _productsGrid(),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
                  DropdownMenuItem(value: _Sort.newest, child: Text('Newest')),
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

  // ——— All Products: GRID ONLY (adaptive; 1-per-row when needed; no overflow) ———
  Widget _productsGrid() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: const ValueKey('grid'),
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
            final a = (m['model_name'] ?? '').toString().toLowerCase();
            final b = (m['colour'] ?? '').toString().toLowerCase();
            return a.contains(s) || b.contains(s);
          }).toList();
        }

        if (docs.isEmpty) {
          return const Center(child: Text('No products found'));
        }

        final w = MediaQuery.of(ctx).size.width;
        // 1 col for very small screens, then 2/3/4 as width grows
        final crossAxisCount = w < 420 ? 1 : w < 720 ? 2 : w < 1024 ? 3 : 4;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
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
        content:
        const Text('Are you sure you want to delete this product?'),
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
              // To fully support undo, keep a temp snapshot before delete.
            },
          ),
        ),
      );
    }
  }
}

/* ========================= Header stats (responsive GRID — min 2 cols) ========================= */

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

class _ProductRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>>) onEdit;
  final void Function(Map<String, dynamic>) onDuplicate;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>>)
  onArchiveToggle;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>>) onDelete;

  const _ProductRow({
    required this.doc,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Kept for completeness; not used since dashboard is grid-only
    final p = doc.data();
    final price = (p['unit_price'] as num?)?.toDouble() ?? 0;
    final archived = (p['archived'] as bool?) ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () => _showProductDetails(context, p),
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
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: _darkBlue)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  stream: FirebaseFirestore.instance
                      .collection('stocks')
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
                            final doc = await FirebaseFirestore.instance
                                .collection('stocks')
                                .doc(createdId)
                                .get();
                            _selectedData = doc.data();
                          }
                        } else if (v != null) {
                          setState(() => _selectedStockId = v);
                          final doc = await FirebaseFirestore.instance
                              .collection('stocks')
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
