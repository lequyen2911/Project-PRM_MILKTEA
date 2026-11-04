import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../models/store_settings_model.dart';
import '../../providers/cart_provider.dart';
import '../../utils/shipping_policy.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/database_seeder.dart';
import '../auth/login_screen.dart';
import 'manage_menu_screen.dart';
import 'seller_orders_screen.dart';
import 'store_settings_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isSyncing = false;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const Color primaryBrown = Color(0xFF6D4C41);

  /// Kiểm tra xem thời gian có thuộc ngày hôm nay theo múi giờ Việt Nam (Asia/Ho_Chi_Minh: UTC+7) không
  bool _isTodayVietnam(DateTime? date) {
    if (date == null) return false;
    final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final vnDate = date.toUtc().add(const Duration(hours: 7));
    return vnDate.year == vnNow.year &&
        vnDate.month == vnNow.month &&
        vnDate.day == vnNow.day;
  }

  bool _isCurrentMonth(DateTime date) {
    final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    return date.year == vnNow.year && date.month == vnNow.month;
  }

  /// Cho phép Admin chọn tháng/năm bất kỳ
  Future<void> _selectMonthYear(BuildContext context) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: primaryBrown),
                  SizedBox(width: 8),
                  Text('Chọn Tháng & Năm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DropdownButton<int>(
                        value: tempMonth,
                        items: List.generate(12, (index) => index + 1).map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text('Tháng $m', style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => tempMonth = val);
                        },
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: tempYear,
                        items: List.generate(3, (index) => now.year - 2 + index).map((y) {
                          return DropdownMenuItem(
                            value: y,
                            child: Text('Năm $y', style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => tempYear = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    // Không cho chọn tháng tương lai
                    if (tempYear > now.year || (tempYear == now.year && tempMonth > now.month)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Không thể chọn tháng trong tương lai')),
                      );
                      return;
                    }
                    setState(() {
                      _selectedMonth = DateTime(tempYear, tempMonth);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Áp dụng'),
                ),
              ],
            );
          },
        );
      },
    );
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
              Flexible(
                child: Text('Đồng Bộ Thực Đơn', style: TextStyle(fontWeight: FontWeight.bold, color: primaryBrown)),
              ),
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
              // Seller cũng có thể đã thêm món vào giỏ từ trang khách
              context.read<CartProvider>().clear();
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

            // 2. KHU VỰC THỐNG KÊ THEO THÁNG (TASK 1) & THỐNG KÊ HÔM NAY
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_rounded, color: primaryBrown, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Thống Kê Theo Tháng',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _selectMonthYear(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.brown.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.brown.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: primaryBrown),
                        const SizedBox(width: 4),
                        Text(
                          'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: primaryBrown,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 18, color: primaryBrown),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Selector điều hướng Tháng trước / Tháng sau
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: primaryBrown,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    label: const Text('Tháng trước', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                      });
                    },
                  ),
                  Text(
                    'Tháng ${_selectedMonth.month} / ${_selectedMonth.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryBrown),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: _isCurrentMonth(_selectedMonth) ? Colors.grey : primaryBrown,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    label: const Text('Tháng sau', style: TextStyle(fontSize: 12)),
                    onPressed: _isCurrentMonth(_selectedMonth)
                        ? null
                        : () {
                            setState(() {
                              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                            });
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

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

                // 1. Map lưu ngày đặt hàng đầu tiên của từng khách hàng để tính đơn từ khách mới
                final Map<String, DateTime> customerFirstOrderDate = {};
                for (var order in orders) {
                  if (order.createdAt != null) {
                    final customerKey = order.userId.isNotEmpty
                        ? order.userId
                        : (order.customerEmail.isNotEmpty ? order.customerEmail : order.id);
                    if (!customerFirstOrderDate.containsKey(customerKey) ||
                        order.createdAt!.isBefore(customerFirstOrderDate[customerKey]!)) {
                      customerFirstOrderDate[customerKey] = order.createdAt!;
                    }
                  }
                }

                // 2. Lọc danh sách đơn theo Tháng/Năm được chọn (múi giờ UTC+7 Việt Nam)
                final selectedMonthOrders = orders.where((order) {
                  if (order.createdAt == null) return false;
                  final vnDate = order.createdAt!.toUtc().add(const Duration(hours: 7));
                  return vnDate.year == _selectedMonth.year && vnDate.month == _selectedMonth.month;
                }).toList();

                // 3. Tính toán các chỉ số của tháng được chọn
                int monthlyTotalOrders = selectedMonthOrders.length;
                int monthlyCompletedOrders = 0;
                int monthlyPendingOrders = 0;
                int monthlyCancelledOrders = 0;
                int monthlyCompletedRevenue = 0; // Chỉ tính đơn Completed!
                int newCustomerOrdersCount = 0;

                for (var order in selectedMonthOrders) {
                  final status = order.status.trim();
                  if (status == 'Completed') {
                    monthlyCompletedOrders++;
                    monthlyCompletedRevenue += order.totalAmount;
                  } else if (status == 'Pending') {
                    monthlyPendingOrders++;
                  } else if (status == 'Cancelled') {
                    monthlyCancelledOrders++;
                  }

                  // Kiểm tra xem đơn này có phải từ khách hàng mới (có đơn đầu tiên trong tháng này) không
                  final customerKey = order.userId.isNotEmpty
                      ? order.userId
                      : (order.customerEmail.isNotEmpty ? order.customerEmail : order.id);
                  final firstOrder = customerFirstOrderDate[customerKey];
                  if (firstOrder != null) {
                    final vnFirst = firstOrder.toUtc().add(const Duration(hours: 7));
                    if (vnFirst.year == _selectedMonth.year && vnFirst.month == _selectedMonth.month) {
                      newCustomerOrdersCount++;
                    }
                  }
                }

                // Tính riêng chỉ số hôm nay để giữ nguyên widget Thống kê nhanh Hôm nay
                int todayCompletedRevenue = 0;
                int pendingOrdersCount = 0;
                int todayTotalOrdersCount = 0;

                for (var order in orders) {
                  final isToday = _isTodayVietnam(order.createdAt);
                  if (order.status.trim() == 'Pending') {
                    pendingOrdersCount++;
                  }
                  if (isToday && order.status.trim() != 'Cancelled') {
                    todayTotalOrdersCount++;
                    if (order.status.trim() == 'Completed') {
                      todayCompletedRevenue += order.totalAmount;
                    }
                  }
                }

                return Column(
                  children: [
                    // Thẻ Doanh thu Tháng (Nổi bật chính)
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.monetization_on, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Doanh thu tháng (Đã hoàn thành)',
                                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'T${_selectedMonth.month}/${_selectedMonth.year}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatVnd(monthlyCompletedRevenue),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tính từ $monthlyCompletedOrders đơn Completed trong Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Lưới 5 thẻ chỉ số của Tháng được chọn
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.receipt_long,
                                color: primaryBrown,
                                title: 'Tổng đơn tháng',
                                value: '$monthlyTotalOrders đơn',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.check_circle_rounded,
                                color: Colors.green.shade700,
                                title: 'Đã hoàn thành',
                                value: '$monthlyCompletedOrders đơn',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.hourglass_top_rounded,
                                color: Colors.orange.shade800,
                                title: 'Chờ xác nhận',
                                value: '$monthlyPendingOrders đơn',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.cancel_rounded,
                                color: Colors.red.shade700,
                                title: 'Đã hủy',
                                value: '$monthlyCancelledOrders đơn',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildStatCard(
                          icon: Icons.person_add_alt_1_rounded,
                          color: Colors.blue.shade800,
                          title: 'Đơn từ khách hàng mới',
                          value: '$newCustomerOrdersCount đơn trong tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                          isFullWidth: true,
                        ),
                      ],
                    ),

                    if (selectedMonthOrders.isEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chưa có đơn hàng nào trong Tháng ${_selectedMonth.month}/${_selectedMonth.year}.',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Thẻ phụ: Thống kê nhanh Hôm nay
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.brown.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.today_rounded, color: Colors.orange.shade800, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hôm Nay',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'Doanh thu: ${_formatVnd(todayCompletedRevenue)} • Đang chờ: $pendingOrdersCount • Tổng đơn: $todayTotalOrdersCount',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
            const SizedBox(height: 12),

            // Thẻ Vị trí quán & giao hàng (dùng để tính phí ship theo km)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StoreSettingsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: StreamBuilder<StoreSettings?>(
                  stream: _dbService.getStoreSettingsStream(),
                  builder: (context, snapshot) {
                    final settings = snapshot.data;
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.storefront_rounded, color: Colors.green.shade800, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vị Trí Quán & Giao Hàng',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settings == null
                                    ? 'Chưa cài vị trí: phí ship đang tính theo giá trị đơn'
                                    : 'Giao trong ${ShippingPolicy.formatKm(settings.deliveryRadiusKm)}'
                                        '${settings.address.isNotEmpty ? ' • ${settings.address}' : ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: settings == null ? Colors.orange.shade900 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.green.shade700),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
