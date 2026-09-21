import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddOrEditProductDialog({Product? product}) {
    if (product != null) {
      _barcodeController.text = product.barcode;
      _nameController.text = product.name;
      _costPriceController.text = product.costPrice.toString();
      _sellPriceController.text = product.sellPrice.toString();
      _stockController.text = product.stockQuantity.toString();
    } else {
      _barcodeController.clear();
      _nameController.clear();
      _costPriceController.clear();
      _sellPriceController.clear();
      _stockController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? 'إضافة منتج جديد' : 'تعديل المنتج'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(labelText: 'الباركود (اختياري)'),
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: _costPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'سعر الشراء (التكلفة)'),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'أدخل رقم صحيح' : null,
                ),
                TextFormField(
                  controller: _sellPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'سعر البيع'),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'أدخل رقم صحيح' : null,
                ),
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية المتوفرة'),
                  validator: (v) => int.tryParse(v ?? '') == null ? 'أدخل رقم صحيح' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final provider = Provider.of<ProductProvider>(context, listen: false);

                if (product == null) {
                  final newProduct = Product(
                    barcode: _barcodeController.text.trim().isEmpty
                        ? DateTime.now().millisecondsSinceEpoch.toString()
                        : _barcodeController.text.trim(),
                    name: _nameController.text.trim(),
                    costPrice: double.parse(_costPriceController.text),
                    sellPrice: double.parse(_sellPriceController.text),
                    stockQuantity: int.parse(_stockController.text),
                  );

                  String result = provider.addProductWithRules(newProduct);

                  Navigator.pop(context);

                  if (result == 'rejected_barcode_conflict') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('خطأ: هذا الباركود مسجل مسبقاً لصنف آخر! تمت ازالة عملية الإضافة.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if (result == 'updated_existing') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('الصنف موجود مسبقاً، تمت إضافة الكمية الجديدة إلى المخزون بنجاح.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة المنتج الجديد بنجاح.'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                } else {
                  product.barcode = _barcodeController.text.trim();
                  product.name = _nameController.text.trim();
                  product.costPrice = double.parse(_costPriceController.text);
                  product.sellPrice = double.parse(_sellPriceController.text);
                  product.stockQuantity = int.parse(_stockController.text);
                  provider.updateProduct(product);
                  Navigator.pop(context);
                }
              }
            },
            child: Text(product == null ? 'إضافة' : 'حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final filteredProducts = productProvider.products.where((p) {
      final query = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(query) || p.barcode.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأصناف والمنتجات'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إضافة منتج'),
              onPressed: () => _showAddOrEditProductDialog(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'بحث باسم المنتج أو الباركود',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('الباركود')),
                      DataColumn(label: Text('اسم المنتج')),
                      DataColumn(label: Text('سعر التكلفة')),
                      DataColumn(label: Text('سعر البيع')),
                      DataColumn(label: Text('المخزون')),
                      DataColumn(label: Text('الإجراءات')),
                    ],
                    rows: filteredProducts.map((p) {
                      return DataRow(cells: [
                        DataCell(Text(p.barcode.isEmpty ? 'بدون باركود' : p.barcode)),
                        DataCell(Text(p.name)),
                        DataCell(Text('${p.costPrice.toStringAsFixed(2)} شيكل')),
                        DataCell(Text('${p.sellPrice.toStringAsFixed(2)} شيكل')),
                        DataCell(
                          Text(
                            '${p.stockQuantity}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: p.stockQuantity <= 5 ? Colors.red : Colors.black,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showAddOrEditProductDialog(product: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => productProvider.deleteProduct(p),
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}