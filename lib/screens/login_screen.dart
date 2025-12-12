import 'package:flutter/material.dart';
import '../services/authentication_service.dart';
import '../models/users_model.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthenticationService _authService = AuthenticationService();
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Lütfen tüm alanları doldurun.");
      return;
    }

    setState(() => _isLoading = true);

    final user = await _authService.loginUser(email, password);
    if (user == null) {
      _showSnack("Giriş başarısız. E-posta veya şifre hatalı.");
      setState(() => _isLoading = false);
      return;
    }

    UserModel? profile = await _authService.fetchUserProfile(user.uid);
    final wasMissingProfile = profile == null;
    profile ??= UserModel(
      uid: user.uid,
      email: user.email ?? email,
      fullName: user.displayName ?? 'Kullanıcı',
      department: '',
      role: 'user',
    );

    if (wasMissingProfile) {
      await _authService.saveUserProfile(profile);
    }

    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(currentUser: profile!)),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary.withOpacity(0.12), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_moon_outlined, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text("Akıllı Kampüs", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text("Sağlık & Güvenlik Bildirim", style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "E-posta",
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Şifre",
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text("Giriş Yap"),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ResetPasswordScreen()),
                              );
                            },
                            child: const Text("Şifreyi Unuttum"),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => RegisterScreen()),
                            );
                          },
                          child: const Text("Hesabınız yok mu? Kayıt Olun"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
