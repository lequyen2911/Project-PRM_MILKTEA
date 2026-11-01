import 'package:latlong2/latlong.dart';
import '../utils/shipping_policy.dart';

/// Cài đặt của quán, lưu ở Firestore: settings/store
class StoreSettings {
  final double latitude;
  final double longitude;
  final String address;
  final double deliveryRadiusKm;

  const StoreSettings({
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.deliveryRadiusKm = ShippingPolicy.defaultRadiusKm,
  });

  LatLng get location => LatLng(latitude, longitude);

  /// Trả về null nếu quán chưa cài tọa độ
  static StoreSettings? fromMap(Map<String, dynamic>? map) {
    final lat = map?['latitude'];
    final lng = map?['longitude'];
    if (lat is! num || lng is! num) return null;

    final radius = map?['deliveryRadiusKm'];
    return StoreSettings(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      address: (map?['address'] ?? '').toString(),
      deliveryRadiusKm: radius is num && radius > 0 ? radius.toDouble() : ShippingPolicy.defaultRadiusKm,
    );
  }

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'deliveryRadiusKm': deliveryRadiusKm,
      };
}
