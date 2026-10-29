import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/order_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/database_seeder.dart';
import '../auth/login_screen.dart';
import 'manage_menu_screen.dart';
import 'seller_orders_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isSyncing = false;

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color accentOrange = Color(0xFFD87D4A);

  /// Kiểm tra xem thời gian có thuộc ngày hôm nay theo múi giờ Việt Nam (Asia/Ho_Chi_Minh: UTC+7) không
  bool _isTodayVietnam(DateTime? date) {
    if (date == null) return false;
    final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final vnDate = date.toUtc().add(const Duration(hours: 7));
    return vnDate.year == vnNow.year &&
        vnDate.month == vnNow.month &&
        vnDate.day == vnNow.day;
  }

  /// Định dạng tiền VND (vd: 150.000 đ)
  String _formatVnd(int amount) {
    if (amount <= 0) return '0 đ';
    final priceStr = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = priceStr.length - 1; i >= 0; i--) {
      buffer.write(priceStr[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join()} đ';
  }

  /// Xử lý đồng bộ Idempotent dữ liệu chuẩn (Topping & Đồ uống)
  Future<void> _handleSyncData() async {
    if (_isSyncing) return;

    // 1. Hiển thị Dialog xác nhận
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.sync_rounded, color: primaryBrown),
              SizedBox(width: 8),
              Text('Đồng Bộ Thực Đơn', style: TextStyle(fontWeight: FontWeight.bold, color: primaryBrown)),
            ],
          ),
          content: const Text(
            'Ứng dụng sẽ đồng bộ danh sách đồ uống và topping chuẩn lên Cloud Firestore.\n\nLưu ý: Hệ thống chỉ bổ sung các món còn thiếu. Dữ liệu do bạn tự tạo hoặc đã chỉnh sửa sẽ KHÔNG bị xóa hay ghi đè.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đồng bộ ngay'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await DatabaseSeeder.syncStandardMenuData();
      final int addedToppings = result['toppings'] ?? 0;
      final int addedProducts = result['products'] ?? 0;

      if (!mounted) return;

      if (addedToppings > 0 || addedProducts > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã đồng bộ thành công $addedProducts đồ uống và $addedToppings topping mới!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ℹ️ Thực đơn đã đồng bộ, không có dữ liệu chuẩn mới cần bổ sung.'),
            backgroundColor: Colors.blue.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi khi đồng bộ dữ liệu: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      appBar: AppBar(
        title: const Text('Admin Quản lý'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Đồng bộ thực đơn',
            onPressed: _isSyncing ? null : _handleSyncData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Card chào mừng thông tin Chủ quán
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.orange.shade100,
                    child: Icon(Icons.storefront, size: 30, color: Colors.orange.shade800),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Chủ Quán',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHU VỰC THỐNG KÊ NHANH DOANH THU & ĐƠN HÀNG (TASK 3)
            const Row(
              children: [
                Icon(Icons.analytics_rounded, color: primaryBrown, size: 22),
                SizedBox(width: 8),
                Text(
                  'Thống Kê Nhanh Hôm Nay',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<OrderModel>>(
              stream: _dbService.getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: const Center(
                      child: CircularProgressIndicator(color: primaryBrown),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Không thể tính thống kê: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  );
                }

                final orders = snapshot.data ?? [];

                // Tính toán thống kê theo thời gian thực (Realtime Stream)
                int todayCompletedRevenue = 0;
                int pendingOrdersCount = 0;
                int todayTotalOrdersCount = 0;

                for (var order in orders) {
                  final isToday = _isTodayVietnam(order.createdAt);

                  // 1. Số lượng đơn 'Pending' (Đơn đang chờ)
                  if (order.status == 'Pending') {
                    pendingOrdersCount++;
                  }

                  // 2. Doanh thu hôm nay từ đơn 'Completed'
                  if (isToday) {
                    todayTotalOrdersCount++;
                    if (order.status == 'Completed') {
                      todayCompletedRevenue += order.totalAmount;
                    }
                  }
                }

                return Column(
                  children: [
                    // Thẻ Doanh thu hôm nay (Nổi bật chính)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade800, Colors.deepOrange.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.monetization_on, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Doanh thu hôm nay (Đã hoàn thành)',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatVnd(todayCompletedRevenue),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tự động tính từ các đơn Completed ngày ${_getTodayDateStr()}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2 Thẻ chỉ số phụ (Đơn chờ xác nhận & Tổng đơn hôm nay)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.hourglass_top, color: Colors.orange, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Đơn chờ xác nhận',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$pendingOrdersCount đơn',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: pendingOrdersCount > 0 ? Colors.orange.shade900 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.brown.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.shopping_bag_outlined, color: primaryBrown, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tổng đơn trong ngày',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$todayTotalOrdersCount đơn',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBrown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // 3. MENU ĐIỀU HƯỚNG QUẢN LÝ (TASK 1 & TASK 2 INTEGRATION)
            const Row(
              children: [
                Icon(Icons.dashboard_customize, color: primaryBrown, size: 22),
                SizedBox(width: 8),
                Text(
                  'Chức Năng Quản Lý',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                // Thẻ Quản lý Thực đơn
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ManageMenuScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.brown.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.brown.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.restaurant_menu, color: primaryBrown, size: 26),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Quản Lý Thực Đơn',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Đồ uống & Topping',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Thẻ Quản lý Đơn hàng
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SellerOrdersScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.receipt_long, color: Colors.orange.shade900, size: 26),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Quản Lý Đơn Hàng',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Xác nhận đơn realtime',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTodayDateStr() {
    final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    return '${vnNow.day.toString().padLeft(2, '0')}/${vnNow.month.toString().padLeft(2, '0')}/${vnNow.year}';
  }
}
