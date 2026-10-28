import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final int basePrice;
  final String category;
  final String imageUrl;
  final bool isAvailable;
  final String? description;
  final DateTime? createdAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.category,
    required this.imageUrl,
    this.isAvailable = true,
    this.description,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'basePrice': basePrice,
      'category': category,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'description': description ?? '',
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? created;
    if (map['createdAt'] != null && map['createdAt'] is Timestamp) {
      created = (map['createdAt'] as Timestamp).toDate();
    }

    // Tự động nhận diện linh hoạt các tên trường khác nhau mà bạn có thể đã đặt trên Firestore
    final name = map['name'] ?? map['productName'] ?? map['ten'] ?? map['title'] ?? 'Món chưa đặt tên';

    // Nhận cả basePrice, price, gia dù là int, double hay string
    int price = 0;
    final rawPrice = map['basePrice'] ?? map['price'] ?? map['gia'];
    if (rawPrice is num) {
      price = rawPrice.toInt();
    } else if (rawPrice != null) {
      price = int.tryParse(rawPrice.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final category = map['category'] ?? map['categoryName'] ?? map['loai'] ?? 'Trà sữa';
    final imageUrl = map['imageUrl'] ?? map['image'] ?? map['img'] ?? map['hinhAnh'] ?? '';
    
    // Mặc định luôn là true nếu trên Firestore chưa set trường này
    final rawAvailable = map['isAvailable'] ?? map['available'] ?? map['conHang'];
    final bool isAvailable = rawAvailable == null
        ? true
        : (rawAvailable == true || rawAvailable.toString().toLowerCase() == 'true');

    final description = map['description'] ?? map['desc'] ?? map['moTa'] ?? '';

    return ProductModel(
      id: id,
      name: name.toString(),
      basePrice: price,
      category: category.toString(),
      imageUrl: imageUrl.toString(),
      isAvailable: isAvailable,
      description: description.toString(),
      createdAt: created,
    );
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProductModel.fromMap(data, id: doc.id);
  }

  // Định dạng hiển thị tiền Việt Nam Đồng (vd: 30.000 đ)
  String get formattedPrice {
    final priceStr = basePrice.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = priceStr.length - 1; i >= 0; i--) {
      buffer.write(priceStr[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join()} đ';
  }
}
