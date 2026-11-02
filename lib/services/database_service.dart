import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/store_settings_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ảnh món lưu trên Cloudinary (gói Free) vì Firebase Storage cần gói Blaze.
  // Preset "unsigned" cho phép upload từ app mà không cần API secret.
  static const String _cloudinaryCloudName = 'aylnzjwi';
  static const String _cloudinaryUploadPreset = 'milktea_unsigned';

  /// Lấy danh sách sản phẩm theo thời gian thực (Realtime Stream) từ Firestore
  /// Nếu [onlyActive] là true, chỉ trả về các sản phẩm đang bật hiển thị (isActive == true) cho khách hàng.
  Stream<List<ProductModel>> getProductsStream({String? category, bool onlyActive = false}) {
    return _firestore.collection('products').snapshots().map((snapshot) {
      var list = snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

      if (onlyActive) {
        list = list.where((p) => p.isActive).toList();
      }

      // Lọc theo danh mục nếu người dùng chọn
      if (category != null && category != 'Tất cả') {
        list = list
            .where((p) => p.category.toLowerCase() == category.toLowerCase())
            .toList();
      }

      return list;
    });
  }

  /// Tải ảnh sản phẩm / topping lên Cloudinary và trả về URL https của ảnh
  Future<String> uploadProductImage(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload'),
      )
        ..fields['upload_preset'] = _cloudinaryUploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 60)),
      );
      final data = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(data['error']?['message'] ?? 'HTTP ${response.statusCode}');
      }
      return data['secure_url'] as String;
    } catch (e) {
      throw Exception('Tải ảnh lên thất bại: $e');
    }
  }

  static Map<String, dynamic> _toppingFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    data['id'] = doc.id;
    // Đảm bảo có giá trị price dù bạn đặt tên là 'price' hay 'gia'
    data['price'] = data['price'] ?? data['gia'] ?? 0;
    data['name'] = data['name'] ?? data['ten'] ?? 'Topping';
    return data;
  }

  /// Topping còn hàng? Dữ liệu cũ không có trường isAvailable / available thì coi là còn hàng
  static bool isToppingAvailable(Map<String, dynamic> topping) {
    final raw = topping['isAvailable'] ?? topping['available'];
    return raw == null || raw == true;
  }

  /// Lấy danh sách topping trực tiếp từ collection 'toppings' trên Firestore
  Stream<List<Map<String, dynamic>>> getToppingsStream() {
    return _firestore.collection('toppings').snapshots().map(
          (snapshot) => snapshot.docs.map(_toppingFromDoc).toList(),
        );
  }

  /// Đọc topping 1 lần từ server (dùng khi đặt hàng để kiểm tra còn hàng và giá mới nhất)
  Future<Map<String, Map<String, dynamic>>> getToppingsById() async {
    final snapshot = await _firestore.collection('toppings').get();
    return {for (final doc in snapshot.docs) doc.id: _toppingFromDoc(doc)};
  }

  /// Lấy chi tiết 1 sản phẩm theo ID từ Firestore
  Future<ProductModel?> getProductById(String id) async {
    try {
      final doc = await _firestore.collection('products').doc(id).get();
      if (doc.exists) {
        return ProductModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Thêm món mới vào Firestore
  Future<void> addProduct(Map<String, dynamic> productData) async {
    await _firestore.collection('products').add(productData);
  }

  /// Cập nhật thông tin món ăn trên Firestore
  Future<void> updateProduct(String id, Map<String, dynamic> productData) async {
    await _firestore.collection('products').doc(id).update(productData);
  }

  /// Cập nhật trạng thái còn hàng/hết hàng (isAvailable) của món ăn
  Future<void> updateProductAvailability(String id, bool isAvailable) async {
    await _firestore.collection('products').doc(id).update({
      'isAvailable': isAvailable,
    });
  }

  /// Cập nhật trạng thái hiển thị/ẩn (isActive) của món ăn
  Future<void> updateProductActiveStatus(String id, bool isActive) async {
    await _firestore.collection('products').doc(id).update({
      'isActive': isActive,
    });
  }

  /// Thêm Topping mới vào Firestore
  Future<void> addTopping(Map<String, dynamic> toppingData) async {
    await _firestore.collection('toppings').add(toppingData);
  }

  /// Cập nhật thông tin Topping trên Firestore
  Future<void> updateTopping(String id, Map<String, dynamic> toppingData) async {
    await _firestore.collection('toppings').doc(id).update(toppingData);
  }

  /// Cập nhật trạng thái còn hàng/hết hàng (isAvailable) của Topping
  Future<void> updateToppingAvailability(String id, bool isAvailable) async {
    await _firestore.collection('toppings').doc(id).update({
      'isAvailable': isAvailable,
    });
  }

  /// Xóa món đồ uống theo ID khỏi Firestore
  Future<void> deleteProduct(String id) async {
    await _firestore.collection('products').doc(id).delete();
  }

  /// Xóa Topping theo ID khỏi Firestore
  Future<void> deleteTopping(String id) async {
    await _firestore.collection('toppings').doc(id).delete();
  }

  /// Lấy danh sách đơn hàng theo thời gian thực (Realtime Stream) từ Firestore
  /// Tự động sắp xếp đơn mới nhất lên đầu
  Stream<List<OrderModel>> getOrdersStream() {
    return _firestore.collection('orders').snapshots().map((snapshot) {
      final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      
      // Sắp xếp đơn mới nhất lên đầu (Client-side sorting để đảm bảo luôn chạy mượt kể cả khi chưa có composite index)
      orders.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return orders;
    });
  }

  /// Cập nhật trạng thái đơn hàng (Pending -> Preparing -> Completed).
  /// Quy tắc được phép chuyển nằm ở OrderPolicy; firestore.rules kiểm tra lại bằng giờ server.
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      // Mốc tính hạn "đang pha" (OrderPolicy.preparingTimeout)
      if (newStatus == 'Preparing') 'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Seller hủy đơn kèm lý do (khách thấy lý do trong lịch sử đơn)
  Future<void> sellerCancelOrder(String orderId, String reason) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'Cancelled',
      'cancelledBy': 'seller',
      'cancelReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  DocumentReference<Map<String, dynamic>> get _storeSettingsRef =>
      _firestore.collection('settings').doc('store');

  /// Cài đặt quán (vị trí, bán kính giao) theo thời gian thực; null nếu quán chưa cài
  Stream<StoreSettings?> getStoreSettingsStream() {
    return _storeSettingsRef.snapshots().map((doc) => StoreSettings.fromMap(doc.data()));
  }

  /// Seller lưu vị trí quán và bán kính giao hàng
  Future<void> saveStoreSettings(StoreSettings settings) async {
    await _storeSettingsRef.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Khách hủy đơn của mình. firestore.rules chỉ cho hủy khi đơn còn 'Pending',
  /// nên nếu quán vừa xác nhận đơn thì lệnh này bị từ chối (permission-denied).
  Future<void> cancelOrder(String orderId) async {
    // Không ghi cancelledBy: đơn hủy không có trường này được hiểu là khách hủy
    // (OrderModel.cancelledBySeller, firestore.rules mặc định 'customer'),
    // nên lệnh hủy chạy được cả khi Firebase còn rules bản cũ.
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'Cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Tạo đơn hàng mới trên Firestore khi khách thanh toán
  Future<DocumentReference> createOrder(Map<String, dynamic> orderData) async {
    return await _firestore.collection('orders').add(orderData);
  }

  /// Lấy danh sách đơn hàng của một khách hàng cụ thể theo thời gian thực
  Stream<List<OrderModel>> getCustomerOrdersStream(String userId) {
    // Lọc trên server: chỉ tải đơn của chính khách này, không tải đơn (tên, SĐT, địa chỉ) của người khác
    return _firestore.collection('orders').where('userId', isEqualTo: userId).snapshots().map((snapshot) {
      final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();

      orders.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return orders;
    });
  }
}
