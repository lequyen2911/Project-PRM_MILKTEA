import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cấu hình GoogleSignIn với Web Client ID từ google-services.json
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '806741376387-25gh4c9c297fgaei5hlqjt71gl5iml2s.apps.googleusercontent.com',
  );

  // Stream theo dõi trạng thái đăng nhập
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // User hiện tại từ Firebase Auth
  User? get currentUser => _auth.currentUser;

  // Lấy thông tin UserModel (bao gồm role) từ Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint("Lỗi đọc dữ liệu user: $e");
    }
    return null;
  }

  // 1. Đăng nhập bằng Google
  Future<User?> signInWithGoogle({Function(String error)? onError}) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        onError?.call("Đã hủy thao tác chọn tài khoản Google.");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        try {
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
          if (!userDoc.exists) {
            final String userEmail = (user.email ?? '').toLowerCase();
            final String defaultRole = (userEmail == 'admin.tiemtranho@gmail.com') ? 'seller' : 'customer';

            await _firestore.collection('users').doc(user.uid).set({
              'uid': user.uid,
              'email': user.email ?? '',
              'name': user.displayName ?? 'Khách hàng',
              'role': defaultRole,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (firestoreError) {
          debugPrint("Cảnh báo lưu Firestore: $firestoreError");
        }
      }

      return user;
    } catch (e) {
      debugPrint("Lỗi đăng nhập Google: $e");
      onError?.call(e.toString());
      return null;
    }
  }

  // 2. Đăng ký tài khoản mới bằng Email & Mật khẩu
  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String name,
    Function(String error)? onError,
  }) async {
    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final User? user = cred.user;

      if (user != null) {
        // Cập nhật Tên hiển thị trong Firebase Auth
        await user.updateDisplayName(name.trim());

        final String normalizedEmail = email.trim().toLowerCase();
        final String finalRole = (normalizedEmail == 'admin.tiemtranho@gmail.com')
            ? 'seller'
            : 'customer';

        // Lưu thông tin vào Firestore với role tương ứng
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': email.trim(),
            'name': name.trim(),
            'role': finalRole,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (fsErr) {
          debugPrint("Lỗi lưu user vào Firestore: $fsErr");
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      String message = 'Đăng ký thất bại.';
      if (e.code == 'weak-password') {
        message = 'Mật khẩu quá yếu, vui lòng chọn mật khẩu từ 6 ký tự.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email này đã được sử dụng bởi tài khoản khác.';
      } else if (e.code == 'invalid-email') {
        message = 'Định dạng email không hợp lệ.';
      } else {
        message = e.message ?? message;
      }
      onError?.call(message);
      return null;
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  // 3. Đăng nhập bằng Email & Mật khẩu
  Future<User?> loginWithEmail({
    required String email,
    required String password,
    Function(String error)? onError,
  }) async {
    try {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      String message = 'Đăng nhập thất bại.';
      if (e.code == 'user-not-found') {
        message = 'Không tìm thấy tài khoản với email này.';
      } else if (e.code == 'wrong-password') {
        message = 'Mật khẩu không chính xác.';
      } else if (e.code == 'invalid-credential') {
        message = 'Email hoặc mật khẩu không chính xác.';
      } else if (e.code == 'invalid-email') {
        message = 'Định dạng email không hợp lệ.';
      } else {
        message = e.message ?? message;
      }
      onError?.call(message);
      return null;
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  // 4. Đăng xuất
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
