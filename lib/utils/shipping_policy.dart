import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Quy tắc tính phí giao hàng của quán.
///
/// Khi quán đã cài vị trí (Kênh Quản Trị → Vị Trí Quán & Giao Hàng):
/// - Chỉ giao trong bán kính quán cài (mặc định 7 km), đo theo đường chim bay.
/// - 3 km đầu: 15.000đ; mỗi km tiếp theo (làm tròn lên): +5.000đ. Tối đa 35.000đ ở 7 km.
/// - Đơn từ 100.000đ: miễn phí 3 km đầu (trừ 15.000đ), tức giao gần là freeship.
///
/// Khi quán chưa cài vị trí: tính theo giá trị đơn như trước đây, không giới hạn khoảng cách.
class ShippingPolicy {
  static const double defaultRadiusKm = 7;
  static const double baseDistanceKm = 3;
  static const int baseFee = 15000;
  static const int feePerExtraKm = 5000;
  static const int freeBaseThreshold = 100000;

  /// Khoảng cách đường chim bay (km) giữa hai điểm
  static double distanceKm(LatLng from, LatLng to) =>
      const Distance().as(LengthUnit.Meter, from, to) / 1000;

  /// Phí ship theo khoảng cách từ quán tới điểm giao
  static int feeByDistance({required double distanceKm, required int subtotal}) {
    if (subtotal <= 0) return 0;
    final extraKm = math.max(0, (distanceKm - baseDistanceKm).ceil());
    final fee = baseFee + extraKm * feePerExtraKm;
    return subtotal >= freeBaseThreshold ? fee - baseFee : fee;
  }

  /// Phí ship theo giá trị đơn (dùng khi quán chưa cài vị trí):
  /// dưới 50.000đ: 15.000đ; 50.000–100.000đ: 10.000đ; trên 100.000đ: miễn phí
  static int feeByOrderValue(int subtotal) {
    if (subtotal <= 0) return 0;
    if (subtotal < 50000) return 15000;
    if (subtotal <= 100000) return 10000;
    return 0;
  }

  /// "2,3 km"
  static String formatKm(double km) => '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}
