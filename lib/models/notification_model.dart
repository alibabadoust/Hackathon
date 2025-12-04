import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String type; // ornek:saglik,guvenlik,teknik veya arıza ve...
  final String status; // open(acik),under review(inceleniyor),resolved(cozuldu)
  final String? imageUrl;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    this.imageUrl,
    required this.createdAt,
  });

  // Veriyi veritabanına kaydetmek için Map formatına çevirir
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt), // DateTime -> Timestamp dönüşümü
    };
  }

  // Veritabanından gelen veriyi modele çevirir
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'Genel',
      status: map['status'] ?? 'Open',
      imageUrl: map['imageUrl'],
      // Timestamp -> DateTime dönüşümü
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}