import 'package:flutter/foundation.dart';
import '../models/cart_item_model.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItemModel> _items = {};

  /// Bản đồ các món trong giỏ hàng
  Map<String, CartItemModel> get items => {..._items};

  /// Danh sách món trong giỏ hàng dưới dạng List
  List<CartItemModel> get itemList => _items.values.toList();

  /// Tổng số lượng ly trong giỏ hàng
  int get totalQuantity => _items.values.fold(0, (sum, item) => sum + item.quantity);

  /// Tổng tiền của tất cả các món trong giỏ hàng
  int get totalAmount => _items.values.fold(0, (sum, item) => sum + item.totalPrice);

  /// Định dạng tiền tổng VND
  String get formattedTotalAmount => CartItemModel.formatVnd(totalAmount);

  /// Kiểm tra giỏ hàng có rỗng không
  bool get isEmpty => _items.isEmpty;

  /// Thêm món vào giỏ hàng (tự động gộp số lượng nếu cùng tùy biến size, đường, đá, topping)
  void addItem({
    required String productId,
    required String productName,
    required String imageUrl,
    required String size,
    required String sugar,
    required String ice,
    required List<String> toppings,
    required int basePrice,
    Map<String, int> toppingPrices = const {},
    required int unitPrice,
    int quantity = 1,
  }) {
    final sortedToppings = List<String>.from(toppings)..sort();
    final cartItemId = '${productId}_${size}_${sugar}_${ice}_${sortedToppings.join('-')}';

    if (_items.containsKey(cartItemId)) {
      _items[cartItemId]!.quantity += quantity;
    } else {
      _items[cartItemId] = CartItemModel(
        id: cartItemId,
        productId: productId,
        productName: productName,
        imageUrl: imageUrl,
        size: size,
        sugar: sugar,
        ice: ice,
        toppings: sortedToppings,
        basePrice: basePrice,
        toppingPrices: toppingPrices,
        unitPrice: unitPrice,
        quantity: quantity,
      );
    }

    notifyListeners();
  }

  /// Cập nhật giá khi Seller đã đổi giá món hoặc giá topping sau lúc khách thêm vào giỏ.
  /// Phụ thu size giữ nguyên, chỉ cộng phần chênh lệch. Trả về true nếu giá có thay đổi.
  bool updatePrices(String cartItemId, {required int basePrice, Map<String, int>? toppingPrices}) {
    final item = _items[cartItemId];
    if (item == null) return false;

    final newToppingPrices = toppingPrices ?? item.toppingPrices;
    int diff = basePrice - item.basePrice;
    newToppingPrices.forEach((id, price) => diff += price - (item.toppingPrices[id] ?? price));
    if (basePrice == item.basePrice && mapEquals(newToppingPrices, item.toppingPrices)) return false;

    _items[cartItemId] = CartItemModel(
      id: item.id,
      productId: item.productId,
      productName: item.productName,
      imageUrl: item.imageUrl,
      size: item.size,
      sugar: item.sugar,
      ice: item.ice,
      toppings: item.toppings,
      basePrice: basePrice,
      toppingPrices: newToppingPrices,
      unitPrice: item.unitPrice + diff,
      quantity: item.quantity,
    );
    notifyListeners();
    return true;
  }

  /// Tăng số lượng của 1 món
  void incrementQuantity(String cartItemId) {
    if (_items.containsKey(cartItemId)) {
      _items[cartItemId]!.quantity += 1;
      notifyListeners();
    }
  }

  /// Giảm số lượng của 1 món (nếu về 0 thì tự xóa khỏi giỏ)
  void decrementQuantity(String cartItemId) {
    if (!_items.containsKey(cartItemId)) return;

    if (_items[cartItemId]!.quantity > 1) {
      _items[cartItemId]!.quantity -= 1;
    } else {
      _items.remove(cartItemId);
    }
    notifyListeners();
  }

  /// Xóa hẳn 1 món khỏi giỏ hàng
  void removeItem(String cartItemId) {
    if (_items.containsKey(cartItemId)) {
      _items.remove(cartItemId);
      notifyListeners();
    }
  }

  /// Xóa toàn bộ giỏ hàng
  void clear() {
    _items.clear();
    notifyListeners();
  }
}
