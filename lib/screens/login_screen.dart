import 'package:flutter/material.dart';
import '../services/authentication_service.dart'; // Servisimizi import ediyoruz
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Metin kutularını kontrol etmek için controller'lar
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Servis sınıfımızdan bir nesne oluşturuyoruz
  final AuthenticationService _authService = AuthenticationService();

  // Giriş yapma fonksiyonu
  void _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lütfen tüm alanları doldurun!")),
      );
      return;
    }

    // Servis üzerinden giriş yapmayı dene
    var user = await _authService.loginUser(email, password);

    if (user != null) {
         print("Giriş Başarılı: ${user.email}");
      
     
        Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
      
    } else
     {
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Giriş Başarısız! E-posta veya şifre hatalı.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Kampüs Giriş")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // E-posta alanı
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "E-posta",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            SizedBox(height: 16),
            
            // Şifre alanı
            TextField(
              controller: _passwordController,
              obscureText: true, // Şifreyi gizle
              decoration: InputDecoration(
                labelText: "Şifre",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            SizedBox(height: 24),

            // Giriş Butonu
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50), // Tam genişlik
              ),
              child: Text("Giriş Yap", style: TextStyle(fontSize: 18)),
            ),
            
            SizedBox(height: 12),
            
            // Kayıt Ol linki (Şimdilik boş)
            TextButton(
              onPressed: () {
               Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                );
              },
              child: Text("Hesabiniz yok mu? Kayit Olun"),
            ),
          ],
        ),
      ),
    );
  }
}