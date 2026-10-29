import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItemModel {
  final String productName;
  final int quantity;
  final String size;
  final String sugar;
  final String ice;
  final List<String> toppings;
  final int price;

  OrderItemModel({
    required this.productName,
    required this.quantity,
    this.size = 'M',
    this.sugar = '100%',
    this.ice = '100%',
    this.toppings = const [],
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'quantity': quantity,
      'size': size,
      'sugar': sugar,
      'ice': ice,
      'toppings': toppings,
      'price': price,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    final name = map['productName'] ?? map['name'] ?? map['tenMon'] ?? map['title'] ?? 'Đồ uống';
    
    int qty = 1;
    final rawQty = map['quantity'] ?? map['soLuong'] ?? map['count'];
    if (rawQty is num) {
      qty = rawQty.toInt();
    } else if (rawQty != null) {
      qty = int.tryParse(rawQty.toString()) ?? 1;
    }

    final size = map['size'] ?? map['kichThuoc'] ?? 'M';
    final sugar = map['sugar'] ?? map['luongDuong'] ?? map['duong'] ?? '100%';
    final ice = map['ice'] ?? map['luongDa'] ?? map['da'] ?? '100%';

    int itemPrice = 0;
    final rawPrice = map['price'] ?? map['unitPrice'] ?? map['gia'];
    if (rawPrice is num) {
      itemPrice = rawPrice.toInt();
    } else if (rawPrice != null) {
      itemPrice = int.tryParse(rawPrice.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    List<String> toppingList = [];
    final rawToppings = map['toppings'] ?? map['danhSachTopping'] ?? map['toppingNames'];
    if (rawToppings is List) {
      for (var t in rawToppings) {
        if (t is String) {
          toppingList.add(t);
        } else if (t is Map) {
          final tName = t['name'] ?? t['ten'] ?? t.toString();
          toppingList.add(tName.toString());
        }
      }
    }

    return OrderItemModel(
      productName: name.toString(),
      quantity: qty,
      size: size.toString(),
      sugar: sugar.toString(),
      ice: ice.toString(),
      toppings: toppingList,
      price: itemPrice,
    );
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
    return '${buffer.toString().split('').reversed.join()} đ';
  }
}

class OrderModel {
  final String id;
  final String orderCode;
  final String userId;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final List<OrderItemModel> items;
  final int totalAmount;
  final String status; // 'Pending', 'Preparing', 'Completed', ...
  final DateTime? createdAt;

  OrderModel({
    required this.id,
    required this.orderCode,
    required this.userId,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderCode': orderCode,
      'userId': userId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'items': items.map((x) => x.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? created;
    if (map['createdAt'] != null && map['createdAt'] is Timestamp) {
      created = (map['createdAt'] as Timestamp).toDate();
    } else if (map['orderDate'] != null && map['orderDate'] is Timestamp) {
      created = (map['orderDate'] as Timestamp).toDate();
    } else if (map['timestamp'] != null && map['timestamp'] is Timestamp) {
      created = (map['timestamp'] as Timestamp).toDate();
    }

    final code = map['orderCode'] ?? map['code'] ?? map['maDon'] ?? id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase();
    final uid = map['userId'] ?? map['uid'] ?? map['customerId'] ?? '';
    final name = map['customerName'] ?? map['userName'] ?? map['name'] ?? map['tenKhachHang'] ?? 'Khách hàng';
    final email = map['customerEmail'] ?? map['email'] ?? '';
    final phone = map['customerPhone'] ?? map['phone'] ?? map['soDienThoai'];

    int total = 0;
    final rawTotal = map['totalAmount'] ?? map['totalPrice'] ?? map['tongTien'] ?? map['total'];
    if (rawTotal is num) {
      total = rawTotal.toInt();
    } else if (rawTotal != null) {
      total = int.tryParse(rawTotal.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final status = map['status'] ?? map['trangThai'] ?? 'Pending';

    List<OrderItemModel> itemList = [];
    final rawItems = map['items'] ?? map['cartItems'] ?? map['products'];
    if (rawItems is List) {
      for (var itemMap in rawItems) {
        if (itemMap is Map<String, dynamic>) {
          itemList.add(OrderItemModel.fromMap(itemMap));
        } else if (itemMap is Map) {
          itemList.add(OrderItemModel.fromMap(Map<String, dynamic>.from(itemMap)));
        }
      }
    }

    return OrderModel(
      id: id,
      orderCode: code.toString(),
      userId: uid.toString(),
      customerName: name.toString(),
      customerEmail: email.toString(),
      customerPhone: phone?.toString(),
      items: itemList,
      totalAmount: total,
      status: status.toString(),
      createdAt: created,
    );
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OrderModel.fromMap(data, id: doc.id);
  }

  String get formattedTotalAmount {
    final priceStr = totalAmount.toString();
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

  String get formattedCreatedAt {
    if (createdAt == null) return 'Chưa rõ';
    final date = createdAt!;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute - $day/$month/$year';
  }

  // Tên hiển thị tiếng Việt của trạng thái
  String get statusDisplay {
    switch (status) {
      case 'Pending':
        return 'Chờ xác nhận';
      case 'Preparing':
        return 'Đang chuẩn bị';
      case 'Completed':
        return 'Đã hoàn thành';
      default:
        return status;
    }
  }
}
