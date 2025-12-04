import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart'; 

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'notifications'; // Koleksiyon adi

  // 1. Yeni bildirim ekle (Create)
  // Kullanici yeni bir olay bildirdiginde bu fonksiyon calisicak
  Future<void> addNotification(NotificationModel notification) async {
    try {
      // Belge id'si(notification.id) ile veritabanina kaydet
      await _firestore.collection(_collectionPath).doc(notification.id).set(notification.toMap());
    } catch (e) {
      print("Bildirim ekleme hatası: $e");
    }
  }

  // 2. Tum bildirimleri getir (read-realtime stream)
  // Veritabanindaki degisiklikleri anlik olarak dinler (canli takip)
  Stream<List<NotificationModel>> getNotifications() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true) // En yeniden eskiye sirala
        .snapshots()
        .map((snapshot) {
      // Gelen verileri listeye cevir
      return snapshot.docs.map((doc) {
        return NotificationModel.fromMap(doc.data());
      }).toList();
    });
  }

  // 3. Bildirim durumunu guncelle (update-admin)
  // Admin acikdurumunu cozuldu yaparken burasi calısır duruma dondurebilir
  Future<void> updateStatus(String notificationId, String newStatus) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).update({
        'status': newStatus,
      });
    } catch (e) {
      print("Durum güncelleme hatası: $e");
    }
  }
}