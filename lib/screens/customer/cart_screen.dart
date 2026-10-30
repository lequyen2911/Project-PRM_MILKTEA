import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cart_item_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/database_service.dart';
import 'map_picker_screen.dart';
import 'order_history_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final DatabaseService _dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // Vị trí tọa độ bắt buộc từ bản đồ
  double? _selectedLat;
  double? _selectedLng;
  String? _mapAddressText;

  String _paymentMethod = 'COD'; // 'COD' hoặc 'BANKING'
  bool _isSubmitting = false;

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color accentOrange = Color(0xFFD87D4A);
  static const Color creamBg = Color(0xFFFBF8F5);

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Tự động nạp thông tin user hiện tại nếu có
  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _nameController.text = user.displayName!;
      }
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          if (data != null) {
            if (_nameController.text.isEmpty && data['name'] != null) {
              _nameController.text = data['name'];
            }
            if (data['phone'] != null) {
              _phoneController.text = data['phone'];
            }
            if (data['address'] != null) {
              _addressController.text = data['address'];
            }
          }
        }
      } catch (_) {}
    }
  }

  // Tính phí vận chuyển theo nấc giá trị đơn hàng:
  // - Đơn hàng dưới 50.000đ: 15.000đ ship
  // - Từ 50.000đ đến 100.000đ: 10.000đ ship
  // - Trên 100.000đ: Miễn phí ship (0đ)
  int _calculateShippingFee(int subtotal) {
    if (subtotal == 0) return 0;
    if (subtotal < 50000) {
      return 15000;
    } else if (subtotal <= 100000) {
      return 10000;
    } else {
      return 0;
    }
  }

  // Xử lý đặt hàng
  Future<void> _processCheckout(CartProvider cart) async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giỏ hàng của bạn đang trống!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Bắt buộc người dùng phải ghim vị trí chính xác trên bản đồ
    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vui lòng ghim vị trí nhận hàng chính xác trên Bản đồ để đặt hàng!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.deepOrange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Ẩn mọi thông báo cũ (ví dụ: thông báo "Đã thêm vào giỏ hàng" còn đọng lại)
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // 1. Kiểm tra lại trạng thái stock (isAvailable) và active (isActive) của từng sản phẩm trong giỏ hàng từ Firestore
      for (var item in cart.itemList) {
        final freshProduct = await _dbService.getProductById(item.productId);
        if (freshProduct == null || !freshProduct.isActive || !freshProduct.isAvailable) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Sản Phẩm Hết Hàng', style: TextStyle(color: Colors.red, fontSize: 16)),
                ],
              ),
              content: Text(
                'Món "${item.productName}" trong giỏ hàng hiện đã hết hàng hoặc không còn hoạt động. Vui lòng xóa món này khỏi giỏ hàng trước khi tiếp tục đặt hàng.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          );
          return;
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();
      final randomSuffix = (now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
      final orderCode = 'TS$randomSuffix';

      final int subtotal = cart.totalAmount;
      final int shippingFee = _calculateShippingFee(subtotal);
      final int totalAmount = subtotal + shippingFee;

      final orderData = {
        'orderCode': orderCode,
        'userId': user?.uid ?? 'guest',
        'customerName': _nameController.text.trim(),
        'customerEmail': user?.email ?? '',
        'customerPhone': _phoneController.text.trim(),
        'deliveryAddress': _addressController.text.trim(),
        'latitude': _selectedLat,
        'longitude': _selectedLng,
        'mapAddress': _mapAddressText,
        'note': _noteController.text.trim(),
        'paymentMethod': _paymentMethod,
        'items': cart.itemList.map((item) => item.toOrderItemModel().toMap()).toList(),
        'subtotal': subtotal,
        'shippingFee': shippingFee,
        'totalAmount': totalAmount,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _dbService.createOrder(orderData);

      // Lưu lại sđt & địa chỉ vào hồ sơ người dùng để lần sau tiện đặt lại
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'name': _nameController.text.trim(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      // Xóa sạch giỏ hàng sau khi đặt thành công
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      cart.clear();

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Hiển thị dialog xác nhận thành công
      _showSuccessDialog(orderCode, totalAmount);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đặt hàng thất bại: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showSuccessDialog(String orderCode, int totalAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 50),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đặt Hàng Thành Công! 🎉',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBrown),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Mã đơn hàng: #$orderCode',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: accentOrange),
              ),
              const SizedBox(height: 8),
              Text(
                'Tổng thanh toán: ${CartItemModel.formatVnd(totalAmount)}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Quán đã nhận được đơn hàng và đang chuẩn bị những ly trà sữa thơm ngon nhất cho bạn!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Xem đơn hàng của tôi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); // đóng dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Trở về màn hình chính
                },
                child: const Text('Tiếp tục đặt món', style: TextStyle(color: primaryBrown)),
              ),
            ],
          ),
        );
      },
    );
  }

  // Xác nhận xóa toàn bộ giỏ hàng
  void _confirmClearCart(CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa tất cả món trong giỏ hàng không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              cart.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Xóa hết'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final subtotal = cart.totalAmount;
    final shippingFee = _calculateShippingFee(subtotal);
    final totalAmount = subtotal + shippingFee;

    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        title: const Text(
          'Giỏ Hàng Của Bạn',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!cart.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Xóa toàn bộ giỏ hàng',
              onPressed: () => _confirmClearCart(cart),
            ),
        ],
      ),
      body: cart.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề danh sách món
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Món đã chọn (${cart.totalQuantity} ly)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryBrown,
                          ),
                        ),
                        Text(
                          '${cart.itemList.length} loại món',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Danh sách món trong giỏ
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cart.itemList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = cart.itemList[index];
                        return _buildCartItemCard(cart, item);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Thông tin giao hàng
                    _buildDeliveryInfoCard(),

                    const SizedBox(height: 20),

                    // Phương thức thanh toán
                    _buildPaymentMethodCard(),

                    const SizedBox(height: 20),

                    // Chi tiết thanh toán
                    _buildPaymentSummaryCard(subtotal, shippingFee, totalAmount),
                  ],
                ),
              ),
            ),
      bottomSheet: cart.isEmpty
          ? null
          : _buildBottomCheckoutBar(cart, totalAmount),
    );
  }

  // Widget hiển thị khi giỏ hàng trống
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: Color(0xFFBCAAA4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Giỏ hàng của bạn đang trống',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy chọn cho mình những ly trà sữa thơm lừng và topping hấp dẫn nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('Khám phá thực đơn ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Card cho từng món trong giỏ hàng
  Widget _buildCartItemCard(CartProvider cart, CartItemModel item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh món
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 76,
              height: 76,
              color: Colors.grey.shade100,
              child: item.imageUrl.isNotEmpty
                  ? (item.imageUrl.startsWith('http')
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_cafe_rounded,
                            color: primaryBrown,
                            size: 32,
                          ),
                        )
                      : Image.asset(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_cafe_rounded,
                            color: primaryBrown,
                            size: 32,
                          ),
                        ))
                  : const Icon(Icons.local_cafe_rounded, color: primaryBrown, size: 32),
            ),
          ),
          const SizedBox(width: 12),

          // Thông tin chi tiết món & tùy biến
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => cart.removeItem(item.id),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Tags size, đường, đá
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildOptionTag('Size ${item.size}'),
                    _buildOptionTag('${item.sugar} đường'),
                    _buildOptionTag('${item.ice} đá'),
                  ],
                ),

                // Danh sách topping nếu có
                if (item.toppings.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+ ${item.toppings.join(', ')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.brown.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Đơn giá & Nút điều chỉnh số lượng
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.formattedTotalPrice,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: accentOrange,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => cart.decrementQuantity(item.id),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Icon(Icons.remove, size: 16, color: primaryBrown),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => cart.incrementQuantity(item.id),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Icon(Icons.add, size: 16, color: primaryBrown),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildOptionTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EAE1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10.5, color: Color(0xFF6D4C41), fontWeight: FontWeight.w500),
      ),
    );
  }

  // Card thông tin giao hàng
  Widget _buildDeliveryInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined, color: primaryBrown, size: 20),
              SizedBox(width: 8),
              Text(
                'Địa Chỉ Nhận Hàng',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Họ và tên người nhận *',
              isDense: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập tên người nhận';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại nhận hàng *',
              hintText: 'VD: 0987654321',
              isDense: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập số điện thoại nhận hàng';
              }
              final cleanPhone = value.trim().replaceAll(RegExp(r'[\s.-]'), '');
              // Kiểm tra định dạng số điện thoại Việt Nam: bắt đầu bằng 0 hoặc +84, theo sau là đầu số 3, 5, 7, 8, 9 và đủ 10 chữ số
              final phoneRegex = RegExp(r'^(0|\+84)(3|5|7|8|9)[0-9]{8}$');
              if (!phoneRegex.hasMatch(cleanPhone)) {
                return 'Số điện thoại không hợp lệ (VD: 0912345678)';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Widget Bắt buộc Ghim vị trí trên bản đồ
          _buildMapPickerCard(),

          const SizedBox(height: 14),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ giao hàng chi tiết *',
              isDense: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home_outlined, size: 20),
              hintText: 'Số nhà, ngõ, tên đường, phường/xã (tự điền khi ghim map)...',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng ghim bản đồ hoặc nhập địa chỉ';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho quán (nếu có)',
              isDense: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
              hintText: 'Ví dụ: gọi trước khi giao, nhiều đá riêng...',
            ),
          ),
        ],
      ),
    );
  }

  // Widget tương tác mở bản đồ ghim vị trí nhận hàng
  Widget _buildMapPickerCard() {
    final hasLocation = _selectedLat != null && _selectedLng != null;

    return InkWell(
      onTap: () async {
        final result = await Navigator.push<MapPickerResult>(
          context,
          MaterialPageRoute(
            builder: (_) => MapPickerScreen(
              initialLat: _selectedLat,
              initialLng: _selectedLng,
            ),
          ),
        );

        if (result != null) {
          setState(() {
            _selectedLat = result.latitude;
            _selectedLng = result.longitude;
            _mapAddressText = result.address;
            _addressController.text = result.address;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasLocation ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasLocation ? Colors.green.shade600 : accentOrange,
            width: hasLocation ? 1.2 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasLocation ? Colors.green.shade100 : const Color(0xFFFFE0B2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasLocation ? Icons.check_circle_rounded : Icons.add_location_alt_rounded,
                color: hasLocation ? Colors.green.shade800 : accentOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasLocation ? 'Vị trí đã ghim trên map' : 'Ghim vị trí nhận hàng *',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: hasLocation ? Colors.green.shade900 : const Color(0xFFBF360C),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasLocation ? Colors.green.shade600 : Colors.deepOrange.shade600,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasLocation ? 'Đã ghim' : 'Bắt buộc',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasLocation
                        ? ((_mapAddressText != null && _mapAddressText!.isNotEmpty)
                            ? _mapAddressText!
                            : (_addressController.text.isNotEmpty
                                ? _addressController.text
                                : 'Đã xác nhận vị trí (Chạm để đổi)'))
                        : 'Chạm vào đây để mở bản đồ và ghim vị trí nhận hàng',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasLocation ? Colors.black87 : Colors.brown.shade700,
                      fontWeight: hasLocation ? FontWeight.w500 : FontWeight.normal,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: hasLocation ? Colors.green.shade700 : accentOrange,
            ),
          ],
        ),
      ),
    );
  }

  // Card phương thức thanh toán (Duy nhất Tiền mặt khi nhận hàng COD)
  Widget _buildPaymentMethodCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payment_outlined, color: primaryBrown, size: 20),
              SizedBox(width: 8),
              Text(
                'Phương Thức Thanh Toán',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentOrange.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0B2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments_rounded, color: accentOrange, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Tiền mặt khi nhận hàng (COD)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: primaryBrown,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.check_circle, size: 16, color: Colors.green),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Thanh toán trực tiếp bằng tiền mặt cho shipper khi nhận được trà sữa',
                        style: TextStyle(fontSize: 11.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card chi tiết thanh toán
  Widget _buildPaymentSummaryCard(int subtotal, int shippingFee, int totalAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi Tiết Thanh Toán',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tạm tính tiền món', style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5)),
              Text(CartItemModel.formatVnd(subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Phí giao hàng', style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5)),
                  if (subtotal > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: shippingFee == 0
                            ? Colors.green.shade50
                            : (shippingFee == 10000 ? Colors.blue.shade50 : Colors.orange.shade50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        shippingFee == 0
                            ? 'Freeship (>100k)'
                            : (shippingFee == 10000 ? 'Ưu đãi 10k (50k-100k)' : '15k (<50k)'),
                        style: TextStyle(
                          color: shippingFee == 0
                              ? Colors.green.shade700
                              : (shippingFee == 10000 ? Colors.blue.shade700 : Colors.orange.shade800),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                shippingFee == 0 ? '0 đ' : CartItemModel.formatVnd(shippingFee),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: shippingFee == 0 ? Colors.green.shade700 : Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng thanh toán',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryBrown),
              ),
              Text(
                CartItemModel.formatVnd(totalAmount),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentOrange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Thanh cố định ở dưới cùng để xác nhận đặt hàng
  Widget _buildBottomCheckoutBar(CartProvider cart, int totalAmount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tổng cộng:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  CartItemModel.formatVnd(totalAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accentOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: _isSubmitting ? null : () => _processCheckout(cart),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Đặt Hàng Ngay',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
