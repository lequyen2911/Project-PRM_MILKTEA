// Unit test cho quy tắc xử lý đơn của Seller (không cần Firebase)

import 'package:flutter_test/flutter_test.dart';
import 'package:projectgroup_milktea/models/order_model.dart';
import 'package:projectgroup_milktea/utils/order_policy.dart';

OrderModel _order(String status, {DateTime? createdAt, DateTime? acceptedAt}) => OrderModel(
      id: 'o1',
      orderCode: 'TS1',
      userId: 'u1',
      customerName: 'Khách',
      customerEmail: '',
      items: const [],
      totalAmount: 50000,
      status: status,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
    );

void main() {
  // 10:00 ngày 02/11/2026 giờ Việt Nam
  final now = DateTime.utc(2026, 11, 2, 3);

  group('Pending', () {
    test('trong 30 phút: được xác nhận hoặc hủy', () {
      final o = _order('Pending', createdAt: now.subtract(const Duration(minutes: 29)));
      expect(OrderPolicy.isOverdue(o, now), isFalse);
      expect(OrderPolicy.sellerNextStatuses(o, now), ['Preparing', 'Cancelled']);
    });

    test('quá 30 phút: quá hạn, chỉ được hủy', () {
      final o = _order('Pending', createdAt: now.subtract(const Duration(minutes: 31)));
      expect(OrderPolicy.isOverdue(o, now), isTrue);
      expect(OrderPolicy.sellerNextStatuses(o, now), ['Cancelled']);
    });
  });

  group('Preparing', () {
    test('tính hạn 2 giờ từ lúc quán nhận đơn, không phải lúc đặt', () {
      final o = _order(
        'Preparing',
        createdAt: now.subtract(const Duration(hours: 3)),
        acceptedAt: now.subtract(const Duration(hours: 1)),
      );
      expect(OrderPolicy.isOverdue(o, now), isFalse);
      expect(OrderPolicy.sellerNextStatuses(o, now), ['Completed']);
    });

    test('quá 2 giờ: được hoàn thành hoặc hủy để đóng đơn', () {
      final o = _order('Preparing', acceptedAt: now.subtract(const Duration(hours: 2, minutes: 1)));
      expect(OrderPolicy.isOverdue(o, now), isTrue);
      expect(OrderPolicy.sellerNextStatuses(o, now), ['Completed', 'Cancelled']);
    });

    test('đơn cũ chưa có acceptedAt thì tính từ lúc đặt', () {
      final o = _order('Preparing', createdAt: now.subtract(const Duration(hours: 5)));
      expect(OrderPolicy.isOverdue(o, now), isTrue);
    });
  });

  test('đơn Completed / Cancelled khóa hẳn, không quá hạn', () {
    final old = now.subtract(const Duration(days: 3));
    for (final status in ['Completed', 'Cancelled']) {
      final o = _order(status, createdAt: old);
      expect(OrderPolicy.isClosed(o), isTrue);
      expect(OrderPolicy.isOverdue(o, now), isFalse);
      expect(OrderPolicy.sellerNextStatuses(o, now), isEmpty);
    }
  });

  group('Tab Hôm nay / Lịch sử (theo giờ Việt Nam)', () {
    final yesterday = now.subtract(const Duration(days: 1));

    test('đơn đã xong hôm qua → Lịch sử', () {
      expect(OrderPolicy.belongsToToday(_order('Completed', createdAt: yesterday), now), isFalse);
    });

    test('đơn còn dở hôm qua vẫn ở Hôm nay', () {
      expect(OrderPolicy.belongsToToday(_order('Preparing', createdAt: yesterday), now), isTrue);
    });

    test('đơn đặt lúc 23:55 hôm qua (giờ VN) đã xong → Lịch sử, dù UTC vẫn là "hôm nay"', () {
      // 23:55 ngày 01/11 giờ VN = 16:55 UTC ngày 01/11; now = 03:00 UTC ngày 02/11
      final lateNight = DateTime.utc(2026, 11, 1, 16, 55);
      expect(OrderPolicy.isSameVnDay(lateNight, now), isFalse);
      expect(OrderPolicy.belongsToToday(_order('Completed', createdAt: lateNight), now), isFalse);
    });

    test('đơn 00:10 sáng nay (giờ VN) là hôm nay', () {
      final earlyMorning = DateTime.utc(2026, 11, 1, 17, 10);
      expect(OrderPolicy.isSameVnDay(earlyMorning, now), isTrue);
    });
  });
}
