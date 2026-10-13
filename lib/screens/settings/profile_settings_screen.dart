import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  String _userRole = 'personel';
  String _companyId = '';

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      _emailController.text = user.email ?? '';

      final profileData = await supabase
          .from('profiles')
          .select('full_name, role, company_id, companies(name)')
          .eq('id', user.id)
          .single();

      _userRole = profileData['role'] ?? 'personel';
      _companyId = profileData['company_id'];

      _fullNameController.text = profileData['full_name'] ?? '';

      final companyInfo = profileData['companies'] as Map<String, dynamic>?;
      _companyNameController.text = companyInfo != null
          ? companyInfo['name']
          : '';

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Profil veri hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Profil (Kişisel) Güncellemesi
      await supabase
          .from('profiles')
          .update({'full_name': _fullNameController.text.trim()})
          .eq('id', user.id);

      // 2. Ofis Unvanı Güncellemesi (Sadece Yönetici Yapabilir)
      if (_userRole == 'admin' &&
          _companyNameController.text.trim().isNotEmpty) {
        await supabase
            .from('companies')
            .update({'name': _companyNameController.text.trim()})
            .eq('id', _companyId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Değişiklikler başarıyla kaydedildi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _companyNameController.dispose();
    super.dispose();
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
          'Profil ve Ayarlar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KİŞİSEL BİLGİLER BÖLÜMÜ
                      const Row(
                        children: [
                          Icon(Icons.person_outline, color: Color(0xFF00ACC1)),
                          SizedBox(width: 12),
                          Text(
                            'Kişisel Bilgiler',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _buildTextField(
                        controller: _fullNameController,
                        label: 'Adınız Soyadınız',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _emailController,
                        label: 'E-posta Adresi (Değiştirilemez)',
                        icon: Icons.email_outlined,
                        enabled:
                            false, // E-posta güvenliği için şu anlık kilitli
                      ),
                      const SizedBox(height: 40),

                      // OFİS BİLGİLERİ BÖLÜMÜ (Sadece Yöneticiler Düzenleyebilir)
                      const Row(
                        children: [
                          Icon(Icons.business, color: Color(0xFF00ACC1)),
                          SizedBox(width: 12),
                          Text(
                            'Ofis Bilgileri',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _buildTextField(
                        controller: _companyNameController,
                        label: 'Şirket / Ofis Unvanı',
                        icon: Icons.storefront_outlined,
                        enabled:
                            _userRole ==
                            'admin', // Personel burayı değiştiremez
                      ),

                      if (_userRole != 'admin')
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0, left: 12.0),
                          child: Text(
                            'Ofis unvanını sadece yöneticiler değiştirebilir.',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 12,
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),

                      // KAYDET BUTONU
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveSettings,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save, color: Colors.white),
                          label: Text(
                            _isSaving
                                ? 'Kaydediliyor...'
                                : 'Değişiklikleri Kaydet',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00ACC1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.white54),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(
          icon,
          color: enabled ? Colors.white30 : Colors.white12,
        ),
        filled: true,
        fillColor: enabled ? const Color(0xFF1A1A20) : const Color(0xFF101014),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00ACC1)),
        ),
      ),
    );
  }
}
