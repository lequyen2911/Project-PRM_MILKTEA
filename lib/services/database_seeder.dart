import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service tự động nạp dữ liệu mẫu (Seeder) & Đồng bộ dữ liệu chuẩn (PRM393)
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
      await cleanupUnwantedToppings();
      debugPrint('=== HOÀN TẤT SEED DỮ LIỆU THÀNH CÔNG! ===');
    } catch (e) {
      debugPrint('❌ Lỗi khi seed dữ liệu: $e');
      rethrow;
    }
  }

  /// Danh sách Đồ uống mẫu cố định chuẩn của quán (5 món)
  static const List<Map<String, dynamic>> defaultProducts = [
    {
      'id': 'prod_truyenthong',
      'name': 'Trà sữa truyền thống',
      'basePrice': 30000,
      'category': 'Trà sữa',
      'imageUrl':
          'https://images.pexels.com/photos/6412836/pexels-photo-6412836.jpeg?auto=compress&cs=tinysrgb&w=600',
      'isAvailable': true,
      'description': 'Vị trà đậm đà hoà quyện sữa thơm béo chuẩn vị Đài Loan.',
    },
    {
      'id': 'prod_matcha',
      'name': 'Trà sữa matcha',
      'basePrice': 35000,
      'category': 'Trà sữa',
      'imageUrl':
          'https://images.pexels.com/photos/31599066/pexels-photo-31599066/free-photo-of-refreshing-iced-matcha-latte-with-sunglasses.jpeg?auto=compress&cs=tinysrgb&w=600',
      'isAvailable': true,
      'description': 'Bột matcha Uji Nhật Bản nguyên chất, thanh mát và thơm ngậy.',
    },
    {
      'id': 'prod_hongtra',
      'name': 'Hồng trà sữa',
      'basePrice': 32000,
      'category': 'Trà sữa',
      'imageUrl':
          'https://images.pexels.com/photos/6412952/pexels-photo-6412952.jpeg?auto=compress&cs=tinysrgb&w=600',
      'isAvailable': true,
      'description': 'Hồng trà Ceylon cao cấp ủ lạnh kết hợp vị ngọt dịu dàng.',
    },
    {
      'id': 'prod_olong',
      'name': 'Trà ô long sữa',
      'basePrice': 35000,
      'category': 'Trà sữa',
      'imageUrl':
          'https://images.pexels.com/photos/11160112/pexels-photo-11160112.jpeg?auto=compress&cs=tinysrgb&w=600',
      'isAvailable': true,
      'description': 'Trà ô long nướng thơm lừng, hậu vị ngọt thanh.',
    },
    {
      'id': 'prod_tradao',
      'name': 'Trà đào cam sả',
      'basePrice': 38000,
      'category': 'Trà trái cây',
      'imageUrl':
          'https://images.pexels.com/photos/31066139/pexels-photo-31066139.jpeg?auto=compress&cs=tinysrgb&w=600',
      'isAvailable': true,
      'description': 'Hương sả nồng ấm quyện cùng đào giòn ngọt và cam tươi mọng nước.',
    },
  ];

  /// Danh sách Topping mẫu cố định chuẩn của quán (Chỉ đúng 4 món chuẩn đã duyệt)
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
  ];

  /// Xóa đúng 4 document topping đã thêm ngoài ý muốn khỏi Cloud Firestore
  static Future<Map<String, String>> cleanupUnwantedToppings() async {
    final Map<String, String> unwantedDocs = {
      'tp_kemcheese': 'Kem Cheese Macchiato',
      'tp_suongsao': 'Thạch sương sáo',
      'tp_thachdua': 'Thạch dừa non',
      'tp_daudo': 'Đậu đỏ Azuki',
    };

    final Map<String, String> results = {};

    for (var entry in unwantedDocs.entries) {
      final docId = entry.key;
      final toppingName = entry.value;

      try {
        final doc = await _firestore.collection(colToppings).doc(docId).get();
        if (doc.exists) {
          await _firestore.collection(colToppings).doc(docId).delete();
          results[docId] = '✅ Đã xóa thành công "$toppingName" ($docId)';
          debugPrint('🗑️ Đã xóa document: $docId ($toppingName)');
        } else {
          results[docId] = '⏩ Không tồn tại document "$toppingName" ($docId)';
        }
      } catch (e) {
        results[docId] = '❌ Lỗi khi xóa "$toppingName" ($docId): $e';
      }
    }

    return results;
  }

  /// 1. Seed danh sách Sản phẩm (Trà sữa)
  static Future<void> seedProducts({bool force = false}) async {
    final productsRef = _firestore.collection(colProducts);

    if (!force) {
      final snapshot = await productsRef.limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('⏩ Collection [$colProducts] đã có dữ liệu. Bỏ qua.');
        return;
      }
    }

    final batch = _firestore.batch();
    for (var product in defaultProducts) {
      final docRef = productsRef.doc(product['id']);
      batch.set(docRef, {
        ...product,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    debugPrint('✅ Đã thêm ${defaultProducts.length} sản phẩm vào [$colProducts].');
  }

  /// 2. Seed danh sách Topping (Chỉ đúng 4 món)
  static Future<void> seedToppings({bool force = false}) async {
    final toppingsRef = _firestore.collection(colToppings);

    if (!force) {
      final snapshot = await toppingsRef.limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('⏩ Collection [$colToppings] đã có dữ liệu. Bỏ qua.');
        return;
      }
    }

    final batch = _firestore.batch();
    for (var topping in defaultToppings) {
      final docRef = toppingsRef.doc(topping['id']);
      batch.set(docRef, {
        ...topping,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    debugPrint('✅ Đã thêm ${defaultToppings.length} topping vào [$colToppings].');
  }

  /// 3. Đồng bộ Idempotent dữ liệu chuẩn (Toppings & Products) lên Cloud Firestore
  /// - Tự động xóa 4 topping đã gỡ khỏi danh sách chuẩn nếu chúng tồn tại.
  /// - Kiểm tra các món chuẩn còn lại (4 topping, 5 đồ uống) hiện có trên Firestore.
  /// - CHỈ bổ sung các mục chuẩn còn thiếu.
  /// - KHÔNG xóa hay đè lên dữ liệu do seller đã chỉnh sửa hoặc tự tạo thêm.
  static Future<Map<String, int>> syncStandardMenuData() async {
    int addedToppingsCount = 0;
    int addedProductsCount = 0;

    // Tự động gỡ bỏ 4 topping bị xóa khỏi danh sách chuẩn
    await cleanupUnwantedToppings();

    // 1. Kiểm tra Topping hiện có trên Firestore
    final toppingsSnapshot = await _firestore.collection(colToppings).get();
    final Set<String> existingToppingNames = toppingsSnapshot.docs.map((doc) {
      final data = doc.data();
      return (data['name'] ?? data['ten'] ?? '').toString().trim().toLowerCase();
    }).toSet();

    for (var topping in defaultToppings) {
      final name = (topping['name'] ?? '').toString().trim().toLowerCase();
      if (!existingToppingNames.contains(name)) {
        final docRef = _firestore.collection(colToppings).doc(topping['id']);
        await docRef.set({
          'name': topping['name'],
          'price': topping['price'],
          'imageUrl': topping['imageUrl'],
          'description': topping['description'],
          'isAvailable': topping['isAvailable'] ?? true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        addedToppingsCount++;
      }
    }

    // 2. Kiểm tra Đồ uống hiện có trên Firestore
    final productsSnapshot = await _firestore.collection(colProducts).get();
    final Set<String> existingProductNames = productsSnapshot.docs.map((doc) {
      final data = doc.data();
      return (data['name'] ?? data['productName'] ?? data['ten'] ?? '').toString().trim().toLowerCase();
    }).toSet();

    for (var product in defaultProducts) {
      final name = (product['name'] ?? '').toString().trim().toLowerCase();
      if (!existingProductNames.contains(name)) {
        final docRef = _firestore.collection(colProducts).doc(product['id']);
        await docRef.set({
          'name': product['name'],
          'basePrice': product['basePrice'],
          'category': product['category'],
          'imageUrl': product['imageUrl'],
          'description': product['description'],
          'isAvailable': product['isAvailable'] ?? true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        addedProductsCount++;
      }
    }

    return {
      'toppings': addedToppingsCount,
      'products': addedProductsCount,
    };
  }

  /// 4. Cập nhật lại toàn bộ link ảnh trong Firestore sang link Pexels nét đẹp & không bị chặn
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

  /// 5. Seed tài khoản mẫu vào `users`
  static Future<void> seedSampleUsers({bool force = false}) async {
    final usersRef = _firestore.collection(colUsers);

    if (!force) {
      final snapshot = await usersRef.limit(1).get();
      if (snapshot.docs.isNotEmpty) return;
    }

    final List<Map<String, dynamic>> sampleUsers = [
      {
        'uid': 'admin_tiemtranho_seller',
        'name': 'Chủ Quán (Admin)',
        'email': 'admin.tiemtranho@gmail.com',
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
