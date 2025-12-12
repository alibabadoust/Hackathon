import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String type; // ornek:saglik,guvenlik,teknik veya ariza
  final String status; // acik/inceleniyor/cozuldu
  final String? imageUrl;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final String department;
  final List<String> followers;

  // Ataturk Universitesi koordinatlari (varsayilan)
  static const double defaultLat = 39.9049;
  static const double defaultLng = 41.2679;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    this.imageUrl,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.department,
    this.followers = const [],
  });

  // Veriyi veritabanina kaydetmek icin Map formatina cevirir
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'latitude': latitude,
      'longitude': longitude,
      'department': department,
      'followers': followers,
    };
  }

  // Veritabanindan gelen veriyi modele cevirir
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final lat = map['latitude'];
    final lng = map['longitude'];

    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'Genel',
      status: map['status'] ?? 'Açık',
      imageUrl: map['imageUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latitude: lat is num ? lat.toDouble() : defaultLat,
      longitude: lng is num ? lng.toDouble() : defaultLng,
      department: map['department'] ?? '',
      followers: (map['followers'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
