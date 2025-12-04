import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/users_model.dart'; 

class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanici Giris (Login)
  Future<User?> loginUser(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Giriş hatası: $e");
      return null;
    }
  }

  // Kullanici Kaydi (Register)
  Future<User?> registerUser(String email, String password, String fullName, String department) async {
    try {
      // 1. Firebase Authentication ile kullanici olustur
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;

      if (user != null) {
        // 2. Kullanici bilgilerini Firestore users koleksiyonuna kaydet
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          fullName: fullName,
          department: department,
          role: 'user', // Varsayilan rol
        );

        // users_model.dart icindeki toMap fonksiyonunu kullaniyoruz
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
      }
      
      return user;
    } catch (e) {
      print("Kayıt hatası: $e");
      return null;
    }
  }

  // Cikis Yap (Sign Out)
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Suanki kullaniciyi al
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}