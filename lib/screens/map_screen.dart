import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/notification_model.dart';
import '../models/users_model.dart';
import '../services/database_service.dart';
import 'notification_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final UserModel currentUser;
  const MapScreen({super.key, required this.currentUser});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final DatabaseService _databaseService = DatabaseService();
  NotificationModel? _selected;

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'saglik':
      case 'sağlik':
      case 'sağlık':
      case 'acil':
        return Colors.redAccent;
      case 'guvenlik':
      case 'güvenlik':
        return Colors.orangeAccent;
      case 'teknik ariza':
      case 'teknik arıza':
        return Colors.blueAccent;
      case 'kayip esya':
      case 'kayıp esya':
        return Colors.purpleAccent;
      default:
        return Colors.green;
    }
  }

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
      appBar: AppBar(
        title: const Text("Harita"),
        actions: [
          if (_selected != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: "Kartı Kapat",
              onPressed: () => setState(() => _selected = null),
            ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _databaseService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Harita verisi alınamadı"));
          }

          final notifications = snapshot.data ?? [];
          final List<Marker> markers = notifications.map<Marker>((n) {
            return Marker(
              point: LatLng(n.latitude, n.longitude),
              width: 36,
              height: 36,
              child: GestureDetector(
                onTap: () => setState(() => _selected = n),
                child: Icon(
                  Icons.location_pin,
                  size: 32,
                  color: _getTypeColor(n.type),
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(NotificationModel.defaultLat, NotificationModel.defaultLng),
                  initialZoom: 15,
                  onTap: (_, __) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.smart_campus',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
              if (_selected != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selected!.type,
                              style: TextStyle(fontWeight: FontWeight.bold, color: _getTypeColor(_selected!.type)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selected!.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(_timeAgo(_selected!.createdAt), style: TextStyle(color: Colors.grey[700])),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    if (_selected == null) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => NotificationDetailScreen(
                                          notification: _selected!,
                                          currentUser: widget.currentUser,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text("Detayı Gör"),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
