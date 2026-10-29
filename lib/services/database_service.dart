import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lấy danh sách sản phẩm theo thời gian thực (Realtime Stream) từ Firestore
  /// Đọc trực tiếp từ collection 'products' trên database của bạn
  Stream<List<ProductModel>> getProductsStream({String? category}) {
    return _firestore.collection('products').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

      // Lọc theo danh mục nếu người dùng chọn
      if (category != null && category != 'Tất cả') {
        return list
            .where((p) => p.category.toLowerCase() == category.toLowerCase())
            .toList();
      }

      return list;
    });
  }

  /// Lấy danh sách topping trực tiếp từ collection 'toppings' trên Firestore
  Stream<List<Map<String, dynamic>>> getToppingsStream() {
    return _firestore.collection('toppings').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Đảm bảo có giá trị price dù bạn đặt tên là 'price' hay 'gia'
        data['price'] = data['price'] ?? data['gia'] ?? 0;
        data['name'] = data['name'] ?? data['ten'] ?? 'Topping';
        return data;
      }).toList();
    });
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

  /// Cập nhật trạng thái đơn hàng (Pending -> Preparing -> Completed)
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Tạo đơn hàng mới trên Firestore khi khách thanh toán
  Future<DocumentReference> createOrder(Map<String, dynamic> orderData) async {
    return await _firestore.collection('orders').add(orderData);
  }

  /// Lấy danh sách đơn hàng của một khách hàng cụ thể theo thời gian thực
  Stream<List<OrderModel>> getCustomerOrdersStream(String userId) {
    return _firestore.collection('orders').snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) => order.userId == userId)
          .toList();

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
