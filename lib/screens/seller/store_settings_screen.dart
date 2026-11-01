import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/store_settings_model.dart';
import '../../services/database_service.dart';
import '../../utils/shipping_policy.dart';
import '../customer/map_picker_screen.dart';

/// Seller cài vị trí quán và bán kính giao hàng. Giỏ hàng của khách dùng để tính phí ship theo km.
class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _coordinatesController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _radiusController =
      TextEditingController(text: ShippingPolicy.defaultRadiusKm.toStringAsFixed(0));

  bool _isLoading = true;
  bool _isSaving = false;

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color accentOrange = Color(0xFFD87D4A);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _coordinatesController.dispose();
    _addressController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _dbService.getStoreSettingsStream().first;
      if (settings != null) {
        _coordinatesController.text = _formatCoordinates(settings.latitude, settings.longitude);
        _addressController.text = settings.address;
        _radiusController.text = _formatNumber(settings.deliveryRadiusKm);
      }
    } catch (_) {
      // Chưa đọc được (vd: mất mạng): để trống cho Seller nhập mới
    }
    if (mounted) setState(() => _isLoading = false);
  }

  static String _formatCoordinates(double lat, double lng) =>
      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

  /// Đọc "10.776889, 106.700806" (định dạng Google Maps khi nhấn giữ một điểm và sao chép tọa độ)
  static ({double lat, double lng})? _parseCoordinates(String input) {
    final parts = input.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) return null;
    return (lat: lat, lng: lng);
  }

  Future<void> _pickOnMap() async {
    final current = _parseCoordinates(_coordinatesController.text);
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: current?.lat,
          initialLng: current?.lng,
          title: 'Chọn Vị Trí Quán',
          pinLabel: 'Quán ở đây',
          confirmLabel: 'Đặt Làm Vị Trí Quán',
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _coordinatesController.text = _formatCoordinates(result.latitude, result.longitude);
      _addressController.text = result.address;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final coordinates = _parseCoordinates(_coordinatesController.text)!;

    setState(() => _isSaving = true);
    try {
      await _dbService.saveStoreSettings(StoreSettings(
        latitude: coordinates.lat,
        longitude: coordinates.lng,
        address: _addressController.text.trim(),
        deliveryRadiusKm: double.parse(_radiusController.text.trim().replaceAll(',', '.')),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('✅ Đã lưu vị trí quán và bán kính giao hàng.'), backgroundColor: Colors.green.shade700),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lưu thất bại: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      appBar: AppBar(
        title: const Text('Vị Trí Quán & Giao Hàng'),
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBrown))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Vị trí quán dùng để tính khoảng cách tới khách, phí giao hàng và chặn đơn ngoài vùng giao.',
                      style: TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Tọa độ: dán từ Google Maps hoặc chọn trên bản đồ
                    TextFormField(
                      controller: _coordinatesController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Tọa độ quán (vĩ độ, kinh độ) *',
                        hintText: 'VD: 10.776889, 106.700806',
                        helperText: 'Trên Google Maps: nhấn giữ vị trí quán rồi chép dãy số tọa độ',
                        helperMaxLines: 2,
                        prefixIcon: Icon(Icons.my_location, color: primaryBrown),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _parseCoordinates(value ?? '') == null
                          ? 'Nhập đúng dạng "vĩ độ, kinh độ", VD: 10.776889, 106.700806'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBrown,
                        side: const BorderSide(color: primaryBrown),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _pickOnMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Chọn trên bản đồ'),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ quán',
                        hintText: 'Tự điền khi chọn trên bản đồ, có thể sửa lại',
                        prefixIcon: Icon(Icons.storefront_outlined, color: primaryBrown),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _radiusController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(
                        labelText: 'Bán kính giao hàng (km) *',
                        hintText: 'VD: 7',
                        prefixIcon: Icon(Icons.radar, color: primaryBrown),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final km = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                        if (km == null || km <= 0 || km > 50) {
                          return 'Nhập số km từ 0 đến 50';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildFeeRulesCard(),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBrown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Lưu Cài Đặt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Giải thích cách tính phí ship cho Seller (theo ShippingPolicy)
  Widget _buildFeeRulesCard() {
    String vnd(int amount) => '${(amount ~/ 1000)}.000đ';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: accentOrange, size: 20),
              SizedBox(width: 8),
              Text('Cách tính phí giao hàng', style: TextStyle(fontWeight: FontWeight.bold, color: primaryBrown)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• ${_formatNumber(ShippingPolicy.baseDistanceKm)} km đầu: ${vnd(ShippingPolicy.baseFee)}\n'
            '• Mỗi km tiếp theo (làm tròn lên): +${vnd(ShippingPolicy.feePerExtraKm)}\n'
            '• Đơn từ ${vnd(ShippingPolicy.freeBaseThreshold)}: miễn phí ${_formatNumber(ShippingPolicy.baseDistanceKm)} km đầu\n'
            '• Ngoài bán kính giao hàng: khách không đặt được\n'
            '• Khoảng cách đo theo đường chim bay từ quán tới vị trí khách ghim',
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}
