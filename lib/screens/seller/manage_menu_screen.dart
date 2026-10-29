import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../services/database_service.dart';

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();
  final Set<String> _deletingItemIds = {};

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color accentOrange = Color(0xFFD87D4A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- HÀM XÁC NHẬN VÀ XÓA ĐỒ UỐNG ---
  Future<void> _confirmAndDeleteProduct(ProductModel product) async {
    if (_deletingItemIds.contains(product.id)) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Xác Nhận Xóa Món', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa đồ uống "${product.name}" khỏi thực đơn không?\n\nLưu ý: Thao tác này không thể hoàn tác và không làm ảnh hưởng đến các đơn hàng cũ đã đặt.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deletingItemIds.add(product.id);
    });

    try {
      await _dbService.deleteProduct(product.id);
      _showSnackBar('✅ Đã xóa đồ uống "${product.name}" khỏi thực đơn.');
    } catch (e) {
      _showSnackBar('❌ Lỗi khi xóa đồ uống: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingItemIds.remove(product.id);
        });
      }
    }
  }

  // --- HÀM XÁC NHẬN VÀ XÓA TOPPING ---
  Future<void> _confirmAndDeleteTopping(String docId, String toppingName) async {
    if (docId.isEmpty || _deletingItemIds.contains(docId)) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Xác Nhận Xóa Topping', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa topping "$toppingName" khỏi danh sách không?\n\nLưu ý: Thao tác này không thể hoàn tác.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deletingItemIds.add(docId);
    });

    try {
      await _dbService.deleteTopping(docId);
      _showSnackBar('✅ Đã xóa topping "$toppingName" thành công.');
    } catch (e) {
      _showSnackBar('❌ Lỗi khi xóa topping: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingItemIds.remove(docId);
        });
      }
    }
  }

  // --- HÀM MỞ DIALOG THÊM / SỬA ĐỒ UỐNG ---
  void _openProductDialog({ProductModel? product}) {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController =
        TextEditingController(text: product != null ? product.basePrice.toString() : '');
    final categoryController =
        TextEditingController(text: product?.category ?? 'Trà sữa');
    final imageController = TextEditingController(text: product?.imageUrl ?? '');
    final descController = TextEditingController(text: product?.description ?? '');
    bool isAvailable = product?.isAvailable ?? true;

    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isEditing ? 'Chỉnh Sửa Đồ Uống' : 'Thêm Đồ Uống Mới',
                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBrown),
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tên đồ uống
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tên đồ uống *',
                            prefixIcon: Icon(Icons.local_cafe, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập tên đồ uống';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Giá tiền
                        TextFormField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giá bán (VNĐ) *',
                            prefixIcon: Icon(Icons.attach_money, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập giá';
                            }
                            final p = int.tryParse(val.trim());
                            if (p == null || p < 0) {
                              return 'Giá tiền không hợp lệ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Danh mục
                        TextFormField(
                          controller: categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Danh mục *',
                            hintText: 'VD: Trà sữa, Trà trái cây...',
                            prefixIcon: Icon(Icons.category, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập danh mục';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Link hình ảnh
                        TextFormField(
                          controller: imageController,
                          decoration: const InputDecoration(
                            labelText: 'Link hình ảnh (URL)',
                            prefixIcon: Icon(Icons.image, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Mô tả
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả ngắn',
                            prefixIcon: Icon(Icons.description, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Trạng thái còn hàng
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Trạng thái còn hàng',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          value: isAvailable,
                          activeColor: primaryBrown,
                          onChanged: (val) {
                            setDialogState(() {
                              isAvailable = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final data = {
                            'name': nameController.text.trim(),
                            'basePrice': int.parse(priceController.text.trim()),
                            'category': categoryController.text.trim(),
                            'imageUrl': imageController.text.trim(),
                            'description': descController.text.trim(),
                            'isAvailable': isAvailable,
                          };

                          try {
                            if (isEditing) {
                              await _dbService.updateProduct(product.id, data);
                              _showSnackBar('✅ Đã cập nhật món "${data['name']}" thành công!');
                            } else {
                              data['createdAt'] = FieldValue.serverTimestamp();
                              await _dbService.addProduct(data);
                              _showSnackBar('✅ Đã thêm món mới "${data['name']}" thành công!');
                            }
                            if (mounted && ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            _showSnackBar('❌ Lỗi khi lưu dữ liệu: $e', isError: true);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEditing ? 'Cập Nhật' : 'Thêm Mới'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- HÀM MỞ DIALOG THÊM / SỬA TOPPING ---
  void _openToppingDialog({Map<String, dynamic>? topping}) {
    final isEditing = topping != null;
    final String docId = topping?['id']?.toString() ?? '';
    final nameController = TextEditingController(
        text: topping?['name'] ?? topping?['ten'] ?? '');
    final priceController = TextEditingController(
        text: topping != null
            ? (topping['price'] ?? topping['gia'] ?? 0).toString()
            : '');
    final imageController = TextEditingController(
        text: topping?['imageUrl'] ?? topping?['image'] ?? '');
    final descController = TextEditingController(
        text: topping?['description'] ?? topping?['desc'] ?? '');
    
    final rawAvailable = topping?['isAvailable'] ?? topping?['available'];
    bool isAvailable = rawAvailable == null ? true : (rawAvailable == true);

    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isEditing ? 'Chỉnh Sửa Topping' : 'Thêm Topping Mới',
                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBrown),
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tên Topping
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tên topping *',
                            prefixIcon: Icon(Icons.cookie, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập tên topping';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Giá tiền
                        TextFormField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giá topping (VNĐ) *',
                            prefixIcon: Icon(Icons.attach_money, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập giá';
                            }
                            final p = int.tryParse(val.trim());
                            if (p == null || p < 0) {
                              return 'Giá tiền không hợp lệ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Link hình ảnh
                        TextFormField(
                          controller: imageController,
                          decoration: const InputDecoration(
                            labelText: 'Link hình ảnh (URL)',
                            prefixIcon: Icon(Icons.image, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Mô tả
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả topping',
                            prefixIcon: Icon(Icons.description, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Trạng thái còn hàng
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Trạng thái còn hàng',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          value: isAvailable,
                          activeColor: primaryBrown,
                          onChanged: (val) {
                            setDialogState(() {
                              isAvailable = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final data = {
                            'name': nameController.text.trim(),
                            'price': int.parse(priceController.text.trim()),
                            'imageUrl': imageController.text.trim(),
                            'description': descController.text.trim(),
                            'isAvailable': isAvailable,
                          };

                          try {
                            if (isEditing && docId.isNotEmpty) {
                              await _dbService.updateTopping(docId, data);
                              _showSnackBar('✅ Đã cập nhật topping "${data['name']}" thành công!');
                            } else {
                              data['createdAt'] = FieldValue.serverTimestamp();
                              await _dbService.addTopping(data);
                              _showSnackBar('✅ Đã thêm topping mới "${data['name']}" thành công!');
                            }
                            if (mounted && ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            _showSnackBar('❌ Lỗi khi lưu topping: $e', isError: true);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEditing ? 'Cập Nhật' : 'Thêm Mới'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      appBar: AppBar(
        title: const Text('Quản Lý Thực Đơn & Topping'),
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentOrange,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(icon: Icon(Icons.local_cafe_rounded), text: 'Đồ Uống'),
            Tab(icon: Icon(Icons.cookie_rounded), text: 'Topping'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildToppingsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _openProductDialog();
          } else {
            _openToppingDialog();
          }
        },
        backgroundColor: accentOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0 ? 'Thêm Đồ Uống' : 'Thêm Topping',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- TAB 1: DANH SÁCH ĐỒ UỐNG ---
  Widget _buildProductsTab() {
    return StreamBuilder<List<ProductModel>>(
      stream: _dbService.getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: primaryBrown),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 54, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'Lỗi tải danh sách đồ uống: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.coffee_rounded, size: 64, color: Colors.brown.shade200),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có đồ uống nào trong thực đơn.',
                  style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openProductDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm đồ uống ngay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final product = products[index];
            final isDeleting = _deletingItemIds.contains(product.id);

            return Card(
              elevation: 2,
              shadowColor: Colors.brown.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Ảnh món
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: product.imageUrl.isNotEmpty
                          ? Image.network(
                              product.imageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: Colors.brown.shade50,
                                child: const Icon(Icons.local_cafe, color: primaryBrown),
                              ),
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: Colors.brown.shade50,
                              child: const Icon(Icons.local_cafe, color: primaryBrown),
                            ),
                    ),
                    const SizedBox(width: 14),

                    // Thông tin món
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  product.category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.brown.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.formattedPrice,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: accentOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.isAvailable ? '🟢 Còn hàng' : '🔴 Hết hàng',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: product.isAvailable ? Colors.green.shade700 : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Thao tác: Switch isAvailable + Nút Sửa + Nút Xóa
                    Column(
                      children: [
                        Switch(
                          value: product.isAvailable,
                          activeColor: primaryBrown,
                          onChanged: (val) async {
                            try {
                              await _dbService.updateProductAvailability(product.id, val);
                              _showSnackBar(
                                val
                                    ? '✅ Đã chuyển "${product.name}" sang Còn hàng'
                                    : '⚠️ Đã chuyển "${product.name}" sang Hết hàng',
                              );
                            } catch (e) {
                              _showSnackBar('❌ Cập nhật thất bại: $e', isError: true);
                            }
                          },
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_note, color: primaryBrown),
                              tooltip: 'Chỉnh sửa món',
                              onPressed: () => _openProductDialog(product: product),
                            ),
                            IconButton(
                              icon: isDeleting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                                    )
                                  : Icon(Icons.delete_outline, color: Colors.red.shade700),
                              tooltip: 'Xóa món',
                              onPressed: isDeleting
                                  ? null
                                  : () => _confirmAndDeleteProduct(product),
                            ),
                          ],
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
    );
  }

  // --- TAB 2: DANH SÁCH TOPPING ---
  Widget _buildToppingsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.getToppingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: primaryBrown),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 54, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'Lỗi tải danh sách topping: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final toppings = snapshot.data ?? [];
        if (toppings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cookie_rounded, size: 64, color: Colors.brown.shade200),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có topping nào trong quán.',
                  style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openToppingDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm topping ngay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: toppings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final topping = toppings[index];
            final String docId = topping['id']?.toString() ?? '';
            final name = topping['name'] ?? topping['ten'] ?? 'Topping';
            final price = (topping['price'] is num)
                ? (topping['price'] as num).toInt()
                : int.tryParse(topping['price']?.toString() ?? '0') ?? 0;
            final img = topping['imageUrl'] ?? topping['image'] ?? '';

            final rawAvailable = topping['isAvailable'] ?? topping['available'];
            final bool isAvailable = rawAvailable == null
                ? true
                : (rawAvailable == true || rawAvailable.toString().toLowerCase() == 'true');

            final formattedPrice = '+${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
            final isDeleting = _deletingItemIds.contains(docId);

            return Card(
              elevation: 2,
              shadowColor: Colors.brown.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Ảnh Topping
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: img.toString().isNotEmpty
                          ? Image.network(
                              img.toString(),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: const Color(0xFFFAF6F0),
                                child: const Icon(Icons.cookie, color: primaryBrown),
                              ),
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: const Color(0xFFFAF6F0),
                              child: const Icon(Icons.cookie, color: primaryBrown),
                            ),
                    ),
                    const SizedBox(width: 14),

                    // Thông tin Topping
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C2C2C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedPrice,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: accentOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAvailable ? '🟢 Còn hàng' : '🔴 Hết hàng',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isAvailable ? Colors.green.shade700 : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Thao tác: Switch isAvailable + Nút Sửa + Nút Xóa
                    Column(
                      children: [
                        Switch(
                          value: isAvailable,
                          activeColor: primaryBrown,
                          onChanged: (val) async {
                            if (docId.isEmpty) return;
                            try {
                              await _dbService.updateToppingAvailability(docId, val);
                              _showSnackBar(
                                val
                                    ? '✅ Đã chuyển topping "$name" sang Còn hàng'
                                    : '⚠️ Đã chuyển topping "$name" sang Hết hàng',
                              );
                            } catch (e) {
                              _showSnackBar('❌ Cập nhật thất bại: $e', isError: true);
                            }
                          },
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_note, color: primaryBrown),
                              tooltip: 'Chỉnh sửa topping',
                              onPressed: () => _openToppingDialog(topping: topping),
                            ),
                            IconButton(
                              icon: isDeleting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                                    )
                                  : Icon(Icons.delete_outline, color: Colors.red.shade700),
                              tooltip: 'Xóa topping',
                              onPressed: isDeleting
                                  ? null
                                  : () => _confirmAndDeleteTopping(docId, name),
                            ),
                          ],
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
    );
  }
}
