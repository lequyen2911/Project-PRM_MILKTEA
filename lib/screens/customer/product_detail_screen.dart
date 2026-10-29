import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/database_service.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final DatabaseService _dbService = DatabaseService();

  String _selectedSize = 'M';
  final Map<String, int> _sizePrice = {
    'M': 0,
    'L': 6000,
  };

  String _selectedSugar = '100%';
  final List<String> _sugarOptions = ['100%', '70%', '50%', '30%', '0%'];

  String _selectedIce = '100%';
  final List<String> _iceOptions = ['100%', '70%', '50%', '0%'];

  final List<Map<String, dynamic>> _selectedToppings = [];
  int _quantity = 1;

  // Tính tổng tiền động
  int get _totalPrice {
    int price = widget.product.basePrice + (_sizePrice[_selectedSize] ?? 0);
    for (var topping in _selectedToppings) {
      price += (topping['price'] as num).toInt();
    }
    return price * _quantity;
  }

  String _formatPrice(int amount) {
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

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6D4C41);
    const accentColor = Color(0xFFD87D4A);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      body: CustomScrollView(
        slivers: [
          // Sliver AppBar với hình ảnh món
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.product.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.product.imageUrl.isNotEmpty
                        ? widget.product.imageUrl
                        : 'https://images.pexels.com/photos/6412836/pexels-photo-6412836.jpeg?auto=compress&cs=tinysrgb&w=600',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.brown.shade200,
                      child: const Center(
                        child: Icon(Icons.local_cafe, size: 70, color: Colors.white),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black54,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nội dung tuỳ chỉnh món
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên món và giá gốc
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                      ),
                      Text(
                        widget.product.formattedPrice,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  if (widget.product.description != null &&
                      widget.product.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.product.description!,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                    ),
                  ],
                  const Divider(height: 32),

                  // 1. Chọn Size
                  const Text(
                    'Chọn Size',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _sizePrice.entries.map((entry) {
                      final size = entry.key;
                      final extra = entry.value;
                      final isSelected = _selectedSize == size;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ChoiceChip(
                          label: Text(
                            extra == 0 ? 'Size $size' : 'Size $size (+${_formatPrice(extra)})',
                          ),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedSize = size);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 32),

                  // 2. Chọn Độ Ngọt (Đường)
                  const Text(
                    'Lượng Đường',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _sugarOptions.map((sugar) {
                      final isSelected = _selectedSugar == sugar;
                      return ChoiceChip(
                        label: Text(sugar),
                        selected: isSelected,
                        selectedColor: primaryColor,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedSugar = sugar);
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 32),

                  // 3. Chọn Lượng Đá
                  const Text(
                    'Lượng Đá',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _iceOptions.map((ice) {
                      final isSelected = _selectedIce == ice;
                      return ChoiceChip(
                        label: Text(ice),
                        selected: isSelected,
                        selectedColor: primaryColor,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedIce = ice);
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 32),

                  // 4. Chọn Topping (Load trực tiếp từ Firestore)
                  const Text(
                    'Thêm Topping',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _dbService.getToppingsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final toppings = snapshot.data!;
                      if (toppings.isEmpty) {
                        return const Text(
                          'Chưa có topping nào.',
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      return Column(
                        children: toppings.map((topping) {
                          final isChecked = _selectedToppings
                              .any((t) => t['id'] == topping['id']);
                          final price = (topping['price'] as num).toInt();

                          final img = topping['imageUrl'] ?? topping['image'] ?? '';

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: img.toString().isNotEmpty
                                  ? Image.network(
                                      img.toString(),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.bubble_chart_rounded,
                                        size: 28,
                                        color: Color(0xFF6D4C41),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.bubble_chart_rounded,
                                      size: 28,
                                      color: Color(0xFF6D4C41),
                                    ),
                            ),
                            title: Text(topping['name'] ?? ''),
                            subtitle: Text('+${_formatPrice(price)}'),
                            value: isChecked,
                            activeColor: primaryColor,
                            onChanged: (bool? val) {
                              setState(() {
                                if (val == true) {
                                  _selectedToppings.add(topping);
                                } else {
                                  _selectedToppings.removeWhere(
                                      (t) => t['id'] == topping['id']);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 100), // Khoảng trống cho BottomBar
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Bar: Chọn số lượng + Nút Thêm vào giỏ
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Bộ tăng giảm số lượng
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.brown.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: () {
                        if (_quantity > 1) {
                          setState(() => _quantity--);
                        }
                      },
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () {
                        setState(() => _quantity++);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Nút Thêm vào giỏ hàng
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final toppingPrice = _selectedToppings.fold<int>(
                      0,
                      (sum, t) => sum + (t['price'] as num).toInt(),
                    );
                    final unitPrice = widget.product.basePrice +
                        (_sizePrice[_selectedSize] ?? 0) +
                        toppingPrice;

                    context.read<CartProvider>().addItem(
                          productId: widget.product.id,
                          productName: widget.product.name,
                          imageUrl: widget.product.imageUrl,
                          size: _selectedSize,
                          sugar: _selectedSugar,
                          ice: _selectedIce,
                          toppings: _selectedToppings
                              .map((t) => t['name'].toString())
                              .toList(),
                          unitPrice: unitPrice,
                          quantity: _quantity,
                        );

                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đã thêm ${widget.product.name} (x$_quantity) vào giỏ hàng!',
                        ),
                        backgroundColor: const Color(0xFF6D4C41),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        action: SnackBarAction(
                          label: 'Xem giỏ',
                          textColor: const Color(0xFFFFCC80),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CartScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    );

                    Navigator.pop(context);
                  },
                  child: Text(
                    'Thêm • ${_formatPrice(_totalPrice)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
