import 'package:flutter/material.dart';
import '../models/users_model.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel currentUser;
  const ProfileScreen({super.key, required this.currentUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool pushEnabled = true;
  bool emailEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profil & Ayarlar")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(widget.currentUser.fullName),
              subtitle: Text(widget.currentUser.email),
              trailing: Chip(label: Text(widget.currentUser.role)),
            ),
            const SizedBox(height: 12),
            Text("Birim: ${widget.currentUser.department.isEmpty ? 'Belirtilmedi' : widget.currentUser.department}"),
            const SizedBox(height: 24),
            const Text("Bildirim Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text("Push bildirimleri"),
              value: pushEnabled,
              onChanged: (v) => setState(() => pushEnabled = v),
            ),
            SwitchListTile(
              title: const Text("E-posta bilgilendirmesi"),
              value: emailEnabled,
              onChanged: (v) => setState(() => emailEnabled = v),
            ),
            const SizedBox(height: 12),
            const Text("Not: Bu ayarlar demo amaçlıdır, gerçek bildirim servisine bağlayabilirsiniz."),
          ],
        ),
      ),
    );
  }
}
