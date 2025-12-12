class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String department;
  final String role; //user veya admin

  bool get isAdmin => role.toLowerCase() == 'admin';

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.department,
    required this.role,
  });

  // Veriyi Firebase formatına (Map) dönüştürme fonksiyonu
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'department': department,
      'role': role,
    };
  }

  // Firebase'den gelen veriyi UserModel sınıfına dönüştürme fonksiyonu
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      department: map['department'] ?? '',
      role: map['role'] ?? 'user', // Varsayılan rol 'user' olarak ayarlandı
    );
  }
}
