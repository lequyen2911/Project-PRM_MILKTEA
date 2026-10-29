import 'order_model.dart';

class CartItemModel {
  final String id;
  final String productId;
  final String productName;
  final String imageUrl;
  final String size;
  final String sugar;
  final String ice;
  final List<String> toppings;
  final int unitPrice;
  int quantity;

  CartItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.size,
    required this.sugar,
    required this.ice,
    required this.toppings,
    required this.unitPrice,
    this.quantity = 1,
  });

  int get totalPrice => unitPrice * quantity;

  String get formattedUnitPrice {
    return formatVnd(unitPrice);
  }

  String get formattedTotalPrice {
    return formatVnd(totalPrice);
  }

  static String formatVnd(int amount) {
    if (amount <= 0) return '0 đ';
    final priceStr = amount.toString();
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

  OrderItemModel toOrderItemModel() {
    return OrderItemModel(
      productName: productName,
      quantity: quantity,
      size: size,
      sugar: sugar,
      ice: ice,
      toppings: toppings,
      price: unitPrice,
    );
  }
}
