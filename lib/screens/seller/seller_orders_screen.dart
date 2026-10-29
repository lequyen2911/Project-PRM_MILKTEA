import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedFilter = 'Tất cả';

  // Set để lưu danh sách ID các đơn đang trong quá trình cập nhật (tránh spam click)
  final Set<String> _updatingOrderIds = {};

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color accentOrange = Color(0xFFD87D4A);

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

  Future<void> _handleUpdateStatus(OrderModel order, String newStatus, String statusName) async {
    if (_updatingOrderIds.contains(order.id)) return;

    setState(() {
      _updatingOrderIds.add(order.id);
    });

    try {
      await _dbService.updateOrderStatus(order.id, newStatus);
      _showSnackBar('✅ Đã cập nhật đơn #${order.orderCode} sang "$statusName"');
    } catch (e) {
      _showSnackBar('❌ Cập nhật trạng thái thất bại: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderIds.remove(order.id);
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.shade800;
      case 'Preparing':
        return Colors.blue.shade700;
      case 'Completed':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.shade50;
      case 'Preparing':
        return Colors.blue.shade50;
      case 'Completed':
        return Colors.green.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      appBar: AppBar(
        title: const Text('Quản Lý Đơn Hàng Realtime'),
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Tất cả'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', label: 'Chờ xác nhận'),
                const SizedBox(width: 8),
                _buildFilterChip('Preparing', label: 'Đang chuẩn bị'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', label: 'Đã hoàn thành'),
              ],
            ),
          ),
          const Divider(height: 1),

          // StreamBuilder danh sách đơn hàng
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: _dbService.getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryBrown),
                        SizedBox(height: 12),
                        Text('Đang tải danh sách đơn hàng...'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 60, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text(
                            'Không thể kết nối với Cloud Firestore!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Chi tiết: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                            onPressed: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allOrders = snapshot.data ?? [];

                // Lọc danh sách theo filter
                var filteredOrders = allOrders;
                if (_selectedFilter != 'Tất cả') {
                  filteredOrders = allOrders
                      .where((o) => o.status.toLowerCase() == _selectedFilter.toLowerCase())
                      .toList();
                }

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 64, color: Colors.brown.shade200),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilter == 'Tất cả'
                              ? 'Chưa có đơn hàng nào trên Firestore.'
                              : 'Không có đơn hàng ở trạng thái "$_selectedFilter".',
                          style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, {String? label}) {
    final displayLabel = label ?? value;
    final isSelected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(displayLabel),
      selected: isSelected,
      selectedColor: primaryBrown,
      backgroundColor: const Color(0xFFFAF6F0),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.brown.shade800,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(color: isSelected ? primaryBrown : Colors.brown.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isUpdating = _updatingOrderIds.contains(order.id);
    final statusColor = _getStatusColor(order.status);
    final statusBgColor = _getStatusBgColor(order.status);

    return Card(
      elevation: 2,
      shadowColor: Colors.brown.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header đơn hàng: Mã đơn + Badge Trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt, color: primaryBrown, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Đơn #${order.orderCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    order.statusDisplay,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tên khách hàng & Thời gian đặt
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  order.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (order.customerEmail.isNotEmpty) ...[
                  Text(
                    ' (${order.customerEmail})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  order.formattedCreatedAt,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),

            const Divider(height: 20),

            // Danh sách các món trong đơn
            const Text(
              'Danh sách món:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryBrown),
            ),
            const SizedBox(height: 6),

            if (order.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Không có chi tiết danh sách món trong đơn này.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              )
            else
              Column(
                children: order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF6F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.productName} (x${item.quantity})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                item.formattedPrice,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: accentOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              Text('Size: ${item.size}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                              Text('Đường: ${item.sugar}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                              Text('Đá: ${item.ice}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                            ],
                          ),
                          if (item.toppings.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Topping: ${item.toppings.join(', ')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: primaryBrown,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const Divider(height: 20),

            // Tổng tiền & Nút Thao tác
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TỔNG TIỀN ĐƠN HÀNG', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      order.formattedTotalAmount,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: accentOrange,
                      ),
                    ),
                  ],
                ),

                // NÚT CHUYỂN TRẠNG THÁI THEO YÊU CẦU TASK 2
                _buildActionButton(order, isUpdating),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(OrderModel order, bool isUpdating) {
    if (isUpdating) {
      return const SizedBox(
        width: 120,
        height: 38,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: primaryBrown),
        ),
      );
    }

    if (order.status == 'Pending') {
      return ElevatedButton.icon(
        onPressed: () => _handleUpdateStatus(order, 'Preparing', 'Đang chuẩn bị'),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Xác nhận đơn'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade800,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (order.status == 'Preparing') {
      return ElevatedButton.icon(
        onPressed: () => _handleUpdateStatus(order, 'Completed', 'Hoàn thành'),
        icon: const Icon(Icons.task_alt, size: 18),
        label: const Text('Hoàn thành đơn'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (order.status == 'Completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green),
            SizedBox(width: 4),
            Text(
              'Đã hoàn thành',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container();
  }
}
