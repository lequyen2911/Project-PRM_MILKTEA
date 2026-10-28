import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import '../customer/customer_home_screen.dart';
import '../seller/seller_dashboard_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Đang kiểm tra phiên đăng nhập
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F2ED),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_cafe, size: 72, color: Colors.brown),
                  SizedBox(height: 16),
                  CircularProgressIndicator(color: Colors.brown),
                ],
              ),
            ),
          );
        }

        // Chưa đăng nhập -> Vào màn hình Login
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final User user = authSnapshot.data!;

        // Đã đăng nhập -> Đọc role từ Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFFF7F2ED),
                body: Center(
                  child: CircularProgressIndicator(color: Colors.brown),
                ),
              );
            }

            if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
              final data = roleSnapshot.data!.data() as Map<String, dynamic>?;
              final String role = data?['role'] ?? 'customer';

              if (role == 'seller') {
                return const SellerDashboardScreen();
              }
              return const CustomerHomeScreen();
            }

            // Trường hợp user có trong Auth nhưng chưa kịp có doc trong Firestore -> Mặc định vào Customer
            return const CustomerHomeScreen();
          },
        );
      },
    );
  }
}
