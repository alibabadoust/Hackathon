import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tarih formatı için (pubspec.yaml'da intl yoksa eklemeniz gerekebilir, yoksa silebilirsiniz)
import '../models/notification_model.dart';

class NotificationDetailScreen extends StatelessWidget {
  final NotificationModel notification;

  // Kurucu metod: Tıklanan bildirimi parametre olarak alır
  const NotificationDetailScreen({Key? key, required this.notification}) : super(key: key);

  // Duruma göre renk seçimi
  Color _getStatusColor(String status) {
    if (status == 'Açık') return Colors.red;
    if (status == 'İnceleniyor') return Colors.orange;
    if (status == 'Çözüldü') return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    
    // Eğer intl paketi yoksa sadece notification.createdAt.toString() kullanabilirsiniz.
    String formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(notification.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Text("Bildirim Detayı"),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Resim Alanı (Şimdilik yer tutucu ikon)
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[200],
              child: notification.imageUrl != null
                  ? Image.network(notification.imageUrl!, fit: BoxFit.cover)
                  : Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Başlık ve Durum Etiketi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(notification.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          notification.status,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),

                  // 3. Tarih ve Tür Bilgisi
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      SizedBox(width: 5),
                      Text(formattedDate, style: TextStyle(color: Colors.grey[700])),
                      SizedBox(width: 20),
                      Icon(Icons.category, size: 16, color: Colors.grey),
                      SizedBox(width: 5),
                      Text(notification.type, style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                  Divider(height: 30),

                  // 4. Açıklama Başlığı
                  Text(
                    "Açıklama:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),

                  // 5. Açıklama Metni
                  Text(
                    notification.description,
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}