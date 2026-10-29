import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/database_seeder.dart';
import '../auth/login_screen.dart';
import '../seller/seller_dashboard_screen.dart';
import 'product_detail_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedCategory = 'Tất cả';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Link ảnh dự phòng nét đẹp theo tên món nếu link trên Firestore bị lỗi
  static const String defaultTeaImage =
      'https://images.pexels.com/photos/6412836/pexels-photo-6412836.jpeg?auto=compress&cs=tinysrgb&w=600';
  static const String matchaImage =
      'https://images.pexels.com/photos/31599066/pexels-photo-31599066/free-photo-of-refreshing-iced-matcha-latte-with-sunglasses.jpeg?auto=compress&cs=tinysrgb&w=600';
  static const String peachTeaImage =
      'https://images.pexels.com/photos/31066139/pexels-photo-31066139.jpeg?auto=compress&cs=tinysrgb&w=600';

  String _getReliableImageUrl(ProductModel product) {
    if (product.imageUrl.isNotEmpty &&
        (product.imageUrl.startsWith('http://') || product.imageUrl.startsWith('https://'))) {
      return product.imageUrl;
    }
    final name = product.name.toLowerCase();
    if (name.contains('matcha')) return matchaImage;
    if (name.contains('đào') || name.contains('trái cây') || name.contains('hoa quả')) {
      return peachTeaImage;
    }
    return defaultTeaImage;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const primaryColor = Color(0xFF6D4C41);
    const accentColor = Color(0xFFD87D4A);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tiệm Trà Nhỏ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Xin chào, ${user?.displayName ?? user?.email?.split('@').first ?? "Bạn"}! 👋',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Nút chuyển đến Kênh Quản Trị (Chỉ hiện nếu user là Seller / Admin)
          if (user != null)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, snapshot) {
                bool isSeller = false;
                final email = user.email?.trim().toLowerCase() ?? '';
                if (email == 'admin.tiemtranho@gmail.com') {
                  isSeller = true;
                } else if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data?['role'] == 'seller') {
                    isSeller = true;
                  }
                }

                if (!isSeller) return const SizedBox.shrink();

                return IconButton(
                  icon: const Icon(Icons.storefront_rounded),
                  tooltip: 'Kênh Quản Trị (Seller)',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SellerDashboardScreen()),
                    );
                  },
                );
              },
            ),
          // Nút cập nhật link ảnh tự động lên Firestore
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Cập nhật lại link ảnh nét',
            onPressed: () async {
              try {
                await DatabaseSeeder.fixAllImageLinks();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Đã cập nhật lại link ảnh nét đẹp trên Firestore!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: _dbService.getProductsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  SizedBox(height: 12),
                  Text('Đang tải thực đơn từ Firestore...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'Không thể đọc dữ liệu từ Cloud Firestore!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chi tiết lỗi: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                      onPressed: () => setState(() {}),
                    ),
                  ],
                ),
              ),
            );
          }

          final allProducts = snapshot.data ?? [];

          // Gom danh mục động từ Firestore và bổ sung mục Topping
          final Set<String> categorySet = {'Tất cả'};
          for (var p in allProducts) {
            if (p.category.trim().isNotEmpty) {
              categorySet.add(p.category.trim());
            }
          }
          categorySet.add('Topping');
          final categories = categorySet.toList();

          // Lọc danh sách món
          var filteredList = allProducts;
          if (_selectedCategory != 'Tất cả' && _selectedCategory != 'Topping') {
            filteredList = filteredList
                .where((p) => p.category.toLowerCase() == _selectedCategory.toLowerCase())
                .toList();
          }

          if (_searchQuery.isNotEmpty) {
            filteredList = filteredList.where((p) {
              return p.name.toLowerCase().contains(_searchQuery) ||
                  (p.description ?? '').toLowerCase().contains(_searchQuery);
            }).toList();
          }

          return CustomScrollView(
            slivers: [
              // 1. Thanh tìm kiếm món
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm trà sữa, topping, đồ ăn...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: primaryColor),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Tiêu đề menu & Tabs danh mục
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(
                        _selectedCategory == 'Topping'
                            ? Icons.cookie_rounded
                            : Icons.local_cafe_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCategory == 'Topping'
                            ? 'Danh Sách Topping & Thạch'
                            : 'Thực Đơn Trà Sữa & Đồ Uống',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _selectedCategory == 'Topping'
                            ? 'Topping gọi thêm'
                            : '${filteredList.length} món',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),

              if (categories.length > 1)
                SliverToBoxAdapter(
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = _selectedCategory == category;
                        final isToppingTab = category == 'Topping';
                        return ChoiceChip(
                          avatar: isToppingTab
                              ? Icon(
                                  Icons.cookie,
                                  size: 16,
                                  color: isSelected ? Colors.white : accentColor,
                                )
                              : null,
                          label: Text(category),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? primaryColor
                                : (isToppingTab
                                    ? accentColor.withOpacity(0.5)
                                    : Colors.brown.shade100),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),

              // 4. Lưới danh sách món ăn hoặc danh sách Topping
              if (_selectedCategory == 'Topping')
                _buildToppingsSliverGrid(context, allProducts, primaryColor, accentColor)
              else if (filteredList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.coffee_rounded, size: 70, color: Colors.brown.shade200),
                          const SizedBox(height: 12),
                          Text(
                            allProducts.isEmpty
                                ? 'Chưa có món nào trong collection [products] trên Firestore!'
                                : 'Không tìm thấy món phù hợp với tìm kiếm.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.brown.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await DatabaseSeeder.seedProducts(force: true);
                              setState(() {});
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Thêm thực đơn mẫu vào Firestore'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = filteredList[index];
                        return _buildProductCard(context, product, primaryColor, accentColor);
                      },
                      childCount: filteredList.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Định dạng tiền Topping (VD: +5.000 đ)
  String _formatToppingPrice(int price) {
    if (price <= 0) return '0 đ';
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

  /// Lưới hiển thị danh sách Topping khi chọn Tab 'Topping'
  Widget _buildToppingsSliverGrid(
    BuildContext context,
    List<ProductModel> allProducts,
    Color primaryColor,
    Color accentColor,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.getToppingsStream(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> toppings = snapshot.data ?? [];
        if (toppings.isEmpty) {
          toppings = DatabaseSeeder.defaultToppings;
          DatabaseSeeder.seedToppings().catchError((_) {});
        }

        if (_searchQuery.isNotEmpty) {
          toppings = toppings.where((t) {
            final name = (t['name'] ?? t['ten'] ?? '').toString().toLowerCase();
            final desc = (t['description'] ?? t['desc'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || desc.contains(_searchQuery);
          }).toList();
        }

        if (toppings.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Không tìm thấy topping phù hợp với từ khóa.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.74,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final topping = toppings[index];
                final name = topping['name'] ?? topping['ten'] ?? 'Topping';
                final price = (topping['price'] is num)
                    ? (topping['price'] as num).toInt()
                    : int.tryParse(topping['price']?.toString() ?? '0') ?? 0;
                final img = topping['imageUrl'] ?? topping['image'] ?? '';
                final desc = topping['description'] ?? topping['desc'] ?? '';

                return Card(
                  elevation: 2,
                  shadowColor: Colors.brown.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  color: Colors.white,
                  child: InkWell(
                    onTap: () => _showToppingDetailSheet(
                      context,
                      topping,
                      allProducts,
                      primaryColor,
                      accentColor,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              img.toString().isNotEmpty
                                  ? Image.network(
                                      img.toString(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFFFAF6F0),
                                        child: const Icon(
                                          Icons.bubble_chart_rounded,
                                          size: 40,
                                          color: Color(0xFF6D4C41),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFFAF6F0),
                                      child: const Icon(
                                        Icons.bubble_chart_rounded,
                                        size: 40,
                                        color: Color(0xFF6D4C41),
                                      ),
                                    ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Topping',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    if (desc.toString().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        desc.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatToppingPrice(price),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD87D4A),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Chọn món',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: toppings.length,
            ),
          ),
        );
      },
    );
  }

  /// Modal BottomSheet xem chi tiết Topping và gợi ý các món trà sữa kết hợp
  void _showToppingDetailSheet(
    BuildContext context,
    Map<String, dynamic> topping,
    List<ProductModel> allProducts,
    Color primaryColor,
    Color accentColor,
  ) {
    final name = topping['name'] ?? topping['ten'] ?? 'Topping';
    final price = (topping['price'] is num)
        ? (topping['price'] as num).toInt()
        : int.tryParse(topping['price']?.toString() ?? '0') ?? 0;
    final img = topping['imageUrl'] ?? topping['image'] ?? '';
    final desc = topping['description'] ??
        topping['desc'] ??
        'Topping ăn kèm thơm ngon hảo hạng, tăng thêm độ béo ngọt và cảm giác dai giòn thích thú cho ly trà sữa.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo dialog
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Thông tin Topping
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: img.toString().isNotEmpty
                        ? Image.network(
                            img.toString(),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 72,
                              height: 72,
                              color: const Color(0xFFFAF6F0),
                              child: const Icon(
                                Icons.bubble_chart_rounded,
                                size: 36,
                                color: Color(0xFF6D4C41),
                              ),
                            ),
                          )
                        : Container(
                            width: 72,
                            height: 72,
                            color: const Color(0xFFFAF6F0),
                            child: const Icon(
                              Icons.bubble_chart_rounded,
                              size: 36,
                              color: Color(0xFF6D4C41),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatToppingPrice(price),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD87D4A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(
                desc.toString(),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),

              const Divider(height: 28),

              // Gợi ý món kết hợp
              const Text(
                'Gợi ý kết hợp cùng món ngon (Chọn món để thêm topping):',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 10),

              if (allProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Chưa có danh sách món để chọn kèm.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              else
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: allProducts.length > 5 ? 5 : allProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final p = allProducts[idx];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(product: p),
                            ),
                          );
                        },
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF6F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.brown.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.formattedPrice,
                                style: const TextStyle(
                                  color: Color(0xFFD87D4A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 12, color: Colors.white),
                                    SizedBox(width: 2),
                                    Text(
                                      'Chọn món này',
                                      style: TextStyle(color: Colors.white, fontSize: 9),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Card từng món trà sữa hiển thị ảnh sắc nét
  Widget _buildProductCard(
    BuildContext context,
    ProductModel product,
    Color primaryColor,
    Color accentColor,
  ) {
    final displayImageUrl = _getReliableImageUrl(product);

    return Card(
      elevation: 2,
      shadowColor: Colors.brown.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh sản phẩm
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    displayImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.brown.shade50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_cafe, size: 36, color: Colors.brown.shade300),
                          const SizedBox(height: 4),
                          Text(
                            product.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(fontSize: 10, color: Colors.brown.shade400),
                          ),
                        ],
                      ),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.brown.shade50,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
                  // Badge danh mục
                  if (product.category.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          product.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Thông tin món
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        if (product.description != null && product.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Giá tiền và nút Thêm
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD87D4A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
