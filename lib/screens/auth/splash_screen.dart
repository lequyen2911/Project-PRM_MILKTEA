import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
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
        final String userEmail = (user.email ?? '').trim().toLowerCase();

        // Tài khoản Admin cố định của hệ thống
        final bool isAdminEmail = userEmail == 'admin.tiemtranho@gmail.com';

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

            // Xử lý khi có lỗi đọc Firestore
            if (roleSnapshot.hasError) {
              return Scaffold(
                backgroundColor: const Color(0xFFF7F2ED),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text(
                          'Lỗi xác thực quyền người dùng!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chi tiết: ${roleSnapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.logout),
                          label: const Text('Đăng xuất & Thử lại'),
                          onPressed: () async {
                            await AuthService().signOut();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
              final data = roleSnapshot.data!.data() as Map<String, dynamic>?;
              final String role = data?['role'] ?? (isAdminEmail ? 'seller' : 'customer');

              if (role == 'seller' || isAdminEmail) {
                return const SellerDashboardScreen();
              }
              return const CustomerHomeScreen();
            }

            // Nếu chưa có document trên Firestore nhưng là email Admin -> Mở SellerDashboard
            if (isAdminEmail) {
              return const SellerDashboardScreen();
            }

            // Mặc định tài khoản người dùng bình thường là Customer
            return const CustomerHomeScreen();
          },
        );
      },
    );
  }
}
