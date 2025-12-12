import 'package:flutter/material.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import '../models/notification_model.dart';
import '../models/users_model.dart';
import 'login_screen.dart';
import 'create_notification_screen.dart';
import 'notification_detail_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel currentUser;
  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthenticationService _authService = AuthenticationService();
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedType = 'Tümü';
  bool _onlyOpen = false;
  bool _onlyFollowed = false;
  bool _onlyDepartment = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _logout() async {
    await _authService.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openEmergencyDialog() async {
    final titleController = TextEditingController(text: "Acil Durum Uyarısı");
    final descController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Acil Durum Yayınla"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Başlık"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Açıklama"),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
            ElevatedButton(
              onPressed: () async {
                final reportId = DateTime.now().millisecondsSinceEpoch.toString();
                final notification = NotificationModel(
                  id: reportId,
                  userId: widget.currentUser.uid,
                  title: titleController.text.isEmpty ? "Acil Durum Uyarısı" : titleController.text,
                  description: descController.text.isEmpty
                      ? "Tüm kullanıcılara acil bilgilendirme."
                      : descController.text,
                  type: "Acil",
                  status: "Açık",
                  createdAt: DateTime.now(),
                  imageUrl: null,
                  latitude: NotificationModel.defaultLat,
                  longitude: NotificationModel.defaultLng,
                  department: widget.currentUser.department,
                  followers: [],
                );
                await _databaseService.addNotification(notification);
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Acil durum uyarısı yayınlandı.")),
                );
              },
              child: const Text("Yayınla"),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('aç') || normalized.contains('open')) return Colors.red;
    if (normalized.contains('ince') || normalized.contains('under')) return Colors.orange;
    if (normalized.contains('çöz') || normalized.contains('res')) return Colors.green;
    return Colors.grey;
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'acil':
        return Icons.warning;
      case 'saglik':
      case 'sağlik':
      case 'sağlık':
        return Icons.health_and_safety;
      case 'guvenlik':
      case 'güvenlik':
        return Icons.shield;
      case 'teknik ariza':
      case 'teknik arıza':
        return Icons.build;
      case 'kayip esya':
      case 'kayıp eşya':
        return Icons.backpack;
      default:
        return Icons.notifications;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Şimdi";
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24) return "${diff.inHours} sa önce";
    return "${diff.inDays} gün önce";
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  Future<void> _toggleFollow(NotificationModel n, bool follow) async {
    await _databaseService.toggleFollow(n.id, widget.currentUser.uid, follow);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(follow ? "Takibe alındı" : "Takip bırakıldı")),
    );
  }

  List<NotificationModel> _applyFilters(List<NotificationModel> items) {
    final query = _searchController.text.toLowerCase();
    return items.where((n) {
      final matchType = _selectedType == 'Tümü' || _normalize(n.type) == _normalize(_selectedType);
      final statusLower = n.status.toLowerCase();
      final matchOpen = !_onlyOpen || statusLower.contains('aç') || statusLower.contains('open');
      final matchFollow = !_onlyFollowed || n.followers.contains(widget.currentUser.uid);
      final matchDept = !_onlyDepartment ||
          (n.department.isNotEmpty &&
              _normalize(n.department) == _normalize(widget.currentUser.department));
      final text = _normalize("${n.title} ${n.description}");
      final normalizedQuery = _normalize(query);
      final matchSearch = normalizedQuery.isEmpty || text.contains(normalizedQuery);
      return matchType && matchOpen && matchFollow && matchDept && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Smart Campus (${widget.currentUser.role.toUpperCase()})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: "Profil",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(currentUser: widget.currentUser),
                ),
              );
            },
          ),
          if (widget.currentUser.isAdmin)
            IconButton(
              icon: const Icon(Icons.warning_amber),
              tooltip: "Acil Uyarı Yayınla",
              onPressed: _openEmergencyDialog,
            ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: "Haritada Gör",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapScreen(currentUser: widget.currentUser),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _logout,
            tooltip: "Çıkış Yap",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Başlık veya açıklamada ara",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: "Tür",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                'Tümü',
                'Saglik',
                'Guvenlik',
                'Teknik Ariza',
                'Kayip Esya',
                'Diger'
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedType = val ?? 'Tümü'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text("Açık"),
                  selected: _onlyOpen,
                  onSelected: (v) => setState(() => _onlyOpen = v),
                ),
                FilterChip(
                  label: const Text("Takip"),
                  selected: _onlyFollowed,
                  onSelected: (v) => setState(() => _onlyFollowed = v),
                ),
                if (widget.currentUser.isAdmin)
                  FilterChip(
                    label: const Text("Departmanım"),
                    selected: _onlyDepartment,
                    onSelected: (v) => setState(() => _onlyDepartment = v),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: _databaseService.getNotifications(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text("Bir hata oluştu"));
                  }
                  final data = _applyFilters(snapshot.data ?? []);
                  if (data.isEmpty) {
                    return const Center(child: Text("Kriterlere uygun bildirim bulunamadı."));
                  }
                  return ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final n = data[index];
                      final isFollowing = n.followers.contains(widget.currentUser.uid);
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(n.status),
                            child: Icon(_typeIcon(n.type), color: Colors.white),
                          ),
                          title: Text(
                            n.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                n.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(n.status),
                                    backgroundColor: _getStatusColor(n.status).withOpacity(0.15),
                                    side: BorderSide(color: _getStatusColor(n.status)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(_timeAgo(n.createdAt), style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(isFollowing ? Icons.bookmark : Icons.bookmark_border),
                            onPressed: () => _toggleFollow(n, !isFollowing),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotificationDetailScreen(
                                  notification: n,
                                  currentUser: widget.currentUser,
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
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateNotificationScreen(currentUser: widget.currentUser),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Yeni Bildirim"),
      ),
    );
  }
}
