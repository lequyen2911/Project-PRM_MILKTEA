import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/cart_provider.dart';
import 'screens/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Không tự seed ở đây: app chạy trên máy khách, trước cả khi đăng nhập.
  // Seller đồng bộ thực đơn mẫu bằng nút trong Kênh Quản Trị (syncStandardMenuData).

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