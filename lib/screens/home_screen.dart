import 'package:flutter/material.dart';
import '../services/authentication_service.dart';
import 'login_screen.dart';
import 'create_notification_screen.dart'; 

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthenticationService _authService = AuthenticationService();

  // Çıkış yapma fonksiyonu
  void _logout() async {
    await _authService.signOut();
   
    // cikis yapinca Login sayfasina geri don ve gecmisi sil
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Smart Campus"),
        actions: [
          // cikis butonu
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _logout,
            tooltip: "Çıkış Yap",
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              "Hoş Geldiniz!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("Başarıyla giriş yaptınız."),
          ],
        ),
      ),
      // + Butonu eklemek icin
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // rapor olusturma sayfasina gidiceksin
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateNotificationScreen()),
          );
        },
        child: Icon(Icons.add),
        tooltip: "Yeni Bildirim Ekle",
      ),
    );
  }
}