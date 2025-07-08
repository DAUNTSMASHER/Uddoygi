// lib/features/marketing/presentation/screens/products_page.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class ProductsPage extends StatefulWidget {
  final String userEmail;
  const ProductsPage({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
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

  int _currentTab = 0;

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

  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) setState(() => _pickedImage = File(xfile.path));
  }

  Future<String> _uploadImage(File image) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('product_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> _addOrUpdateProduct() async {
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
      if (imageUrl != null) 'imageUrl': imageUrl,
    };

    await FirebaseFirestore.instance.collection('products').add(data);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Product added')));

    _formKey.currentState!.reset();
    setState(() {
      _gender = null;
      _pickedImage = null;
    });
  }

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
          title: const Text('Edit Product'),
          content: SingleChildScrollView(
            child: Form(
              key: _editFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: _decoration.copyWith(hintText: 'Gender'),
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
                    decoration: _decoration.copyWith(hintText: 'Model Name'),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _size,
                    decoration: _decoration.copyWith(hintText: 'Size'),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _density,
                    decoration: _decoration.copyWith(hintText: 'Density'),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _curl,
                    decoration: _decoration.copyWith(hintText: 'Curl'),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _colour,
                    decoration: _decoration.copyWith(hintText: 'Colour'),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _price,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: _decoration.copyWith(hintText: 'Unit Price'),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notes,
                    decoration: _decoration.copyWith(hintText: 'Notes'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _time,
                    decoration:
                    _decoration.copyWith(hintText: 'Production Time'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cost,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                    _decoration.copyWith(hintText: 'Production Cost'),
                  ),
                  const SizedBox(height: 12),
                  _pickedImage == null
                      ? OutlinedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Change Image'),
                    onPressed: _pickImage,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _darkBlue),
                    ),
                  )
                      : Image.file(_pickedImage!, height: 80, fit: BoxFit.cover),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
              onPressed: () async {
                if (!_editFormKey.currentState!.validate()) return;
                String? imageUrl;
                if (_pickedImage != null)
                  imageUrl = await _uploadImage(_pickedImage!);
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
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product updated')));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _field(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: child,
  );

  InputDecoration get _decoration => InputDecoration(
    filled: true,
    fillColor: Colors.grey.shade100,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: InputBorder.none,
  );

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.of(context).size.width - 48) / 2;

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
            tabs: const [
              Tab(text: 'Add Product'),
              Tab(text: 'All Products'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (ctx, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    child: ListTile(
                      leading:
                      const Icon(Icons.inventory, color: _darkBlue),
                      title: const Text('Total Products',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text('$count',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentTab == 0
                // Add Product Form
                    ? SingleChildScrollView(
                  key: const ValueKey(0),
                  padding:
                  const EdgeInsets.symmetric(vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      runSpacing: 0,
                      children: [
                        _field(DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: _decoration.copyWith(
                              hintText: 'Gender'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Male', child: Text('Male')),
                            DropdownMenuItem(
                                value: 'Female', child: Text('Female')),
                          ],
                          onChanged: (v) =>
                              setState(() => _gender = v),
                          validator: (v) =>
                          v == null ? 'Required' : null,
                        )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.image),
                            label: Text(_pickedImage == null
                                ? 'Pick Image'
                                : 'Change Image'),
                            onPressed: _pickImage,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: _darkBlue),
                            ),
                          ),
                        )),
                        if (_pickedImage != null)
                          _field(SizedBox(
                            width: cardWidth,
                            height: 80,
                            child: Image.file(_pickedImage!,
                                fit: BoxFit.cover),
                          )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: TextFormField(
                            controller: _model,
                            decoration: _decoration.copyWith(
                                hintText: 'Model Name'),
                            validator: (v) => v!.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: TextFormField(
                            controller: _size,
                            decoration: _decoration.copyWith(
                                hintText: 'Size'),
                            validator: (v) => v!.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: TextFormField(
                            controller: _density,
                            decoration: _decoration.copyWith(
                                hintText: 'Density'),
                            validator: (v) => v!.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: TextFormField(
                            controller: _curl,
                            decoration: _decoration.copyWith(
                                hintText: 'Curl'),
                            validator: (v) => v!.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: TextFormField(
                            controller: _colour,
                            decoration: _decoration.copyWith(
                                hintText: 'Colour'),
                            validator: (v) => v!.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: TextFormField(
                            controller: _price,
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                            decoration: _decoration.copyWith(
                                hintText: 'Unit Price'),
                            validator: (v) => v!.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: TextFormField(
                            controller: _notes,
                            decoration: _decoration.copyWith(
                                hintText: 'Notes'),
                          ),
                        )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: TextFormField(
                            controller: _time,
                            decoration: _decoration.copyWith(
                                hintText: 'Production Time'),
                            validator: (v) => v!.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        )),
                        _field(SizedBox(
                          width: cardWidth,
                          child: TextFormField(
                            controller: _cost,
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                            decoration: _decoration.copyWith(
                                hintText: 'Production Cost'),
                            validator: (v) => v!.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        )),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _darkBlue,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14)),
                              onPressed: _addOrUpdateProduct,
                              child: const Text('Submit'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                // All Products List
                    : _buildProductList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No products found'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final p = doc.data();
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['model_name'] ?? '',
                                  style: const TextStyle(
                                      color: _darkBlue,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text('Colour: ${p['colour'] ?? ''}'),
                              ],
                            ),
                          ),
                          if (p['imageUrl'] != null)
                            Image.network(
                              p['imageUrl'],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showEditDialog(doc),
                            icon: const Icon(Icons.edit,
                                color: _darkBlue),
                            label: const Text('Edit',
                                style: TextStyle(color: _darkBlue)),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _confirmDelete(doc.id),
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            label: const Text('Delete',
                                style: TextStyle(
                                    color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content:
        const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    if (ok) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted')));
    }
  }
}
