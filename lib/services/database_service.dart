import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'notifications';

  Future<void> addNotification(NotificationModel notification) async {
    try {
      await _firestore.collection(_collectionPath).doc(notification.id).set(notification.toMap());
    } catch (e) {
      print("Bildirim ekleme hatasi: $e");
    }
  }

  Stream<List<NotificationModel>> getNotifications() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] ??= doc.id;
        return NotificationModel.fromMap(data);
      }).toList();
    });
  }

  Future<void> updateStatus(String notificationId, String newStatus) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).update({
        'status': newStatus,
      });
    } catch (e) {
      print("Durum guncelleme hatasi: $e");
    }
  }

  Future<void> updateDescription(String notificationId, String description) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).update({
        'description': description,
      });
    } catch (e) {
      print("Aciklama guncelleme hatasi: $e");
    }
  }

  Future<void> toggleFollow(String notificationId, String userId, bool follow) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).update({
        'followers': follow
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      print("Takip guncelleme hatasi: $e");
    }
  }
}
