import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/users_model.dart';
import '../services/database_service.dart';
import 'notification_detail_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  final UserModel currentUser;
  AdminPanelScreen({super.key, required this.currentUser});

  final DatabaseService _databaseService = DatabaseService();

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Şimdi";
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24) return "${diff.inHours} sa önce";
    return "${diff.inDays} gün önce";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Paneli")),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _databaseService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Bildirimler alınamadı"));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) return const Center(child: Text("Hiç bildirim yok."));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final n = items[index];
              final allowedStatuses = const ["Açık", "İnceleniyor", "Çözüldü"];
              final currentStatus = allowedStatuses.contains(n.status) ? n.status : "Açık";
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(n.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text("${n.type} • ${n.department} • ${_timeAgo(n.createdAt)}"),
                      Text("User: ${n.userId}", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  trailing: DropdownButton<String>(
                    value: currentStatus,
                    items: const [
                      DropdownMenuItem(value: "Açık", child: Text("Açık")),
                      DropdownMenuItem(value: "İnceleniyor", child: Text("İnceleniyor")),
                      DropdownMenuItem(value: "Çözüldü", child: Text("Çözüldü")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _databaseService.updateStatus(n.id, val);
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationDetailScreen(
                          notification: n,
                          currentUser: currentUser,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
