import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapPickerResult {
  final String address;
  final double latitude;
  final double longitude;

  MapPickerResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  late LatLng _currentCenter;
  String _currentAddress = 'Đang xác định địa chỉ...';
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  // Danh sách kết quả gợi ý tìm kiếm
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color accentOrange = Color(0xFFD87D4A);

  @override
  void initState() {
    super.initState();
    _currentCenter = LatLng(
      widget.initialLat ?? 10.776889, // Mặc định TP.HCM / Hà Nội
      widget.initialLng ?? 106.700806,
    );
    _getAddressFromCoordinates(_currentCenter);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // Phân tích tọa độ ra địa chỉ chữ (Reverse Geocoding)
  Future<void> _getAddressFromCoordinates(LatLng point) async {
    setState(() => _isLoadingAddress = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'TiemTraNhoMilkTeaApp/1.0 (contact: tiemtranho@gmail.com)'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final displayName = data['display_name'];

        if (mounted) {
          setState(() {
            _currentAddress = displayName ??
                'Tọa độ: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
            _isLoadingAddress = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentAddress =
            'Vị trí: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        _isLoadingAddress = false;
      });
    }
  }

  // Tìm kiếm địa điểm theo từ khóa nhập vào
  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=vn&limit=5&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'TiemTraNhoMilkTeaApp/1.0 (contact: tiemtranho@gmail.com)'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List list = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _searchResults = list.map((item) => Map<String, dynamic>.from(item)).toList();
            _isSearching = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  // Khi chọn 1 địa điểm từ danh sách gợi ý tìm kiếm
  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat'].toString());
    final lon = double.tryParse(item['lon'].toString());

    if (lat != null && lon != null) {
      final newCenter = LatLng(lat, lon);
      setState(() {
        _currentCenter = newCenter;
        _currentAddress = item['display_name'] ?? '';
        _showSearchResults = false;
        _searchController.text = item['display_name'] ?? '';
      });
      _mapController.move(newCenter, 16.5);
      FocusScope.of(context).unfocus();
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _currentCenter = camera.center;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        _getAddressFromCoordinates(_currentCenter);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ghim Vị Trí Nhận Hàng',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Bản đồ OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.5,
              maxZoom: 18.0,
              minZoom: 5.0,
              onPositionChanged: _onPositionChanged,
              onTap: (tapPosition, point) {
                // Cho phép chạm vào map để di chuyển ghim
                setState(() => _currentCenter = point);
                _mapController.move(point, _mapController.camera.zoom);
                _getAddressFromCoordinates(point);
                setState(() => _showSearchResults = false);
                FocusScope.of(context).unfocus();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.projectgroup_milktea',
              ),
            ],
          ),

          // Ghim cố định ở chính giữa tâm bản đồ
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryBrown,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_cafe_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Giao trà sữa tới đây',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.location_pin,
                    size: 46,
                    color: accentOrange,
                  ),
                ],
              ),
            ),
          ),

          // Thanh tìm kiếm địa chỉ thông minh trên đầu map
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm địa chỉ, tên đường, tòa nhà...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, color: primaryBrown),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _showSearchResults = false;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    ),
                    onSubmitted: (value) => _searchPlace(value),
                    onChanged: (value) {
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                        _searchPlace(value);
                      });
                    },
                  ),
                ),

                // Danh sách kết quả tìm kiếm thả xuống
                if (_showSearchResults)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: primaryBrown),
                              ),
                            ),
                          )
                        : _searchResults.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Không tìm thấy địa điểm phù hợp.',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = _searchResults[index];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.location_on_outlined, color: accentOrange, size: 20),
                                    title: Text(
                                      item['display_name'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                    onTap: () => _selectSearchResult(item),
                                  );
                                },
                              ),
                  ),
              ],
            ),
          ),

          // Hộp thông tin địa chỉ và nút Xác nhận ở phía dưới
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: accentOrange, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Vị trí đã chọn trên bản đồ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryBrown,
                          ),
                        ),
                      ),
                      if (_isLoadingAddress)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primaryBrown),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentAddress,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text(
                        'Xác Nhận Vị Trí Này',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBrown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          MapPickerResult(
                            address: _currentAddress,
                            latitude: _currentCenter.latitude,
                            longitude: _currentCenter.longitude,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
