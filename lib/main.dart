import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/cart_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'services/database_seeder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Tự động kiểm tra và seed dữ liệu topping & sản phẩm nếu Firestore chưa có
  DatabaseSeeder.seedToppings().catchError((e) => debugPrint('Seed toppings error: $e'));
  DatabaseSeeder.seedProducts().catchError((e) => debugPrint('Seed products error: $e'));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Tiệm Trà Nhỏ',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6D4C41),
            primary: const Color(0xFF6D4C41),
          ),
          useMaterial3: true,
          fontFamily: null,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}