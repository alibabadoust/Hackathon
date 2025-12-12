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
      print("Giris hatasi: $e");
      return null;
    }
  }

  // Kullanici Kaydi (Register)
  Future<User?> registerUser(String email, String password, String fullName, String department) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          fullName: fullName,
          department: department,
          role: 'user', // Varsayilan rol
        );

        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
      }

      return user;
    } catch (e) {
      print("Kayit hatasi: $e");
      return null;
    }
  }

  Future<UserModel?> fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() ?? {});
    } catch (e) {
      print("Profil cekme hatasi: $e");
      return null;
    }
  }

  Future<void> saveUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      print("Profil kaydetme hatasi: $e");
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print("Sifre sifirlama mail hatasi: $e");
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
