import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/cart_item_model.dart';
import '../../models/store_settings_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/database_service.dart';
import '../../utils/shipping_policy.dart';
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

  final String _paymentMethod = 'COD'; // Hiện chỉ hỗ trợ COD
  bool _isSubmitting = false;

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color accentOrange = Color(0xFFD87D4A);
  static const Color creamBg = Color(0xFFFBF8F5);

  // Vị trí quán & bán kính giao (null nếu Seller chưa cài: khi đó phí ship tính theo giá trị đơn)
  StoreSettings? _storeSettings;
  StreamSubscription<StoreSettings?>? _storeSettingsSub;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _storeSettingsSub = _dbService.getStoreSettingsStream().listen(
      (settings) {
        if (mounted) setState(() => _storeSettings = settings);
      },
      onError: (_) {}, // Không đọc được cài đặt quán thì vẫn cho đặt hàng với phí theo giá trị đơn
    );
  }

  @override
  void dispose() {
    _storeSettingsSub?.cancel();
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

  // Khoảng cách từ quán tới vị trí khách ghim (null nếu quán chưa cài vị trí hoặc khách chưa ghim)
  double? get _distanceKm {
    if (_storeSettings == null || _selectedLat == null || _selectedLng == null) return null;
    return ShippingPolicy.distanceKm(_storeSettings!.location, LatLng(_selectedLat!, _selectedLng!));
  }

  bool get _isOutOfDeliveryRange {
    final km = _distanceKm;
    return km != null && km > _storeSettings!.deliveryRadiusKm;
  }

  // Phí vận chuyển (quy tắc chi tiết ở ShippingPolicy):
  // - Quán đã cài vị trí: theo km từ quán tới vị trí khách ghim
  // - Quán chưa cài vị trí: theo giá trị đơn như trước
  int _calculateShippingFee(int subtotal) {
    if (_storeSettings == null) return ShippingPolicy.feeByOrderValue(subtotal);
    // Chưa ghim vị trí: tạm tính mức thấp nhất (3 km đầu), ghim xong mới tính đúng theo km
    return ShippingPolicy.feeByDistance(distanceKm: _distanceKm ?? 0, subtotal: subtotal);
  }

  // Nhãn nhỏ cạnh dòng "Phí giao hàng"
  ({String text, Color color, Color background}) _shippingFeeTag(int shippingFee) {
    if (_storeSettings == null) {
      if (shippingFee == 0) return (text: 'Freeship (>100k)', color: Colors.green.shade700, background: Colors.green.shade50);
      if (shippingFee == 10000) return (text: 'Ưu đãi 10k (50k-100k)', color: Colors.blue.shade700, background: Colors.blue.shade50);
      return (text: '15k (<50k)', color: Colors.orange.shade800, background: Colors.orange.shade50);
    }
    final km = _distanceKm;
    if (km == null) {
      return (text: 'Tạm tính, ghim vị trí để tính theo km', color: Colors.orange.shade800, background: Colors.orange.shade50);
    }
    if (shippingFee == 0) {
      return (text: 'Freeship • ${ShippingPolicy.formatKm(km)}', color: Colors.green.shade700, background: Colors.green.shade50);
    }
    return (text: ShippingPolicy.formatKm(km), color: Colors.blue.shade700, background: Colors.blue.shade50);
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

    // Quán đã cài vùng giao hàng: không nhận đơn ngoài bán kính
    if (_isOutOfDeliveryRange) {
      _showCheckoutNotice(
        icon: Icons.wrong_location_outlined,
        iconColor: Colors.red,
        title: 'Ngoài Vùng Giao Hàng',
        message: 'Vị trí bạn ghim cách quán ${ShippingPolicy.formatKm(_distanceKm!)}, '
            'trong khi quán chỉ giao trong ${ShippingPolicy.formatKm(_storeSettings!.deliveryRadiusKm)}. '
            'Vui lòng ghim lại vị trí gần quán hơn.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Ẩn mọi thông báo cũ (ví dụ: thông báo "Đã thêm vào giỏ hàng" còn đọng lại)
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // 1. Kiểm tra lại từng ly trong giỏ với dữ liệu mới nhất trên Firestore:
      //    món và topping còn bán không, giá có đổi không
      final freshToppings = await _dbService.getToppingsById();
      final priceChanges = <String>[];

      for (var item in cart.itemList) {
        final freshProduct = await _dbService.getProductById(item.productId);

        String? soldOutMessage;
        if (freshProduct == null || !freshProduct.isActive || !freshProduct.isAvailable) {
          soldOutMessage = 'Món "${item.productName}" hiện đã hết hàng hoặc không còn bán.';
        } else {
          final soldOutToppingIds = item.toppingPrices.keys.where((id) {
            final topping = freshToppings[id];
            return topping == null || !DatabaseService.isToppingAvailable(topping);
          }).toList();
          if (soldOutToppingIds.isNotEmpty) {
            final names = soldOutToppingIds
                .map((id) => freshToppings[id]?['name']?.toString() ?? 'một topping')
                .join(', ');
            soldOutMessage = 'Topping $names của món "${item.productName}" hiện đã hết.';
          }
        }

        if (soldOutMessage != null) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          _showCheckoutNotice(
            icon: Icons.error_outline,
            iconColor: Colors.red,
            title: 'Sản Phẩm Hết Hàng',
            message: '$soldOutMessage Vui lòng xóa ly này khỏi giỏ hàng (có thể chọn lại với topping khác) trước khi đặt hàng.',
          );
          return;
        }

        // Quán đã đổi giá món hoặc topping sau lúc khách thêm vào giỏ: cập nhật giỏ theo giá mới
        final oldUnitPrice = item.formattedUnitPrice;
        final changed = cart.updatePrices(
          item.id,
          basePrice: freshProduct!.basePrice,
          toppingPrices: {
            for (final id in item.toppingPrices.keys) id: (freshToppings[id]!['price'] as num).toInt(),
          },
        );
        if (changed) {
          priceChanges.add('• ${item.productName}: $oldUnitPrice → ${cart.items[item.id]!.formattedUnitPrice} / ly');
        }
      }

      // Có giá thay đổi thì dừng lại để khách xem tổng tiền mới rồi mới đặt
      if (priceChanges.isNotEmpty) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showCheckoutNotice(
          icon: Icons.price_change_outlined,
          iconColor: accentOrange,
          title: 'Giá Đã Thay Đổi',
          message: 'Quán vừa cập nhật giá:\n${priceChanges.join('\n')}\n\n'
              'Giỏ hàng đã được cập nhật, bạn kiểm tra lại tổng tiền rồi bấm đặt hàng nhé.',
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();
      // Mã theo mili-giây ở hệ 36 (vd: TSMHE4K2X1): không lặp lại như cách lấy 5 số cuối cũ
      final orderCode = 'TS${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

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
        // Khoảng cách đường chim bay từ quán (km, làm tròn 2 số lẻ); null nếu quán chưa cài vị trí
        'distanceKm': _distanceKm == null ? null : double.parse(_distanceKm!.toStringAsFixed(2)),
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

  // Hộp thoại báo cho khách khi kiểm tra giỏ hàng lúc đặt (hết hàng, đổi giá)
  void _showCheckoutNotice({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title, style: TextStyle(color: iconColor, fontSize: 16)),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
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
  }

  void _showSuccessDialog(String orderCode, int totalAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: SingleChildScrollView(
            child: Column(
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
              storeLocation: _storeSettings?.location,
              deliveryRadiusKm: _storeSettings?.deliveryRadiusKm,
            ),
          ),
        );

        if (result == null || !mounted) return;

        // Chỉ tự điền khi ô địa chỉ trống hoặc vẫn là địa chỉ lấy từ lần ghim trước.
        // Nếu khách đã tự gõ (số nhà, hẻm...) thì hỏi trước, tránh mất phần đã nhập.
        final typedAddress = _addressController.text.trim();
        bool replaceAddress = typedAddress.isEmpty || typedAddress == _mapAddressText;
        if (!replaceAddress) {
          replaceAddress = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Thay địa chỉ đã nhập?', style: TextStyle(fontSize: 16)),
                  content: Text(
                    'Địa chỉ theo vị trí vừa ghim:\n${result.address}\n\nBạn muốn thay địa chỉ đang nhập bằng địa chỉ này không?',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Giữ địa chỉ của tôi'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBrown,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Thay'),
                    ),
                  ],
                ),
              ) ??
              false;
        }
        if (!mounted) return;

        setState(() {
          _selectedLat = result.latitude;
          _selectedLng = result.longitude;
          _mapAddressText = result.address;
          if (replaceAddress) {
            _addressController.text = result.address;
          }
        });
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
                  if (_distanceKm != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _isOutOfDeliveryRange
                          ? '⛔ Ngoài vùng giao: cách quán ${ShippingPolicy.formatKm(_distanceKm!)} '
                              '(tối đa ${ShippingPolicy.formatKm(_storeSettings!.deliveryRadiusKm)})'
                          : 'Cách quán ${ShippingPolicy.formatKm(_distanceKm!)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isOutOfDeliveryRange ? Colors.red.shade700 : Colors.green.shade800,
                      ),
                    ),
                  ],
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
              Expanded(
                child: Row(
                children: [
                  Text('Phí giao hàng', style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5)),
                  if (subtotal > 0) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Builder(builder: (context) {
                        final tag = _shippingFeeTag(shippingFee);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tag.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag.text,
                            style: TextStyle(
                              color: tag.color,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
                ),
              ),
              const SizedBox(width: 8),
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
