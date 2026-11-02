// Unit test cho quy tắc phí ship và tìm kiếm không dấu (không cần Firebase)

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:projectgroup_milktea/utils/shipping_policy.dart';
import 'package:projectgroup_milktea/utils/text_utils.dart';

void main() {
  group('ShippingPolicy.feeByDistance', () {
    test('đơn dưới 50.000đ: 10.000đ trong 3 km, 15.000đ xa hơn', () {
      expect(ShippingPolicy.feeByDistance(distanceKm: 2, subtotal: 45000), 10000);
      expect(ShippingPolicy.feeByDistance(distanceKm: 3.0, subtotal: 45000), 10000);
      expect(ShippingPolicy.feeByDistance(distanceKm: 3.1, subtotal: 45000), 15000);
      expect(ShippingPolicy.feeByDistance(distanceKm: 12, subtotal: 49999), 15000);
    });

    test('đơn 50.000đ – dưới 150.000đ: freeship trong 3 km, 5.000đ xa hơn', () {
      expect(ShippingPolicy.feeByDistance(distanceKm: 2, subtotal: 50000), 0);
      expect(ShippingPolicy.feeByDistance(distanceKm: 2, subtotal: 80000), 0);
      expect(ShippingPolicy.feeByDistance(distanceKm: 8, subtotal: 120000), 5000);
      expect(ShippingPolicy.feeByDistance(distanceKm: 8, subtotal: 149999), 5000);
    });

    test('đơn từ 150.000đ: freeship mọi khoảng cách', () {
      expect(ShippingPolicy.feeByDistance(distanceKm: 1, subtotal: 150000), 0);
      expect(ShippingPolicy.feeByDistance(distanceKm: 12, subtotal: 160000), 0);
    });

    test('giỏ trống thì không tính phí', () {
      expect(ShippingPolicy.feeByDistance(distanceKm: 5, subtotal: 0), 0);
    });
  });

  group('ShippingPolicy.feeByOrderValue (khi quán chưa cài vị trí)', () {
    test('giữ đúng quy tắc cũ', () {
      expect(ShippingPolicy.feeByOrderValue(0), 0);
      expect(ShippingPolicy.feeByOrderValue(45000), 15000);
      expect(ShippingPolicy.feeByOrderValue(80000), 10000);
      expect(ShippingPolicy.feeByOrderValue(150000), 0);
    });
  });

  test('distanceKm: Nhà thờ Đức Bà → Chợ Bến Thành khoảng 1 km', () {
    const notreDame = LatLng(10.779783, 106.699018);
    const benThanh = LatLng(10.772450, 106.698060);
    final km = ShippingPolicy.distanceKm(notreDame, benThanh);
    expect(km, greaterThan(0.7));
    expect(km, lessThan(1.0));
  });

  test('formatKm dùng dấu phẩy thập phân', () {
    expect(ShippingPolicy.formatKm(2.345), '2,3 km');
  });

  group('joinAddress', () {
    test('ghép chi tiết khách ghi với địa chỉ theo vị trí ghim', () {
      expect(joinAddress(' Số 12,  hẻm 45 ', '123 Lê Lợi, Q.1'), 'Số 12, hẻm 45 – 123 Lê Lợi, Q.1');
    });

    test('không có chi tiết thì chỉ còn địa chỉ bản đồ', () {
      expect(joinAddress('', '123 Lê Lợi, Q.1'), '123 Lê Lợi, Q.1');
      expect(joinAddress(null, '123 Lê Lợi, Q.1'), '123 Lê Lợi, Q.1');
    });
  });

  group('normalizeForSearch', () {
    test('bỏ dấu, chữ thường, gom khoảng trắng', () {
      expect(normalizeForSearch('  Trà Sữa   Đào '), 'tra sua dao');
      expect(normalizeForSearch('Ô LONG Kem Cheese'), 'o long kem cheese');
    });

    test('gõ không dấu vẫn tìm ra món có dấu', () {
      expect(normalizeForSearch('Trà sữa trân châu đường đen').contains(normalizeForSearch('tran chau')), isTrue);
      expect(normalizeForSearch('Hồng trà').contains(normalizeForSearch('HONG TRA')), isTrue);
    });

    test('xử lý cả chữ có dấu dạng tổ hợp (NFD)', () {
      // "trà" viết bằng "a" + dấu huyền rời (U+0300)
      expect(normalizeForSearch('trà'), 'tra');
    });
  });
}
