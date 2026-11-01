import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedFilter = 'Tất cả';
  final Set<String> _cancellingOrderIds = {};

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color accentOrange = Color(0xFFD87D4A);
  static const Color creamBg = Color(0xFFFBF8F5);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.shade800;
      case 'Preparing':
        return Colors.blue.shade700;
      case 'Completed':
        return Colors.green.shade700;
      case 'Cancelled':
        return Colors.red.shade700;
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
      case 'Cancelled':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_top_rounded;
      case 'Preparing':
        return Icons.blender_rounded;
      case 'Completed':
        return Icons.check_circle_rounded;
      case 'Cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline;
    }
  }

  // Khách hủy đơn khi quán chưa xác nhận. Trả về true nếu hủy thành công.
  Future<bool> _confirmAndCancelOrder(OrderModel order) async {
    if (_cancellingOrderIds.contains(order.id)) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy Đơn Hàng?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
          'Bạn chắc chắn muốn hủy đơn #${order.orderCode} (${order.formattedTotalAmount})?\n\n'
          'Đơn đã hủy không thể khôi phục. Nếu muốn, bạn có thể đặt lại đơn mới.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    setState(() => _cancellingOrderIds.add(order.id));
    try {
      await _dbService.cancelOrder(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã hủy đơn #${order.orderCode}.'), backgroundColor: Colors.green.shade700),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        // Rules từ chối khi đơn không còn ở trạng thái Pending (quán vừa xác nhận)
        final message = e.toString().contains('permission-denied')
            ? 'Không thể hủy: quán đã xác nhận đơn #${order.orderCode}. Vui lòng liên hệ quán nếu cần thay đổi.'
            : 'Hủy đơn thất bại: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _cancellingOrderIds.remove(order.id));
    }
  }

  void _showOrderDetailModal(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo nhỏ
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Modal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết đơn #${order.orderCode}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryBrown,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.formattedCreatedAt,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(order.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.statusDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Danh sách món
              const Text(
                'Danh sách món:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryBrown),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: order.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, index) {
                    final item = order.items[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EAE1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_cafe_rounded, size: 20, color: primaryBrown),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.productName} (x${item.quantity})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              Text(
                                'Size ${item.size} • ${item.sugar} đường • ${item.ice} đá',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                              if (item.toppings.isNotEmpty)
                                Text(
                                  '+ Topping: ${item.toppings.join(', ')}',
                                  style: TextStyle(fontSize: 11.5, color: Colors.brown.shade700),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          item.formattedPrice,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 24),

              // Thông tin người nhận
              Row(
                children: [
                  const Icon(Icons.person_pin_circle_outlined, size: 20, color: primaryBrown),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Khách hàng: ${order.customerName}${order.customerPhone != null ? " • ${order.customerPhone}" : ""}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tổng cộng
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: creamBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng thanh toán:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryBrown),
                    ),
                    Text(
                      order.formattedTotalAmount,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (order.canCustomerCancel) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Hủy đơn này'),
                    onPressed: () async {
                      final cancelled = await _confirmAndCancelOrder(order);
                      if (cancelled && ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'guest';

    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        title: const Text(
          'Đơn Hàng Của Tôi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Tất cả'),
                const SizedBox(width: 8),
                _buildFilterChip('Chờ xác nhận'),
                const SizedBox(width: 8),
                _buildFilterChip('Đang chuẩn bị'),
                const SizedBox(width: 8),
                _buildFilterChip('Đã hoàn thành'),
                const SizedBox(width: 8),
                _buildFilterChip('Đã hủy'),
              ],
            ),
          ),

          // Orders Stream
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: _dbService.getCustomerOrdersStream(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryBrown),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi tải dữ liệu: ${snapshot.error}'),
                  );
                }

                final allOrders = snapshot.data ?? [];

                // Lọc theo tab
                final filteredOrders = allOrders.where((order) {
                  if (_selectedFilter == 'Tất cả') return true;
                  if (_selectedFilter == 'Chờ xác nhận') return order.status == 'Pending';
                  if (_selectedFilter == 'Đang chuẩn bị') return order.status == 'Preparing';
                  if (_selectedFilter == 'Đã hoàn thành') return order.status == 'Completed';
                  if (_selectedFilter == 'Đã hủy') return order.status == 'Cancelled';
                  return true;
                }).toList();

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 70, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'Tất cả'
                              ? 'Bạn chưa có đơn hàng nào'
                              : 'Không có đơn hàng "$_selectedFilter"',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Các đơn hàng đặt sẽ hiển thị tại đây để bạn tiện theo dõi!',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = label);
        }
      },
      selectedColor: primaryBrown,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Mã đơn + Badge trạng thái
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_rounded, size: 18, color: primaryBrown),
                  const SizedBox(width: 6),
                  Text(
                    '#${order.orderCode}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: primaryBrown,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(order.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(order.status), size: 14, color: _getStatusColor(order.status)),
                    const SizedBox(width: 4),
                    Text(
                      order.statusDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.formattedCreatedAt,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const Divider(height: 18),

          // Tóm tắt món
          ...order.items.take(2).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '• ${item.productName} (Size ${item.size})',
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF333333)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'x${item.quantity}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
          if (order.items.length > 2)
            Text(
              '+ và ${order.items.length - 2} món khác...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),

          const SizedBox(height: 10),

          // Footer: Tổng tiền + Nút chi tiết
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng tiền:', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                  Text(
                    order.formattedTotalAmount,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: accentOrange,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (order.canCustomerCancel) ...[
                    _cancellingOrderIds.contains(order.id)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                          )
                        : TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () => _confirmAndCancelOrder(order),
                            child: const Text('Hủy đơn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                    const SizedBox(width: 4),
                  ],
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBrown,
                      side: const BorderSide(color: primaryBrown),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showOrderDetailModal(context, order),
                    child: const Text('Xem chi tiết', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
