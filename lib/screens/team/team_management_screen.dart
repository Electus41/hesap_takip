import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _teamMembers = [];
  String _companyId = '';

  @override
  void initState() {
    super.initState();
    _fetchTeamMembers();
  }

  Future<void> _fetchTeamMembers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Önce yöneticinin (senin) company_id'ni bul
      final myProfile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = myProfile['company_id'];

      // Sonra bu şirkete ait TÜM profilleri (personelleri) çek
      final membersRes = await supabase
          .from('profiles')
          .select()
          .eq('company_id', _companyId)
          .order('role', ascending: true);

      if (mounted) {
        setState(() {
          _teamMembers = List<Map<String, dynamic>>.from(membersRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ekip çekilirken hata: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Personel Davet Dialogu
  void _showInviteDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'personel'; // Varsayılan rol

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Yeni Personel Davet Et',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personelin sisteme kayıt olabilmesi için e-posta adresine bir davet bağlantısı gönderilecektir.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Personel E-posta Adresi',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF101014),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.white30,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    dropdownColor: const Color(0xFF222222),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Sistem Yetkisi',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF101014),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'personel',
                        child: Text('Standart Personel (Sadece İşlem Yapar)'),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Yönetici (Ayarları Değiştirebilir)'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedRole = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'İptal',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // MVP Aşamasında davet simülasyonu yapıyoruz.
                    // Gerçek senaryoda burada 'invitations' tablosuna kayıt atılır.
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${emailController.text} adresine davetiye gönderildi!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ACC1),
                  ),
                  child: const Text(
                    'Davet Gönder',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Ekip Yönetimi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ofis Çalışanları',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sisteme erişimi olan toplam ${_teamMembers.length} personel bulunuyor.',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _teamMembers.length,
                      itemBuilder: (context, index) {
                        final member = _teamMembers[index];
                        final isMe =
                            member['id'] == supabase.auth.currentUser?.id;
                        final role = member['role'] ?? 'personel';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMe
                                  ? const Color(0xFF00ACC1).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: role == 'admin'
                                  ? Colors.redAccent.withOpacity(0.2)
                                  : Colors.blueAccent.withOpacity(0.2),
                              child: Text(
                                member['full_name'] != null
                                    ? member['full_name'][0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: role == 'admin'
                                      ? Colors.redAccent
                                      : Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  member['full_name'] ?? 'İsimsiz',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF00ACC1,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Sen',
                                      style: TextStyle(
                                        color: Color(0xFF00ACC1),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              role == 'admin'
                                  ? 'Yönetici'
                                  : 'Standart Personel',
                              style: TextStyle(
                                color: role == 'admin'
                                    ? Colors.redAccent
                                    : Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            trailing: !isMe
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () {
                                      // Personeli şirketten çıkarma (pasife alma) fonksiyonu eklenecek
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteDialog,
        backgroundColor: const Color(0xFF00ACC1),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Personel Davet Et',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
