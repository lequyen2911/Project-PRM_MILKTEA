import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';
import '../../utils/order_policy.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final DatabaseService _dbService = DatabaseService();
  late final Stream<List<OrderModel>> _ordersStream = _dbService.getOrdersStream();

  // Bộ lọc riêng cho từng tab
  String _todayFilter = 'Tất cả';
  String _historyFilter = 'Tất cả';
  DateTime? _historyDate; // null = mọi ngày
  bool _showOlderOpen = false; // mục "đơn ngày trước chưa xử lý" ở tab Hôm nay

  // Set để lưu danh sách ID các đơn đang trong quá trình cập nhật (tránh spam click)
  final Set<String> _updatingOrderIds = {};

  // Đồng hồ để nhãn "Quá hạn" tự cập nhật khi màn hình đang mở
  DateTime _now = DateTime.now();
  Timer? _clock;

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color accentOrange = Color(0xFFD87D4A);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
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

  // Rules từ chối khi đơn vừa đổi trạng thái hoặc đã quá hạn theo giờ server
  String _updateErrorMessage(Object e) => e.toString().contains('permission-denied')
      ? 'Không thể cập nhật: đơn vừa thay đổi hoặc đã quá hạn xử lý. Danh sách sẽ tự làm mới.'
      : 'Cập nhật trạng thái thất bại: $e';

  Future<void> _runUpdate(OrderModel order, Future<void> Function() update, String doneMessage) async {
    if (_updatingOrderIds.contains(order.id)) return;

    setState(() {
      _updatingOrderIds.add(order.id);
    });

    try {
      await update();
      _showSnackBar(doneMessage);
    } catch (e) {
      _showSnackBar('❌ ${_updateErrorMessage(e)}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderIds.remove(order.id);
        });
      }
    }
  }

  Future<void> _handleUpdateStatus(OrderModel order, String newStatus, String statusName) {
    return _runUpdate(
      order,
      () => _dbService.updateOrderStatus(order.id, newStatus),
      '✅ Đã cập nhật đơn #${order.orderCode} sang "$statusName"',
    );
  }

  Future<void> _handleSellerCancel(OrderModel order) async {
    final overdue = OrderPolicy.isOverdue(order, _now);
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _CancelReasonDialog(
        orderCode: order.orderCode,
        initialReason: overdue ? 'Quá hạn xử lý' : OrderPolicy.sellerCancelReasons.first,
      ),
    );
    if (reason == null || !mounted) return;

    await _runUpdate(
      order,
      () => _dbService.sellerCancelOrder(order.id, reason),
      'Đã hủy đơn #${order.orderCode} ($reason)',
    );
  }

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

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBF8F5),
        appBar: AppBar(
          title: const Text('Quản Lý Đơn Hàng Realtime'),
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.today_rounded, size: 20), text: 'Hôm nay'),
              Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Lịch sử'),
            ],
          ),
        ),
        body: StreamBuilder<List<OrderModel>>(
          stream: _ordersStream,
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
                    ],
                  ),
                ),
              );
            }

            final allOrders = snapshot.data ?? [];
            final todayOrders = allOrders.where((o) => OrderPolicy.belongsToToday(o, _now)).toList();
            // Lịch sử hiển thị tất cả các đơn hàng bao gồm các đơn đã hoàn thành và đã hủy của hôm nay và các ngày trước
            final historyOrders = allOrders;

            return TabBarView(
              children: [
                _buildTodayTab(todayOrders),
                _buildHistoryTab(historyOrders),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- Tab "Hôm nay": đơn hôm nay + đơn cũ còn dở ----------------

  Widget _buildTodayTab(List<OrderModel> orders) {
    final overdueCount = orders.where((o) => OrderPolicy.isOverdue(o, _now)).length;
    // Hết đơn quá hạn thì chip "Quá hạn" biến mất: quay về "Tất cả" để danh sách không trống oan
    final filter = (_todayFilter == 'Quá hạn' && overdueCount == 0) ? 'Tất cả' : _todayFilter;

    var filtered = orders;
    if (filter == 'Quá hạn') {
      filtered = orders.where((o) => OrderPolicy.isOverdue(o, _now)).toList();
    } else if (filter != 'Tất cả') {
      filtered = orders.where((o) => o.status == filter).toList();
    }

    // Đơn đặt hôm nay hiện trước; đơn cũ còn dở gom vào một mục thu gọn để không đẩy đơn mới xuống dưới.
    // Trong mỗi nhóm, đơn quá hạn lên đầu, còn lại giữ thứ tự mới nhất trước.
    List<OrderModel> overdueFirst(Iterable<OrderModel> list) => [
          ...list.where((o) => OrderPolicy.isOverdue(o, _now)),
          ...list.where((o) => !OrderPolicy.isOverdue(o, _now)),
        ];
    bool placedToday(OrderModel o) => o.createdAt == null || OrderPolicy.isSameVnDay(o.createdAt, _now);
    final todayList = overdueFirst(filtered.where(placedToday));
    final olderList = overdueFirst(filtered.where((o) => !placedToday(o)));
    final showOlder = _showOlderOpen || filter == 'Quá hạn';

    return Column(
      children: [
        _buildChipBar([
          _buildFilterChip('Tất cả', filter, (v) => _todayFilter = v),
          if (overdueCount > 0)
            _buildFilterChip('Quá hạn', filter, (v) => _todayFilter = v,
                label: 'Quá hạn ($overdueCount)', warning: true),
          _buildFilterChip('Pending', filter, (v) => _todayFilter = v, label: 'Chờ xác nhận'),
          _buildFilterChip('Preparing', filter, (v) => _todayFilter = v, label: 'Đang chuẩn bị'),
          _buildFilterChip('Completed', filter, (v) => _todayFilter = v, label: 'Đã hoàn thành'),
          _buildFilterChip('Cancelled', filter, (v) => _todayFilter = v, label: 'Đã hủy'),
        ]),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty(filter == 'Tất cả'
                  ? 'Hôm nay chưa có đơn hàng nào.'
                  : 'Không có đơn nào trong mục này.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    _buildSectionTitle('Đơn đặt hôm nay (${todayList.length})'),
                    if (todayList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          filter == 'Tất cả' ? 'Hôm nay chưa có đơn mới.' : 'Không có đơn hôm nay trong mục này.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ),
                    for (final order in todayList)
                      Padding(padding: const EdgeInsets.only(bottom: 14), child: _buildOrderCard(order)),
                    if (olderList.isNotEmpty) ...[
                      _buildOlderOpenHeader(olderList, expanded: showOlder),
                      if (showOlder)
                        for (final order in olderList)
                          Padding(padding: const EdgeInsets.only(bottom: 14), child: _buildOrderCard(order)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryBrown)),
    );
  }

  // Mục thu gọn "Đơn ngày trước chưa xử lý": chạm để mở / đóng
  Widget _buildOlderOpenHeader(List<OrderModel> olderList, {required bool expanded}) {
    final overdue = olderList.where((o) => OrderPolicy.isOverdue(o, _now)).length;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Material(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _showOlderOpen = !_showOlderOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${olderList.length} đơn của ngày trước chưa xử lý xong'
                    '${overdue > 0 ? ' ($overdue quá hạn)' : ''}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade800),
                  ),
                ),
                Text(
                  expanded ? 'Thu gọn' : 'Xem',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.red.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Tab "Lịch sử": tất cả đơn hàng, hỗ trợ lọc theo trạng thái và ngày ----------------

  Widget _buildHistoryTab(List<OrderModel> orders) {
    var filtered = orders;
    if (_historyFilter != 'Tất cả') {
      filtered = filtered.where((o) => o.status.trim().toLowerCase() == _historyFilter.trim().toLowerCase()).toList();
    }
    if (_historyDate != null) {
      filtered = filtered.where((o) => OrderPolicy.isSameVnDay(o.createdAt, _historyDate!)).toList();
    }

    return Column(
      children: [
        _buildChipBar([
          ActionChip(
            avatar: const Icon(Icons.calendar_month_rounded, size: 18, color: primaryBrown),
            label: Text(_historyDate == null ? 'Mọi ngày' : _formatDate(_historyDate!)),
            backgroundColor: const Color(0xFFFAF6F0),
            side: BorderSide(color: Colors.brown.shade200),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: _pickHistoryDate,
          ),
          if (_historyDate != null)
            IconButton(
              tooltip: 'Bỏ lọc ngày',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => _historyDate = null),
            ),
          _buildFilterChip('Tất cả', _historyFilter, (v) => _historyFilter = v),
          _buildFilterChip('Completed', _historyFilter, (v) => _historyFilter = v, label: 'Đã hoàn thành'),
          _buildFilterChip('Cancelled', _historyFilter, (v) => _historyFilter = v, label: 'Đã hủy'),
          _buildFilterChip('Pending', _historyFilter, (v) => _historyFilter = v, label: 'Chờ xác nhận'),
          _buildFilterChip('Preparing', _historyFilter, (v) => _historyFilter = v, label: 'Đang chuẩn bị'),
        ]),
        Container(
          width: double.infinity,
          color: Colors.brown.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: Colors.brown.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Lịch sử toàn bộ đơn hàng (bao gồm các đơn đã hoàn thành và đã hủy của hôm nay và các ngày trước).',
                  style: TextStyle(fontSize: 12, color: Colors.brown.shade600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty('Không có đơn cũ nào phù hợp.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    final prev = index > 0 ? filtered[index - 1] : null;
                    final showHeader = order.createdAt != null &&
                        (prev?.createdAt == null || !OrderPolicy.isSameVnDay(prev!.createdAt, order.createdAt!));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              'Ngày ${_formatDate(order.createdAt!)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBrown),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildOrderCard(order),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pickHistoryDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _historyDate ?? today.subtract(const Duration(days: 1)),
      firstDate: DateTime(2024),
      lastDate: today,
      helpText: 'Xem đơn của ngày',
    );
    if (picked != null && mounted) {
      // Giữa trưa để chắc chắn rơi vào đúng ngày theo giờ Việt Nam
      setState(() => _historyDate = DateTime(picked.year, picked.month, picked.day, 12));
    }
  }

  Widget _buildChipBar(List<Widget> chips) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.brown.shade200),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String value,
    String selectedValue,
    void Function(String) onSelect, {
    String? label,
    bool warning = false,
  }) {
    final displayLabel = label ?? value;
    final isSelected = selectedValue == value;
    final activeColor = warning ? Colors.red.shade700 : primaryBrown;

    return ChoiceChip(
      label: Text(displayLabel),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: warning ? Colors.red.shade50 : const Color(0xFFFAF6F0),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (warning ? Colors.red.shade700 : Colors.brown.shade800),
        fontWeight: isSelected || warning ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(color: isSelected ? activeColor : (warning ? Colors.red.shade200 : Colors.brown.shade200)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (selected) {
        if (selected) {
          setState(() => onSelect(value));
        }
      },
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isUpdating = _updatingOrderIds.contains(order.id);
    final statusColor = _getStatusColor(order.status);
    final statusBgColor = _getStatusBgColor(order.status);
    final isOverdue = OrderPolicy.isOverdue(order, _now);
    final deadline = OrderPolicy.deadline(order);
    final nextStatuses = OrderPolicy.sellerNextStatuses(order, _now);
    final isFromEarlierDay = order.createdAt != null && !OrderPolicy.isSameVnDay(order.createdAt, _now);

    return Card(
      elevation: 2,
      shadowColor: Colors.brown.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOverdue ? BorderSide(color: Colors.red.shade300, width: 1.5) : BorderSide.none,
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header đơn hàng: Mã đơn + Badge Trạng thái
            Row(
              children: [
                const Icon(Icons.receipt, color: primaryBrown, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Đơn #${order.orderCode}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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

            // Hạn xử lý của đơn đang mở
            if (deadline != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                      size: 16,
                      color: isOverdue ? Colors.red.shade700 : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isOverdue
                            ? 'Quá hạn xử lý từ ${_formatTime(deadline)}'
                                '${isFromEarlierDay ? ' ngày ${_formatDate(deadline)}' : ''}. '
                                '${order.status == 'Pending' ? 'Chỉ còn được hủy đơn.' : 'Hãy hoàn thành hoặc hủy để đóng đơn.'}'
                            : order.status == 'Pending'
                                ? 'Cần xác nhận trước ${_formatTime(deadline)}'
                                : 'Hạn hoàn thành ${_formatTime(deadline)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOverdue ? Colors.red.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Tên khách hàng & Thời gian đặt
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    order.customerEmail.isNotEmpty
                        ? '${order.customerName} (${order.customerEmail})'
                        : order.customerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            if ((order.customerPhone ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildInfoLine(Icons.phone_outlined, order.customerPhone!),
            ],
            if (order.deliveryAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildInfoLine(Icons.location_on_outlined, order.deliveryAddress),
            ],
            if (order.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildInfoLine(Icons.note_alt_outlined, 'Ghi chú: ${order.note}'),
            ],
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

            // Tổng tiền & trạng thái khóa
            Row(
              children: [
                Expanded(
                  child: Column(
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
                ),
                if (OrderPolicy.isClosed(order)) _buildClosedBadge(order),
              ],
            ),

            if (order.status == 'Cancelled' && (order.cancelReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Lý do hủy: ${order.cancelReason}',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ],

            // Nút chuyển trạng thái theo OrderPolicy
            if (nextStatuses.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildActionButtons(order, nextStatuses, isUpdating),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.3)),
        ),
      ],
    );
  }

  Widget _buildActionButtons(OrderModel order, List<String> nextStatuses, bool isUpdating) {
    if (isUpdating) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: primaryBrown),
        ),
      );
    }

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    final buttons = <Widget>[];

    if (nextStatuses.contains('Cancelled')) {
      buttons.add(Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _handleSellerCancel(order),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Hủy đơn'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300),
            shape: buttonShape,
          ),
        ),
      ));
    }

    if (nextStatuses.contains('Preparing')) {
      buttons.add(Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _handleUpdateStatus(order, 'Preparing', 'Đang chuẩn bị'),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Xác nhận đơn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            elevation: 1,
            shape: buttonShape,
          ),
        ),
      ));
    }

    if (nextStatuses.contains('Completed')) {
      buttons.add(Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _handleUpdateStatus(order, 'Completed', 'Hoàn thành'),
          icon: const Icon(Icons.task_alt, size: 18),
          label: const Text('Hoàn thành'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            elevation: 1,
            shape: buttonShape,
          ),
        ),
      ));
    }

    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          buttons[i],
        ],
      ],
    );
  }

  // Đơn đã kết thúc: khóa, không còn nút thao tác
  Widget _buildClosedBadge(OrderModel order) {
    final completed = order.status == 'Completed';
    final color = completed ? Colors.green.shade700 : Colors.red.shade700;
    final label = completed ? 'Đã hoàn thành' : (order.cancelledBySeller ? 'Quán đã hủy' : 'Khách đã hủy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: completed ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: completed ? Colors.green.shade300 : Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Hộp thoại Seller chọn lý do hủy; trả về lý do hoặc null nếu bỏ qua
class _CancelReasonDialog extends StatefulWidget {
  final String orderCode;
  final String initialReason;

  const _CancelReasonDialog({required this.orderCode, required this.initialReason});

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  late String _reason = widget.initialReason;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Hủy đơn #${widget.orderCode}?',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Khách sẽ thấy lý do này. Đơn đã hủy không thể khôi phục.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          for (final reason in OrderPolicy.sellerCancelReasons)
            RadioListTile<String>(
              value: reason,
              groupValue: _reason,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(reason, style: const TextStyle(fontSize: 14)),
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Không hủy', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, _reason),
          child: const Text('Hủy đơn'),
        ),
      ],
    );
  }
}
