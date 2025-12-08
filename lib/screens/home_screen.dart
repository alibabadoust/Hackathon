import 'package:flutter/material.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart'; // Veritabani servisini 
import '../models/notification_model.dart'; 
import 'login_screen.dart';
import 'create_notification_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthenticationService _authService = AuthenticationService();
  final DatabaseService _databaseService = DatabaseService(); // Veritabani servis nesnesi

  // Çıkış yapma fonksiyonu
  void _logout() async {
    await _authService.signOut();
    // Çıkış yapınca Login sayfasına geri dön ve geçmişi temizle
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  // Bildirim durumuna göre renk seçimi
  Color _getStatusColor(String status) {
    if (status == 'Açık') return Colors.red;      // 'Açık' durumu için kırmızı
    if (status == 'İnceleniyor') return Colors.orange; // 'İnceleniyor' durumu için turuncu
    if (status == 'Çözüldü') return Colors.green; // 'Çözüldü' durumu için yeşil
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Smart Campus"),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _logout,
            tooltip: "Çıkış Yap",
          ),
        ],
      ),
      // StreamBuilder: Veritabanındaki değişiklikleri anlık olarak dinler
      body: StreamBuilder<List<NotificationModel>>(
        stream: _databaseService.getNotifications(),
        builder: (context, snapshot) {
          // Veri yukleniyor 
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          
          if (snapshot.hasError) {
            return Center(child: Text("Bir hata oluştu!"));
          }

          //  Durum: Hiç veri yok Liste bos gozukecek
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 60, color: Colors.grey),
                  Text("Henüz bildirim yok."),
                ],
              ),
            );
          }

          //  Veriler geldi, listeyi goster
          List<NotificationModel> notifications = snapshot.data!;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notification = notifications[index];
              
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 3,
                child: ListTile(
                  // Durum ikonu Reng duruma gore degisicek
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(notification.status),
                    child: Icon(Icons.report_problem, color: Colors.white),
                  ),
                  // Bildirim basligi
                  title: Text(
                    notification.title,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // Tur ve Durum
                  subtitle: Text("${notification.type} • ${notification.status}"),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Buraya tiklandiginda detay sayfasi acilacak
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Detaylar yakında...")),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      // Yeni bildirim ekleme butonu
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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