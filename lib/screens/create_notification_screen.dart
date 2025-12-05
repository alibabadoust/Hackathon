import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';
import '../services/authentication_service.dart';

class CreateNotificationScreen extends StatefulWidget {
  @override
  _CreateNotificationScreenState createState() => _CreateNotificationScreenState();
}

class _CreateNotificationScreenState extends State<CreateNotificationScreen> {
  // form anahtari validasyon icin
  final _formKey = GlobalKey<FormState>();
  
  // metin kontrolculeri
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // bildirim türleri listesi
  final List<String> _types = ['Sağlık', 'Güvenlik', 'Teknik Arıza', 'Kayıp Eşya', 'Diğer'];
  String? _selectedType; // Seçilen türü tutar

  // servisler
  final DatabaseService _databaseService = DatabaseService();
  final AuthenticationService _authService = AuthenticationService();
  
  bool _isLoading = false;

  // rapor gonderme fonksiyonu
  void _submitReport() async {
    if (_formKey.currentState!.validate() && _selectedType != null) {
      setState(() {
        _isLoading = true;
      });

      // suanki kullaniciyi al (idsini alacak)
      var user = _authService.getCurrentUser();
      
      if (user != null) {
        // Benzersiz bir ID oluştur (Zaman damgası kullanarak basitçe)
        String reportId = DateTime.now().millisecondsSinceEpoch.toString();

        // yeni bildirim modelini olustur
        NotificationModel newReport = NotificationModel(
          id: reportId,
          userId: user.uid,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          type: _selectedType!,
          status: 'Açik', // varsayilan olarak acik baslar
          createdAt: DateTime.now(),
          imageUrl: null, 
        );

        // veritabanina kaydet
        await _databaseService.addNotification(newReport);

        // Basari mesaj gosterecek
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rapor başarıyla gönderildi!")),
        );
        
        // onceki sayfaya geri don
        Navigator.pop(context);
      }
      
      setState(() {
        _isLoading = false;
      });
    } else if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lütfen bir tür seçin!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Yeni Bildirim Olustur")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Baslik Alani
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Başlik (Ornek: Bozuk Asansor)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => value!.isEmpty ? "Başlık boş olamaz" : null,
              ),
              SizedBox(height: 16),

              // Tur Secimi(Dropdown)
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: "Bildirim Türü",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _types.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedType = val;
                  });
                },
              ),
              SizedBox(height: 16),

              // Aciklama Alani
              TextFormField(
                controller: _descController,
                maxLines: 4, // Daha buyuk alan
                decoration: InputDecoration(
                  labelText: "Detayli Aciklama",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) => value!.isEmpty ? "Aciklama bos olamaz" : null,
              ),
              SizedBox(height: 24),

              // Gönder Butonu
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submitReport,
                      icon: Icon(Icons.send),
                      label: Text("Raporu Gonder", style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}