import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service tự động nạp dữ liệu mẫu (Seeder) cho ứng dụng Đặt Trà Sữa (PRM393)
class DatabaseSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String colProducts = 'products';
  static const String colToppings = 'toppings';
  static const String colUsers = 'users';

  /// Nạp tất cả dữ liệu (products, toppings, users mẫu)
  static Future<void> seedAll({bool force = false}) async {
    debugPrint('=== BẮT ĐẦU SEED DỮ LIỆU FIRESTORE ===');
    try {
      await seedProducts(force: force);
      await seedToppings(force: force);
      await seedSampleUsers(force: force);
      debugPrint('=== HOÀN TẤT SEED DỮ LIỆU THÀNH CÔNG! ===');
    } catch (e) {
      debugPrint('❌ Lỗi khi seed dữ liệu: $e');
      rethrow;
    }
  }

  /// 1. Seed danh sách Sản phẩm (Trà sữa) với link ảnh Pexels hoạt động 100%
  static Future<void> seedProducts({bool force = false}) async {
    final productsRef = _firestore.collection(colProducts);

    if (!force) {
      final snapshot = await productsRef.limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('⏩ Collection [$colProducts] đã có dữ liệu. Bỏ qua.');
        return;
      }
    }

    final List<Map<String, dynamic>> sampleProducts = [
      {
        'name': 'Trà sữa truyền thống',
        'basePrice': 30000,
        'category': 'Trà sữa',
        'imageUrl':
            'https://images.pexels.com/photos/6412836/pexels-photo-6412836.jpeg?auto=compress&cs=tinysrgb&w=600',
        'isAvailable': true,
        'description': 'Vị trà đậm đà hoà quyện sữa thơm béo chuẩn vị Đài Loan.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Trà sữa matcha',
        'basePrice': 35000,
        'category': 'Trà sữa',
        'imageUrl':
            'https://images.pexels.com/photos/31599066/pexels-photo-31599066/free-photo-of-refreshing-iced-matcha-latte-with-sunglasses.jpeg?auto=compress&cs=tinysrgb&w=600',
        'isAvailable': true,
        'description': 'Bột matcha Uji Nhật Bản nguyên chất, thanh mát và thơm ngậy.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Hồng trà sữa',
        'basePrice': 32000,
        'category': 'Trà sữa',
        'imageUrl':
            'https://images.pexels.com/photos/6412952/pexels-photo-6412952.jpeg?auto=compress&cs=tinysrgb&w=600',
        'isAvailable': true,
        'description': 'Hồng trà Ceylon cao cấp ủ lạnh kết hợp vị ngọt dịu dàng.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Trà ô long sữa',
        'basePrice': 35000,
        'category': 'Trà sữa',
        'imageUrl':
            'https://images.pexels.com/photos/11160112/pexels-photo-11160112.jpeg?auto=compress&cs=tinysrgb&w=600',
        'isAvailable': true,
        'description': 'Trà ô long nướng thơm lừng, hậu vị ngọt thanh.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Trà đào cam sả',
        'basePrice': 38000,
        'category': 'Trà trái cây',
        'imageUrl':
            'https://images.pexels.com/photos/31066139/pexels-photo-31066139.jpeg?auto=compress&cs=tinysrgb&w=600',
        'isAvailable': true,
        'description': 'Hương sả nồng ấm quyện cùng đào giòn ngọt và cam tươi mọng nước.',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();
    for (var product in sampleProducts) {
      final docRef = productsRef.doc();
      batch.set(docRef, product);
    }

    await batch.commit();
    debugPrint('✅ Đã thêm ${sampleProducts.length} sản phẩm vào [$colProducts].');
  }

  /// 2. Seed danh sách Topping với link ảnh hoạt động 100%
  static Future<void> seedToppings({bool force = false}) async {
    final toppingsRef = _firestore.collection(colToppings);

    if (!force) {
      final snapshot = await toppingsRef.limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('⏩ Collection [$colToppings] đã có dữ liệu. Bỏ qua.');
        return;
      }
    }

    final List<Map<String, dynamic>> sampleToppings = defaultToppings;

    final batch = _firestore.batch();
    for (var topping in sampleToppings) {
      final docRef = toppingsRef.doc();
      batch.set(docRef, topping);
    }

    await batch.commit();
    debugPrint('✅ Đã thêm ${sampleToppings.length} topping vào [$colToppings].');
  }

  /// Danh sách topping mặc định chất lượng cao có sẵn mô tả và hình ảnh
  static const List<Map<String, dynamic>> defaultToppings = [
    {
      'id': 'tp_tranchauden',
      'name': 'Trân châu đen',
      'price': 5000,
      'isAvailable': true,
      'description': 'Trân châu dẻo dai, nấu đường đen thơm ngọt chuẩn vị truyền thống.',
      'imageUrl':
          'https://images.pexels.com/photos/6412836/pexels-photo-6412836.jpeg?auto=compress&cs=tinysrgb&w=400',
    },
    {
      'id': 'tp_tranchautrang',
      'name': 'Trân châu trắng',
      'price': 7000,
      'isAvailable': true,
      'description': 'Trân châu 3Q giòn sần sật, thanh mát không ngấy.',
      'imageUrl':
          'https://images.pexels.com/photos/38006841/pexels-photo-38006841.jpeg?auto=compress&cs=tinysrgb&w=400',
    },
    {
      'id': 'tp_thachphomai',
      'name': 'Thạch phô mai',
      'price': 10000,
      'isAvailable': true,
      'description': 'Viên phô mai béo ngậy tan chảy được bọc lớp thạch giòn mỏng.',
      'imageUrl':
          'https://images.pexels.com/photos/33212344/pexels-photo-33212344.jpeg?auto=compress&cs=tinysrgb&w=400',
    },
    {
      'id': 'tp_puddingtrung',
      'name': 'Pudding trứng',
      'price': 8000,
      'isAvailable': true,
      'description': 'Pudding mềm mượt núng nính, thơm ngậy vị trứng và sữa tươi.',
      'imageUrl':
          'https://images.pexels.com/photos/37105558/pexels-photo-37105558.jpeg?auto=compress&cs=tinysrgb&w=400',
    },
    {
      'id': 'tp_kemcheese',
      'name': 'Kem Cheese Macchiato',
      'price': 10000,
      'isAvailable': true,
      'description': 'Lớp kem béo sánh mịn, mằn mặn thơm ngậy phủ trên mặt ly trà.',
      'imageUrl':
          'https://images.pexels.com/photos/31599066/pexels-photo-31599066/free-photo-of-refreshing-iced-matcha-latte-with-sunglasses.jpeg?auto=compress&cs=tinysrgb&w=400',
    },
    {
      'id': 'tp_suongsao',
      'name': 'Thạch sương sáo',
      'price': 6000,
      'isAvailable': true,
      'description': 'Thạch sương sáo thanh nhiệt, giải khát mát lạnh mùa hè.',
      'imageUrl':
          'https://images.pexels.com/photos/6412952/pexels-photo-6412952.jpeg?auto=compress&cs=tinysrgb&w=400',
    },
    {
      'id': 'tp_thachdua',
      'name': 'Thạch dừa non',
      'price': 6000,
      'isAvailable': true,
      'description': 'Thạch dừa non giòn ngọt tự nhiên, thơm mát vị dừa tươi.',
      'imageUrl':
          'https://images.pexels.com/photos/31066139/pexels-photo-31066139.jpeg?auto=compress&cs=tinysrgb&w=400',
    },
    {
      'id': 'tp_daudo',
      'name': 'Đậu đỏ Azuki',
      'price': 7000,
      'isAvailable': true,
      'description': 'Đậu đỏ hầm nhừ ngọt bùi, hoàn hảo khi kết hợp cùng trà sữa Matcha.',
      'imageUrl':
          'https://images.pexels.com/photos/11160112/pexels-photo-11160112.jpeg?auto=compress&cs=tinysrgb&w=400',
    },
  ];

  /// 3. Cập nhật lại toàn bộ link ảnh trong Firestore sang link Pexels nét đẹp & không bị chặn
  static Future<void> fixAllImageLinks() async {
    final Map<String, String> productImages = {
      'truyền thống':
          'https://images.pexels.com/photos/6412836/pexels-photo-6412836.jpeg?auto=compress&cs=tinysrgb&w=600',
      'matcha':
          'https://images.pexels.com/photos/31599066/pexels-photo-31599066/free-photo-of-refreshing-iced-matcha-latte-with-sunglasses.jpeg?auto=compress&cs=tinysrgb&w=600',
      'hồng trà':
          'https://images.pexels.com/photos/6412952/pexels-photo-6412952.jpeg?auto=compress&cs=tinysrgb&w=600',
      'ô long':
          'https://images.pexels.com/photos/11160112/pexels-photo-11160112.jpeg?auto=compress&cs=tinysrgb&w=600',
      'đào':
          'https://images.pexels.com/photos/31066139/pexels-photo-31066139.jpeg?auto=compress&cs=tinysrgb&w=600',
    };

    final productsSnapshot = await _firestore.collection(colProducts).get();
    final batch = _firestore.batch();

    for (var doc in productsSnapshot.docs) {
      final name = (doc.data()['name'] ?? doc.data()['productName'] ?? '').toString().toLowerCase();
      String? newUrl;
      for (var entry in productImages.entries) {
        if (name.contains(entry.key)) {
          newUrl = entry.value;
          break;
        }
      }
      newUrl ??= 'https://images.pexels.com/photos/6412836/pexels-photo-6412836.jpeg?auto=compress&cs=tinysrgb&w=600';

      batch.update(doc.reference, {
        'imageUrl': newUrl,
        'image': newUrl,
      });
    }

    await batch.commit();
    debugPrint('✅ Đã cập nhật lại link ảnh cho toàn bộ sản phẩm trên Firestore!');
  }

  /// 4. Seed tài khoản mẫu vào `users`
  static Future<void> seedSampleUsers({bool force = false}) async {
    final usersRef = _firestore.collection(colUsers);

    if (!force) {
      final snapshot = await usersRef.limit(1).get();
      if (snapshot.docs.isNotEmpty) return;
    }

    final List<Map<String, dynamic>> sampleUsers = [
      {
        'uid': 'seller_admin_test',
        'name': 'Chủ Quán (Admin Test)',
        'email': 'seller@milktea.vn',
        'role': 'seller',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();
    for (var user in sampleUsers) {
      final docRef = usersRef.doc(user['uid']);
      batch.set(docRef, user, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
