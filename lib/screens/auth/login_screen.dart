import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'splash_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // true: Đang ở chế độ Đăng nhập; false: Đang ở chế độ Đăng ký
  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Điều hướng sau khi đăng nhập thành công
  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SplashScreen()),
      (route) => false,
    );
  }

  // Xử lý gửi Form (Email & Password)
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    if (_isLoginMode) {
      // Đăng nhập
      final user = await _authService.loginWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        onError: _showErrorSnackBar,
      );

      setState(() {
        _isLoading = false;
      });

      if (user != null) {
        _navigateToHome();
      }
    } else {
      // Đăng ký
      final user = await _authService.registerWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        onError: _showErrorSnackBar,
      );

      setState(() {
        _isLoading = false;
      });

      if (user != null) {
        _showSuccessSnackBar('Tạo tài khoản thành công!');
        _navigateToHome();
      }
    }
  }

  // Xử lý Đăng nhập Google
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    final user = await _authService.signInWithGoogle(
      onError: _showErrorSnackBar,
    );

    setState(() {
      _isLoading = false;
    });

    if (user != null) {
      _navigateToHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBrown = Color(0xFF6D4C41);
    const bgCream = Color(0xFFFAF6F0);

    return Scaffold(
      backgroundColor: bgCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Logo & Tên Quán
                    const Icon(
                      Icons.local_cafe_rounded,
                      size: 70,
                      color: primaryBrown,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tiệm Trà Nhỏ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLoginMode
                          ? 'Đăng nhập để đặt trà sữa ngay'
                          : 'Tạo tài khoản mới cùng thưởng thức trà sữa',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown.shade400,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Card Form chứa các Input
                    Card(
                      elevation: 3,
                      shadowColor: Colors.brown.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(22.0),
                        child: Column(
                          children: [
                            // 1. Trường Họ và tên (chỉ hiện khi Đăng ký)
                            if (!_isLoginMode) ...[
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Họ và tên',
                                  prefixIcon: const Icon(Icons.person_outline, color: primaryBrown),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryBrown, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập họ và tên';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 2. Trường Email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined, color: primaryBrown),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: primaryBrown, width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vui lòng nhập email';
                                }
                                if (!value.contains('@') || !value.contains('.')) {
                                  return 'Email không hợp lệ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // 3. Trường Mật khẩu
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                prefixIcon: const Icon(Icons.lock_outline, color: primaryBrown),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: primaryBrown, width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập mật khẩu';
                                }
                                if (value.length < 6) {
                                  return 'Mật khẩu phải từ 6 ký tự trở lên';
                                }
                                return null;
                              },
                            ),

                            // 4. Trường Xác nhận mật khẩu (chỉ hiện khi Đăng ký)
                            if (!_isLoginMode) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Xác nhận mật khẩu',
                                  prefixIcon: const Icon(Icons.lock_reset_outlined, color: primaryBrown),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword = !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryBrown, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value != _passwordController.text) {
                                    return 'Mật khẩu xác nhận không khớp';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 22),

                            // Nút Submit chính (Đăng nhập / Đăng ký)
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(color: primaryBrown),
                                  )
                                : ElevatedButton(
                                    onPressed: _handleSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryBrown,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      _isLoginMode ? 'Đăng Nhập' : 'Tạo Tài Khoản',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Divider "HOẶC"
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.brown.shade200)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'HOẶC',
                            style: TextStyle(
                              color: Colors.brown.shade400,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.brown.shade200)),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Nút Đăng nhập bằng Google
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(color: Colors.brown.shade200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 1,
                      ),
                      icon: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                        width: 22,
                        height: 22,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.g_mobiledata,
                          color: Colors.red,
                          size: 28,
                        ),
                      ),
                      label: const Text(
                        'Tiếp tục với Google',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Chuyển đổi giữa Đăng nhập <-> Đăng ký
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLoginMode ? 'Chưa có tài khoản?' : 'Đã có tài khoản?',
                          style: TextStyle(color: Colors.brown.shade600),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                              _formKey.currentState?.reset();
                            });
                          },
                          child: Text(
                            _isLoginMode ? 'Đăng ký ngay' : 'Đăng nhập',
                            style: const TextStyle(
                              color: primaryBrown,
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
          ),
        ),
      ),
    );
  }
}
