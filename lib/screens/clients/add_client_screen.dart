import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _taxNoController = TextEditingController();
  final _taxOfficeController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'Oturum açmış kullanıcı bulunamadı.';

      // Kullanıcının bağlı olduğu company_id'yi profilden alalım
      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();

      final companyId = profile['company_id'];
      if (companyId == null) throw 'Kullanıcıya ait bir şirket ID bulunamadı.';

      await supabase.from('clients').insert({
        'company_id': companyId,
        'title': _titleController.text.trim(),
        'tax_no': _taxNoController.text.trim(),
        'tax_office': _taxOfficeController.text.trim(),
        'contact_name': _contactNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mükellef başarıyla eklendi!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kayıt Hatası: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _taxNoController.dispose();
    _taxOfficeController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
          'Yeni Mükellef Ekle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : SingleChildScrollView(
              // Üst kısımdaki etiketin kesilmesini önlemek için üstten boşluk bırakıldı
              padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModernTextField(
                      controller: _titleController,
                      label: 'Unvan / Ad Soyad (*)',
                      icon: Icons.business,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Zorunlu alan' : null,
                    ),
                    const SizedBox(height: 16),

                    // Yan Yana İki Alan
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernTextField(
                            controller: _taxNoController,
                            label: 'Vergi No / TCKN',
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMODernTextFieldForOffice(
                            controller: _taxOfficeController,
                            label: 'Vergi Dairesi',
                            icon: Icons.account_balance,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildModernTextField(
                      controller: _contactNameController,
                      label: 'İletişim Kişisi (Yetkili)',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),

                    _buildModernTextField(
                      controller: _phoneController,
                      label: 'Telefon',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    _buildModernTextField(
                      controller: _emailController,
                      label: 'E-posta Adresi',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _saveClient,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: label, // Etiketi hintText yaparak kutunun içine sabitliyoruz
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white30, size: 20),
        filled: true,
        fillColor: const Color(0xFF1A1A20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00ACC1)),
        ),
      ),
    );
  }

  Widget _buildMODernTextFieldForOffice({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return _buildModernTextField(
      controller: controller,
      label: label,
      icon: icon,
    );
  }
}
