import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'client_detail_screen.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _companyId = '';

  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'];

      final res = await supabase
          .from('clients')
          .select()
          .eq('company_id', _companyId)
          .order('title', ascending: true);

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteClient(Map<String, dynamic> client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Kritik Uyarı!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '${client['title']} mükellefini silmek üzeresiniz.\n\nBu mükellefe ait tüm finansal hareketler ve görevler de KALICI OLARAK SİLİNECEKTİR. Onaylıyor musunuz?',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Evet, Sil',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('clients').delete().eq('id', client['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mükellef başarıyla sistemden silindi.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchClients();
        }
      } catch (e) {
        _showUserFriendlyError(e);
      }
    }
  }

  // --- KULLANICI DOSTU HATA YÖNETİMİ (İNGİLİZCE KODLARI TÜRKÇEYE ÇEVİRİR) ---
  void _showUserFriendlyError(dynamic error) {
    if (!mounted) return;

    String errorMessage =
        'İşleminiz şu anda gerçekleştirilemiyor. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';

    if (error is PostgrestException) {
      if (error.code == 'PGRST204' || error.message.contains('schema cache')) {
        errorMessage =
            'Arka planda sistem güncellemesi yapılıyor. Lütfen sayfayı yenileyin veya 1 dakika sonra tekrar deneyin.';
      } else if (error.code == '23505') {
        errorMessage =
            'Uyarı: Girdiğiniz bilgilere sahip bir mükellef zaten sistemde kayıtlı!';
      } else if (error.message.contains('foreign key')) {
        errorMessage =
            'Bu mükellefe bağlı aktif işlemler olduğu için silinemiyor.';
      } else {
        errorMessage =
            'Sunucuyla iletişim kurulurken sistemsel bir hata oluştu. Sorun devam ederse teknik desteğe başvurun.';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showClientForm([Map<String, dynamic>? existingClient]) {
    final isEdit = existingClient != null;

    final titleController = TextEditingController(
      text: isEdit ? existingClient['title'] : '',
    );
    final contactController = TextEditingController(
      text: isEdit ? (existingClient['contact_name'] ?? '') : '',
    );
    final taxNoController = TextEditingController(
      text: isEdit ? (existingClient['tax_number'] ?? '') : '',
    );
    final taxOfficeController = TextEditingController(
      text: isEdit ? (existingClient['tax_office'] ?? '') : '',
    );
    final phoneController = TextEditingController(
      text: isEdit ? (existingClient['phone'] ?? '') : '',
    );
    final emailController = TextEditingController(
      text: isEdit ? (existingClient['email'] ?? '') : '',
    );
    final addressController = TextEditingController(
      text: isEdit ? (existingClient['address'] ?? '') : '',
    );
    final notesController = TextEditingController(
      text: isEdit ? (existingClient['notes'] ?? '') : '',
    );

    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isEdit ? 'Mükellefi Düzenle' : 'Yeni Mükellef Ekle',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: isProcessing
                ? const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00ACC1),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: SizedBox(
                      width: 600,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: titleController,
                                  label: 'Firma / Unvan Adı (*)',
                                  icon: Icons.business,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: contactController,
                                  label: 'Yetkili Adı Soyadı',
                                  icon: Icons.person,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: taxOfficeController,
                                  label: 'Vergi Dairesi',
                                  icon: Icons.account_balance,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: taxNoController,
                                  label: 'TC / Vergi Kimlik No',
                                  icon: Icons.numbers,
                                  isNumber: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: phoneController,
                                  label: 'Telefon (Örn: 555...)',
                                  icon: Icons.phone,
                                  isNumber: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: emailController,
                                  label: 'E-Posta Adresi',
                                  icon: Icons.email,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: addressController,
                            label: 'Açık Adres / İl / İlçe',
                            icon: Icons.location_on,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: notesController,
                            label: 'Mükellefe Ait Özel Notlar',
                            icon: Icons.note_alt,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
            actions: isProcessing
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'İptal',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen firma unvanını girin.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isProcessing = true);

                        final data = {
                          'company_id': _companyId,
                          'title': titleController.text.trim(),
                          'contact_name': contactController.text.trim(),
                          'tax_number': taxNoController.text.trim(),
                          'tax_office': taxOfficeController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'email': emailController.text.trim(),
                          'address': addressController.text.trim(),
                          'notes': notesController.text.trim(),
                        };

                        try {
                          if (isEdit) {
                            await supabase
                                .from('clients')
                                .update(data)
                                .eq('id', existingClient['id']);
                          } else {
                            await supabase.from('clients').insert(data);
                          }

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchClients();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Mükellef güncellendi.'
                                      : 'Yeni mükellef sisteme eklendi.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          _showUserFriendlyError(
                            e,
                          ); // Yeni akıllı hata göstericiyi çağırdık
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                      ),
                      child: Text(
                        isEdit ? 'Değişiklikleri Kaydet' : 'Sisteme Ekle',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF101014),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        title: const Text(
          'Mükellef Yönetimi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : _clients.isEmpty
          ? const Center(
              child: Text(
                'Henüz sisteme kayıtlı bir mükellefiniz bulunmuyor.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(32),
              itemCount: _clients.length,
              itemBuilder: (context, index) {
                final client = _clients[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(
                        0xFF00ACC1,
                      ).withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.business_center,
                        color: Color(0xFF00ACC1),
                      ),
                    ),
                    title: Text(
                      client['title'] ?? 'Bilinmeyen Unvan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Yetkili: ${client['contact_name'] == null || client['contact_name'].isEmpty ? '-' : client['contact_name']} • V.No: ${client['tax_number'] == null || client['tax_number'].isEmpty ? '-' : client['tax_number']}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClientDetailScreen(client: client),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      color: const Color(0xFF222222),
                      onSelected: (value) {
                        if (value == 'edit')
                          _showClientForm(client);
                        else if (value == 'delete')
                          _deleteClient(client);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Düzenle',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Sil',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClientForm(),
        backgroundColor: const Color(0xFF00ACC1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Yeni Mükellef',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
