import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/users_model.dart';
import '../services/database_service.dart';

class NotificationDetailScreen extends StatefulWidget {
  final NotificationModel notification;
  final UserModel currentUser;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
    required this.currentUser,
  });

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late String _status;
  late TextEditingController _descController;
  late bool _isFollowing;
  final DatabaseService _databaseService = DatabaseService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.notification.status;
    const allowed = ["Açık", "İnceleniyor", "Çözüldü"];
    if (!allowed.contains(_status)) _status = "Açık";
    _descController = TextEditingController(text: widget.notification.description);
    _isFollowing = widget.notification.followers.contains(widget.currentUser.uid);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _saveAdminChanges() async {
    setState(() => _saving = true);
    await _databaseService.updateStatus(widget.notification.id, _status);
    if (_descController.text.trim() != widget.notification.description) {
      await _databaseService.updateDescription(widget.notification.id, _descController.text.trim());
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Güncellendi")));
  }

  Future<void> _toggleFollow() async {
    final newValue = !_isFollowing;
    setState(() => _isFollowing = newValue);
    await _databaseService.toggleFollow(widget.notification.id, widget.currentUser.uid, newValue);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(newValue ? "Takibe alındı" : "Takip bırakıldı")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final isAdmin = widget.currentUser.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text("Bildirim Detayı")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                n.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(n.type)),
                  Chip(label: Text(_status)),
                  if (n.department.isNotEmpty) Chip(label: Text(n.department)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                readOnly: !isAdmin,
                decoration: const InputDecoration(
                  labelText: "Açıklama",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text("Oluşturulma: ${_formatDate(n.createdAt)}"),
              const SizedBox(height: 8),
              Text("Konum: ${n.latitude.toStringAsFixed(5)}, ${n.longitude.toStringAsFixed(5)}"),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleFollow,
                    icon: Icon(_isFollowing ? Icons.bookmark_remove : Icons.bookmark_add),
                    label: Text(_isFollowing ? "Takibi Bırak" : "Takip Et"),
                  ),
                  const SizedBox(width: 12),
                  if (isAdmin)
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: "Durum",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: "Açık", child: Text("Açık")),
                          DropdownMenuItem(value: "İnceleniyor", child: Text("İnceleniyor")),
                          DropdownMenuItem(value: "Çözüldü", child: Text("Çözüldü")),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (isAdmin)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveAdminChanges,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text("Kaydet"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
