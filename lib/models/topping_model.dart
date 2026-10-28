import 'package:cloud_firestore/cloud_firestore.dart';

class ToppingModel {
  final String id;
  final String name;
  final int price;
  final String imageUrl;
  final bool isAvailable;
  final String description;

  ToppingModel({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.isAvailable = true,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ToppingModel.fromMap(Map<String, dynamic> map, {required String id}) {
    final name = map['name'] ?? map['ten'] ?? 'Topping';

    int price = 0;
    final rawPrice = map['price'] ?? map['basePrice'] ?? map['gia'];
    if (rawPrice is num) {
      price = rawPrice.toInt();
    } else if (rawPrice != null) {
      price = int.tryParse(rawPrice.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final imageUrl = map['imageUrl'] ?? map['image'] ?? map['img'] ?? '';
    final rawAvailable = map['isAvailable'] ?? map['available'] ?? map['conHang'];
    final bool isAvailable = rawAvailable == null
        ? true
        : (rawAvailable == true || rawAvailable.toString().toLowerCase() == 'true');
    final description = map['description'] ?? map['desc'] ?? map['moTa'] ?? '';

    return ToppingModel(
      id: id,
      name: name.toString(),
      price: price,
      imageUrl: imageUrl.toString(),
      isAvailable: isAvailable,
      description: description.toString(),
    );
  }

  factory ToppingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ToppingModel.fromMap(data, id: doc.id);
  }

  String get formattedPrice {
    final priceStr = price.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = priceStr.length - 1; i >= 0; i--) {
      buffer.write(priceStr[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return '+${buffer.toString().split('').reversed.join()} đ';
  }
}
