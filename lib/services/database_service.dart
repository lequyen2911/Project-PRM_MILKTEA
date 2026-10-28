import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

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
}
