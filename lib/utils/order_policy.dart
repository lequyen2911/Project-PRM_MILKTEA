import '../models/order_model.dart';

/// Quy tắc xử lý đơn của Seller (phương án "khóa theo trạng thái + thời hạn").
///
/// - Đơn 'Completed' và 'Cancelled' là kết thúc: khóa hẳn.
/// - Đơn 'Pending' quá [pendingTimeout] kể từ lúc đặt: quá hạn, chỉ được hủy.
/// - Đơn 'Preparing' quá [preparingTimeout] kể từ lúc quán nhận đơn: quá hạn,
///   được hoàn thành hoặc hủy để đóng đơn.
///
/// firestore.rules kiểm tra lại đúng các mốc này bằng giờ server.
class OrderPolicy {
  static const pendingTimeout = Duration(minutes: 30);
  static const preparingTimeout = Duration(hours: 2);

  /// Lý do hủy Seller chọn, hiển thị lại cho khách
  static const sellerCancelReasons = [
    'Hết nguyên liệu',
    'Quán quá tải, không kịp làm',
    'Không liên hệ được khách',
    'Quá hạn xử lý',
  ];

  static bool isClosed(OrderModel order) => order.status == 'Completed' || order.status == 'Cancelled';

  /// Mốc bắt đầu tính hạn: lúc đặt (Pending) hoặc lúc quán nhận đơn (Preparing)
  static DateTime? _deadlineStart(OrderModel order) {
    if (order.status == 'Preparing') return order.acceptedAt ?? order.createdAt;
    return order.createdAt;
  }

  /// Hạn xử lý của đơn đang mở, null nếu đơn đã đóng hoặc chưa có giờ tạo
  static DateTime? deadline(OrderModel order) {
    final start = _deadlineStart(order);
    if (start == null) return null;
    switch (order.status) {
      case 'Pending':
        return start.add(pendingTimeout);
      case 'Preparing':
        return start.add(preparingTimeout);
      default:
        return null;
    }
  }

  static bool isOverdue(OrderModel order, DateTime now) {
    final d = deadline(order);
    return d != null && now.isAfter(d);
  }

  /// Các trạng thái Seller được chuyển tới từ trạng thái hiện tại
  static List<String> sellerNextStatuses(OrderModel order, DateTime now) {
    final overdue = isOverdue(order, now);
    switch (order.status) {
      case 'Pending':
        return overdue ? const ['Cancelled'] : const ['Preparing', 'Cancelled'];
      case 'Preparing':
        return overdue ? const ['Completed', 'Cancelled'] : const ['Completed'];
      default:
        return const [];
    }
  }

  /// Ngày theo giờ Việt Nam (UTC+7), không phụ thuộc múi giờ của máy
  static DateTime _vnDay(DateTime t) {
    final vn = t.toUtc().add(const Duration(hours: 7));
    return DateTime.utc(vn.year, vn.month, vn.day);
  }

  static bool isSameVnDay(DateTime? a, DateTime b) => a != null && _vnDay(a) == _vnDay(b);

  /// Tab "Hôm nay": đơn đặt hôm nay + mọi đơn còn mở của các ngày trước.
  /// Đơn chưa có giờ tạo (vừa gửi, server chưa ghi giờ) cũng nằm ở đây.
  static bool belongsToToday(OrderModel order, DateTime now) =>
      !isClosed(order) || order.createdAt == null || isSameVnDay(order.createdAt, now);
}
