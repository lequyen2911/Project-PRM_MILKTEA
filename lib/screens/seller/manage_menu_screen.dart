import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
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

  // Danh mục của thực đơn mẫu, luôn có trong danh sách chọn
  static const List<String> _defaultCategories = ['Trà sữa', 'Trà trái cây'];
  static const String _newCategoryOption = '__new_category__';

  // Danh mục đang có, cập nhật mỗi khi danh sách đồ uống thay đổi.
  // Seller chọn từ đây thay vì gõ tự do, để trang khách không bị "trà sữa" / "Trà sữa" thành 2 nút lọc.
  List<String> _knownCategories = [..._defaultCategories];

  /// Thêm các danh mục trong [extra] vào [base], bỏ qua chuỗi rỗng và trùng (không phân biệt hoa thường)
  static List<String> _withCategories(List<String> base, Iterable<String> extra) {
    final result = [...base];
    for (final raw in extra) {
      final category = raw.trim();
      if (category.isNotEmpty && !result.any((c) => c.toLowerCase() == category.toLowerCase())) {
        result.add(category);
      }
    }
    return result;
  }

  /// Trả về cách viết đã có của danh mục (vd: "trà sữa" → "Trà sữa"), hoặc tên đã bỏ khoảng trắng thừa
  static String _canonicalCategory(List<String> options, String name) {
    final trimmed = name.trim();
    return options.firstWhere(
      (c) => c.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => trimmed,
    );
  }

  // Giới hạn 1080px: ảnh chụp điện thoại (~4000px, vài MB) còn khoảng 100–300 KB,
  // upload nhanh hơn và khách tải menu cũng nhẹ hơn
  Future<XFile?> _pickMenuImage() => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

  // Đợi hiệu ứng đóng dialog chạy xong rồi mới dispose,
  // tránh lỗi "TextEditingController was used after being disposed"
  void _disposeAfterDialogClosed(List<TextEditingController> controllers) {
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

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
    final categoryOptions = _withCategories(_knownCategories, [product?.category ?? '']);
    String selectedCategory = product == null
        ? categoryOptions.first
        : _canonicalCategory(categoryOptions, product.category);
    final newCategoryController = TextEditingController();
    final imageController = TextEditingController(text: product?.imageUrl ?? '');
    final descController = TextEditingController(text: product?.description ?? '');
    bool isAvailable = product?.isAvailable ?? true;
    bool isActive = product?.isActive ?? true;

    XFile? pickedImageFile;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? saveError;

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
                        // Chọn ảnh từ điện thoại & Xem trước
                        Center(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.brown.shade50,
                                  child: pickedImageFile != null
                                      ? Image.file(File(pickedImageFile!.path), fit: BoxFit.cover)
                                      : (imageController.text.isNotEmpty
                                          ? Image.network(
                                              imageController.text,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.local_cafe, size: 36, color: primaryBrown),
                                            )
                                          : const Icon(Icons.add_a_photo, size: 36, color: primaryBrown)),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  backgroundColor: accentOrange,
                                  radius: 16,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                    onPressed: isSubmitting
                                        ? null
                                        : () async {
                                            final picked = await _pickMenuImage();
                                            if (picked != null) {
                                              setDialogState(() {
                                                pickedImageFile = picked;
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Chạm vào máy ảnh để chọn ảnh từ thư viện',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),

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
                          // Chỉ nhận chữ số: gõ "30.000" sẽ thành 30000
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Giá bán (VNĐ) *',
                            hintText: 'VD: 30000',
                            prefixIcon: Icon(Icons.attach_money, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            final p = int.tryParse(val?.trim() ?? '');
                            if (p == null || p <= 0) {
                              return 'Vui lòng nhập giá lớn hơn 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Danh mục: chọn từ danh sách có sẵn hoặc thêm mới
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Danh mục *',
                            prefixIcon: Icon(Icons.category, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            ...categoryOptions.map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            ),
                            const DropdownMenuItem(
                              value: _newCategoryOption,
                              child: Text(
                                '+ Danh mục mới...',
                                style: TextStyle(color: accentOrange, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          onChanged: isSubmitting
                              ? null
                              : (val) => setDialogState(() => selectedCategory = val!),
                        ),
                        if (selectedCategory == _newCategoryOption) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: newCategoryController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Tên danh mục mới *',
                              hintText: 'VD: Cà phê',
                              prefixIcon: Icon(Icons.create_new_folder_outlined, color: primaryBrown),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              final name = val?.trim() ?? '';
                              if (name.isEmpty) {
                                return 'Vui lòng nhập tên danh mục';
                              }
                              // Trang khách đã có tab "Topping" riêng
                              if (name.toLowerCase() == 'topping') {
                                return '"Topping" là tab riêng, hãy đặt tên khác';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Link hình ảnh (hoặc URL tự động sau khi upload)
                        TextFormField(
                          controller: imageController,
                          decoration: const InputDecoration(
                            labelText: 'Link hình ảnh (URL hoặc tự tải lên)',
                            prefixIcon: Icon(Icons.image, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          // Dán link mới thì bỏ ảnh đã chọn từ máy và cập nhật khung xem trước
                          onChanged: (_) => setDialogState(() => pickedImageFile = null),
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
                        const SizedBox(height: 8),

                        // Trạng thái hiển thị (isActive)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Trạng thái hiển thị (Active)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                          subtitle: const Text(
                            'Bật để hiển thị cho khách hàng, tắt để ẩn',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: isActive,
                          activeColor: primaryBrown,
                          onChanged: (val) {
                            setDialogState(() {
                              isActive = val;
                            });
                          },
                        ),

                        // Trạng thái còn hàng (isAvailable)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Trạng thái còn hàng',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                          subtitle: const Text(
                            'Bật nếu còn hàng, tắt nếu hết hàng (không cho mua)',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: isAvailable,
                          activeColor: primaryBrown,
                          onChanged: (val) {
                            setDialogState(() {
                              isAvailable = val;
                            });
                          },
                        ),
                        if (saveError != null) _buildSaveError(saveError!),
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
                          setDialogState(() {
                            isSubmitting = true;
                            saveError = null;
                          });

                          String imageUrl = imageController.text.trim();
                          final category = selectedCategory == _newCategoryOption
                              ? _canonicalCategory(categoryOptions, newCategoryController.text)
                              : selectedCategory;

                          try {
                            // Nếu có chọn ảnh mới từ điện thoại, upload lên Cloudinary để lấy link
                            if (pickedImageFile != null) {
                              imageUrl = await _dbService.uploadProductImage(File(pickedImageFile!.path));
                            }

                            final data = {
                              'name': nameController.text.trim(),
                              'basePrice': int.parse(priceController.text.trim()),
                              'category': category,
                              'imageUrl': imageUrl,
                              'description': descController.text.trim(),
                              'isAvailable': isAvailable,
                              'isActive': isActive,
                            };

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
                            // Hiện lỗi ngay trong form, SnackBar ở màn hình phía sau bị lớp mờ của dialog che
                            setDialogState(() {
                              isSubmitting = false;
                              saveError = 'Lỗi khi lưu dữ liệu: $e';
                            });
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
    ).then((_) => _disposeAfterDialogClosed([
          nameController,
          priceController,
          newCategoryController,
          imageController,
          descController,
        ]));
  }

  // Khung báo lỗi đỏ ở cuối form thêm / sửa
  Widget _buildSaveError(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800, fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
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

    XFile? pickedToppingImage;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? saveError;

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
                        // Chọn ảnh Topping
                        Center(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.brown.shade50,
                                  child: pickedToppingImage != null
                                      ? Image.file(File(pickedToppingImage!.path), fit: BoxFit.cover)
                                      : (imageController.text.isNotEmpty
                                          ? Image.network(
                                              imageController.text,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.cookie, size: 32, color: primaryBrown),
                                            )
                                          : const Icon(Icons.add_a_photo, size: 32, color: primaryBrown)),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  backgroundColor: accentOrange,
                                  radius: 15,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                    onPressed: isSubmitting
                                        ? null
                                        : () async {
                                            final picked = await _pickMenuImage();
                                            if (picked != null) {
                                              setDialogState(() {
                                                pickedToppingImage = picked;
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

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
                          // Chỉ nhận chữ số: gõ "5.000" sẽ thành 5000
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Giá topping (VNĐ) *',
                            hintText: 'VD: 5000 (nhập 0 nếu tặng kèm)',
                            prefixIcon: Icon(Icons.attach_money, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (int.tryParse(val?.trim() ?? '') == null) {
                              return 'Vui lòng nhập giá (chỉ gõ số)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Link hình ảnh
                        TextFormField(
                          controller: imageController,
                          decoration: const InputDecoration(
                            labelText: 'Link hình ảnh (URL hoặc tự tải lên)',
                            prefixIcon: Icon(Icons.image, color: primaryBrown),
                            border: OutlineInputBorder(),
                          ),
                          // Dán link mới thì bỏ ảnh đã chọn từ máy và cập nhật khung xem trước
                          onChanged: (_) => setDialogState(() => pickedToppingImage = null),
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
                        if (saveError != null) _buildSaveError(saveError!),
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
                          setDialogState(() {
                            isSubmitting = true;
                            saveError = null;
                          });

                          String imageUrl = imageController.text.trim();

                          try {
                            // Nếu có chọn ảnh mới từ điện thoại, upload lên Cloudinary để lấy link
                            if (pickedToppingImage != null) {
                              imageUrl = await _dbService.uploadProductImage(File(pickedToppingImage!.path));
                            }

                            final data = {
                              'name': nameController.text.trim(),
                              'price': int.parse(priceController.text.trim()),
                              'imageUrl': imageUrl,
                              'description': descController.text.trim(),
                              'isAvailable': isAvailable,
                            };

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
                            setDialogState(() {
                              isSubmitting = false;
                              saveError = 'Lỗi khi lưu topping: $e';
                            });
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
    ).then((_) => _disposeAfterDialogClosed([
          nameController,
          priceController,
          imageController,
          descController,
        ]));
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
      stream: _dbService.getProductsStream(), // Admin xem toàn bộ sản phẩm (kể cả ẩn isActive = false)
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
        _knownCategories = _withCategories(_defaultCategories, products.map((p) => p.category));
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
                          // Wrap thay vì Row: cột này hẹp (~90px) nên 2 nhãn tự xuống dòng khi không đủ chỗ
                          Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            children: [
                              Text(
                                product.isActive ? '👁️ Hiển thị' : '🔒 Đã ẩn',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: product.isActive ? Colors.blue.shade700 : Colors.grey,
                                ),
                              ),
                              Text(
                                product.isAvailable ? '🟢 Còn hàng' : '🔴 Hết hàng',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: product.isAvailable ? Colors.green.shade700 : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Thao tác: Switches + Nút Sửa + Nút Xóa
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Quick toggle Active
                            Tooltip(
                              message: product.isActive ? 'Đang hiện (Chạm để ẩn)' : 'Đang ẩn (Chạm để hiện)',
                              child: Switch(
                                value: product.isActive,
                                activeColor: Colors.blue.shade700,
                                onChanged: (val) async {
                                  try {
                                    await _dbService.updateProductActiveStatus(product.id, val);
                                    _showSnackBar(
                                      val
                                          ? '👁️ Đã hiển thị "${product.name}" với khách hàng'
                                          : '🔒 Đã ẩn "${product.name}" khỏi khách hàng',
                                    );
                                  } catch (e) {
                                    _showSnackBar('❌ Cập nhật thất bại: $e', isError: true);
                                  }
                                },
                              ),
                            ),
                            // Quick toggle Available
                            Tooltip(
                              message: product.isAvailable ? 'Còn hàng (Chạm để hết hàng)' : 'Hết hàng (Chạm để còn hàng)',
                              child: Switch(
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
                            ),
                          ],
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
