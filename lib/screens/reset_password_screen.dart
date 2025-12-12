import 'package:flutter/material.dart';
import '../services/authentication_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AuthenticationService _authService = AuthenticationService();
  bool _isLoading = false;

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack("E-posta zorunlu");
      return;
    }
    setState(() => _isLoading = true);
    final ok = await _authService.sendPasswordReset(email);
    setState(() => _isLoading = false);
    final message = ok
        ? "E-posta adresinize şifre sıfırlama bağlantısı gönderildi (simülasyon)."
        : "Şifre sıfırlama isteği gönderilemedi. Lütfen e-postayı kontrol edin.";
    _showSnack(message);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Şifre Sıfırlama")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("E-postanızı girin, size şifre sıfırlama bağlantısı göndereceğiz.",
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "E-posta",
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendReset,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Bağlantıyı Gönder"),
              ),
            ),
            const SizedBox(height: 12),
            const Text("Not: Bu ekran değerlendirme için simülasyon amaçlıdır."),
          ],
        ),
      ),
    );
  }
}
