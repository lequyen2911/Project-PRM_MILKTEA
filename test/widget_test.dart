// Unit test cho giỏ hàng (CartProvider). Không cần Firebase nên chạy được bằng `flutter test`.

import 'package:flutter_test/flutter_test.dart';
import 'package:projectgroup_milktea/models/cart_item_model.dart';
import 'package:projectgroup_milktea/providers/cart_provider.dart';

void main() {
  late CartProvider cart;

  // Trà sữa 30.000đ, size L (+6.000đ), topping trân châu (+5.000đ) => 41.000đ / ly
  void addMilkTea({
    List<String> toppings = const ['Trân châu'],
    String sugar = '100%',
    int quantity = 1,
  }) {
    cart.addItem(
      productId: 'tra-sua',
      productName: 'Trà sữa truyền thống',
      imageUrl: '',
      size: 'L',
      sugar: sugar,
      ice: '100%',
      toppings: toppings,
      basePrice: 30000,
      toppingPrices: const {'tran-chau': 5000},
      unitPrice: 41000,
      quantity: quantity,
    );
  }

  setUp(() => cart = CartProvider());

  group('CartProvider', () {
    test('giỏ hàng mới thì trống', () {
      expect(cart.isEmpty, isTrue);
      expect(cart.totalQuantity, 0);
      expect(cart.totalAmount, 0);
    });

    test('thêm cùng món, cùng tùy chọn thì gộp số lượng', () {
      addMilkTea(quantity: 1);
      addMilkTea(quantity: 2);

      expect(cart.itemList.length, 1);
      expect(cart.totalQuantity, 3);
      expect(cart.totalAmount, 123000);
    });

    test('topping khác thứ tự vẫn được coi là cùng một ly', () {
      addMilkTea(toppings: ['Trân châu', 'Thạch dừa']);
      addMilkTea(toppings: ['Thạch dừa', 'Trân châu']);

      expect(cart.itemList.length, 1);
      expect(cart.totalQuantity, 2);
    });

    test('khác mức đường thì tách thành dòng riêng', () {
      addMilkTea(sugar: '100%');
      addMilkTea(sugar: '50%');

      expect(cart.itemList.length, 2);
    });

    test('giảm số lượng về 0 thì tự xóa món khỏi giỏ', () {
      addMilkTea(quantity: 2);
      final id = cart.itemList.first.id;

      cart.decrementQuantity(id);
      expect(cart.totalQuantity, 1);

      cart.decrementQuantity(id);
      expect(cart.isEmpty, isTrue);
    });

    test('tăng số lượng và xóa món', () {
      addMilkTea();
      final id = cart.itemList.first.id;

      cart.incrementQuantity(id);
      expect(cart.totalQuantity, 2);

      cart.removeItem(id);
      expect(cart.isEmpty, isTrue);
    });

    test('Seller đổi giá gốc: chỉ cộng phần chênh lệch, giữ phụ thu size và topping', () {
      addMilkTea(quantity: 2);
      final id = cart.itemList.first.id;

      final changed = cart.updatePrices(id, basePrice: 35000);

      final item = cart.items[id]!;
      expect(changed, isTrue);
      expect(item.basePrice, 35000);
      expect(item.unitPrice, 46000);
      expect(cart.totalAmount, 92000);
    });

    test('Seller đổi giá topping: cộng phần chênh lệch của topping', () {
      addMilkTea();
      final id = cart.itemList.first.id;

      cart.updatePrices(id, basePrice: 30000, toppingPrices: const {'tran-chau': 7000});

      final item = cart.items[id]!;
      expect(item.toppingPrices['tran-chau'], 7000);
      expect(item.unitPrice, 43000);
    });

    test('giá không đổi thì không cập nhật', () {
      addMilkTea();
      final id = cart.itemList.first.id;

      final changed = cart.updatePrices(id, basePrice: 30000, toppingPrices: const {'tran-chau': 5000});

      expect(changed, isFalse);
      expect(cart.items[id]!.unitPrice, 41000);
    });

    test('clear xóa sạch giỏ hàng', () {
      addMilkTea();
      cart.clear();
      expect(cart.isEmpty, isTrue);
    });
  });

  group('CartItemModel.formatVnd', () {
    test('định dạng tiền Việt Nam có dấu chấm ngăn cách', () {
      expect(CartItemModel.formatVnd(41000), '41.000 đ');
      expect(CartItemModel.formatVnd(1250000), '1.250.000 đ');
      expect(CartItemModel.formatVnd(0), '0 đ');
    });
  });
}
