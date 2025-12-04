import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Bu dosya flutterfire configure ile olusturuldu
import 'screens/login_screen.dart'; // Giris ekranini import ediyoruz

void main() async {
  // 1. Flutter motorunun hazır oldugundan emin ol
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebasei baslat(Platforma ozel ayarlarla)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Uygulamayi çalistir
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Campus',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        // Uygulamanin ana renk temasi 
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Uygulama açıldiginda gosterilecek ilk ekran
      home: LoginScreen(),
    );
  }
}