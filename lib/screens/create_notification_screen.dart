import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/notification_model.dart';
import '../models/users_model.dart';
import '../services/database_service.dart';
import '../services/authentication_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CreateNotificationScreen extends StatefulWidget {
  final UserModel currentUser;
  const CreateNotificationScreen({super.key, required this.currentUser});

  @override
  _CreateNotificationScreenState createState() => _CreateNotificationScreenState();
}

class _CreateNotificationScreenState extends State<CreateNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _latController =
      TextEditingController(text: NotificationModel.defaultLat.toString());
  final TextEditingController _lngController =
      TextEditingController(text: NotificationModel.defaultLng.toString());

  final List<String> _types = ['Acil', 'Saglik', 'Guvenlik', 'Teknik Ariza', 'Kayip Esya', 'Diger'];
  String? _selectedType;

  final DatabaseService _databaseService = DatabaseService();
  final AuthenticationService _authService = AuthenticationService();
  
  bool _isLoading = false;
  LatLng? _selectedPoint;
  bool _locating = false;
  XFile? _pickedImage;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konum izni verilmedi. Haritadan seçebilirsiniz.")),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      _setPointFromMap(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konum alınamadı. Haritadan seçin.")),
      );
    } finally {
      setState(() => _locating = false);
    }
  }

  Future<void> _submitReport() async {
    if (!(_formKey.currentState?.validate() ?? false) || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm bilgileri doldurun ve tür seçin.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = _authService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Oturum bulunamadı.")),
      );
      setState(() => _isLoading = false);
      return;
    }

    final latitude = double.tryParse(_latController.text.trim());
    final longitude = double.tryParse(_lngController.text.trim());
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Geçerli enlem/boylam girin.")),
      );
      setState(() => _isLoading = false);
      return;
    }

    final reportId = DateTime.now().millisecondsSinceEpoch.toString();
    String? imageUrl;

    if (_pickedImage != null) {
      try {
        setState(() => _uploadingImage = true);
        final ref = FirebaseStorage.instance.ref('notification_images/$reportId.jpg');
        if (kIsWeb) {
          final bytes = await _pickedImage!.readAsBytes();
          await ref.putData(bytes);
        } else {
          await ref.putFile(File(_pickedImage!.path));
        }
        imageUrl = await ref.getDownloadURL();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fotoğraf yüklenemedi, bildiriminiz resimsiz kaydedildi.")),
        );
      } finally {
        setState(() => _uploadingImage = false);
      }
    }

    final notification = NotificationModel(
      id: reportId,
      userId: user.uid,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      type: _selectedType!,
      status: 'Açık',
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      department: widget.currentUser.department,
      followers: [user.uid],
    );

    await _databaseService.addNotification(notification);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Rapor başarıyla gönderildi!")),
    );

    setState(() => _isLoading = false);
    Navigator.pop(context);
  }

  void _setPointFromMap(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _latController.text = point.latitude.toStringAsFixed(6);
      _lngController.text = point.longitude.toStringAsFixed(6);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Yeni Bildirim Oluştur")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Başlık (Örnek: Bozuk Asansör)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => value == null || value.isEmpty ? "Başlık boş olamaz" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: "Bildirim Türü",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _types.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedType = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Detaylı Açıklama",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) => value == null || value.isEmpty ? "Açıklama boş olamaz" : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                      if (picked != null) {
                        setState(() => _pickedImage = picked);
                      }
                    },
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text("Fotoğraf Ekle (opsiyonel)"),
                  ),
                  const SizedBox(width: 12),
                  if (_pickedImage != null) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              if (_pickedImage != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(_pickedImage!.path, height: 120, fit: BoxFit.cover)
                      : Image.file(File(_pickedImage!.path), height: 120, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 16),
              Text("Konum seçin (cihaz konumu veya harita):",
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    label: const Text("Konumumu Kullan"),
                  ),
                  const SizedBox(width: 12),
                  Text("Ya da haritadan noktaya dokun.", style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(NotificationModel.defaultLat, NotificationModel.defaultLng),
                      initialZoom: 15,
                      onTap: (tapPosition, point) => _setPointFromMap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.smart_campus',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint ??
                                LatLng(NotificationModel.defaultLat, NotificationModel.defaultLng),
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_pin, size: 36, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Enlem (lat)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (value) => value == null || value.isEmpty ? "Enlem zorunlu" : null,
                      onChanged: (val) {
                        final lat = double.tryParse(val);
                        final lng = double.tryParse(_lngController.text);
                        if (lat != null && lng != null) {
                          _selectedPoint = LatLng(lat, lng);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Boylam (lng)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_searching),
                      ),
                      validator: (value) => value == null || value.isEmpty ? "Boylam zorunlu" : null,
                      onChanged: (val) {
                        final lat = double.tryParse(_latController.text);
                        final lng = double.tryParse(val);
                        if (lat != null && lng != null) {
                          _selectedPoint = LatLng(lat, lng);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submitReport,
                      icon: const Icon(Icons.send),
                      label: const Text("Raporu Gönder"),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
