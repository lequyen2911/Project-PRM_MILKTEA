import 'package:latlong2/latlong.dart';

/// Quy tắc tính phí giao hàng của quán.
///
/// Khi quán đã cài vị trí (Kênh Quản Trị → Vị Trí Quán & Giao Hàng), phí theo bảng
/// 2 mức khoảng cách × 3 mức giá trị đơn (đo đường chim bay, chỉ giao trong bán kính quán cài):
///
/// | Giá trị đơn         | Gần (≤ 3 km) | Xa (> 3 km) |
/// |---------------------|--------------|-------------|
/// | Dưới 50.000đ        | 10.000đ      | 15.000đ     |
/// | 50.000 – <150.000đ  | Freeship     | 5.000đ      |
/// | Từ 150.000đ         | Freeship     | Freeship    |
///
/// Khi quán chưa cài vị trí: tính theo giá trị đơn như trước đây, không giới hạn khoảng cách.
class ShippingPolicy {
  static const double defaultRadiusKm = 7;
  static const double nearDistanceKm = 3; // đúng 3,0 km vẫn tính là gần

  static const int smallOrderThreshold = 50000; // đúng 50.000đ tính vào mức trên
  static const int freeShipThreshold = 150000;

  static const int smallOrderNearFee = 10000;
  static const int smallOrderFarFee = 15000;
  static const int mediumOrderFarFee = 5000;

  /// Các dòng mô tả quy tắc, hiển thị cho Seller trong màn Vị trí quán
  static const rulesDescription = [
    'Đơn dưới 50.000đ: 10.000đ trong 3 km, 15.000đ xa hơn 3 km',
    'Đơn từ 50.000đ đến dưới 150.000đ: freeship trong 3 km, 5.000đ xa hơn 3 km',
    'Đơn từ 150.000đ: freeship mọi khoảng cách',
    'Ngoài bán kính giao hàng: khách không đặt được',
    'Khoảng cách đo theo đường chim bay từ quán tới vị trí khách ghim',
  ];

  /// Khoảng cách đường chim bay (km) giữa hai điểm
  static double distanceKm(LatLng from, LatLng to) =>
      const Distance().as(LengthUnit.Meter, from, to) / 1000;

  /// Phí ship theo khoảng cách từ quán tới điểm giao và giá trị đơn
  static int feeByDistance({required double distanceKm, required int subtotal}) {
    if (subtotal <= 0 || subtotal >= freeShipThreshold) return 0;
    final isNear = distanceKm <= nearDistanceKm;
    if (subtotal < smallOrderThreshold) return isNear ? smallOrderNearFee : smallOrderFarFee;
    return isNear ? 0 : mediumOrderFarFee;
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
