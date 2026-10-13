import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard/ana_ekran.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final supabase = Supabase.instance.client;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = false; // Beni Hatırla durumu

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _fullNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  // Cihaz hafızasından kayıtlı bilgileri çek
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  // Bilgileri cihaz hafızasına kaydet veya sil
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setString('saved_password', _passwordController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await _saveCredentials(); // Giriş başarılıysa bilgileri hafızaya yaz

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AnaEkran()),
          );
        }
      } else {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        final companyName = _companyNameController.text.trim();
        final fullName = _fullNameController.text.trim();

        if (companyName.isEmpty || fullName.isEmpty) {
          throw Exception('Lütfen şirket adını ve adınızı girin.');
        }

        final authResponse = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (authResponse.user != null) {
          final companyResponse = await supabase
              .from('companies')
              .insert({'name': companyName})
              .select()
              .single();

          final companyId = companyResponse['id'];

          await supabase.from('profiles').insert({
            'id': authResponse.user!.id,
            'company_id': companyId,
            'full_name': fullName,
            'role': 'admin',
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kayıt başarılı! Şimdi giriş yapabilirsiniz.'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() {
              _isLogin = true;
              _passwordController.clear();
            });
          }
        }
      }
    } on AuthException catch (e) {
      String errorMessage = 'Bir kimlik doğrulama hatası oluştu.';
      if (e.message.contains('User already registered') ||
          e.code == 'user_already_exists') {
        errorMessage =
            'Bu e-posta adresi zaten kullanılıyor. Lütfen "Giriş Yap" sekmesine geçin.';
      } else if (e.message.contains('Invalid login credentials')) {
        errorMessage = 'E-posta adresiniz veya şifreniz hatalı.';
      } else if (e.message.contains('Password should be at least')) {
        errorMessage =
            'Şifreniz çok zayıf. Lütfen en az 6 karakterli bir şifre belirleyin.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on PostgrestException catch (e) {
      String errorMessage = 'Veritabanı işlemi sırasında bir hata oluştu.';
      if (e.code == '42501') {
        errorMessage =
            'Kayıt Engellendi: Supabase panelinden tabloların "RLS" ayarlarını kapatmanız gerekmektedir.';
      } else {
        errorMessage =
            'Sistemsel bir sorun oluştu (${e.code}). Lütfen tekrar deneyin.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorText = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorText,
              style: const TextStyle(color: Colors.white),
            ),
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
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A20),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance,
                  color: Color(0xFF00ACC1),
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'HesapTakip',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Hesabınıza giriş yapın'
                      : 'Muhasebe ofisinizi kaydedin',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 32),

                if (!_isLogin) ...[
                  _buildTextField(
                    controller: _companyNameController,
                    label: 'Şirket/Ofis Adı',
                    icon: Icons.business,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _fullNameController,
                    label: 'Adınız Soyadınız',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                ],

                _buildTextField(
                  controller: _emailController,
                  label: 'E-posta Adresi',
                  icon: Icons.email_outlined,
                  isEmail: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Şifre',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _isLoading ? null : _submit,
                ),

                // BENİ HATIRLA ALANI
                if (_isLogin) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF00ACC1),
                        side: const BorderSide(color: Colors.white54),
                      ),
                      const Text(
                        'Beni Hatırla',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00ACC1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      if (!_rememberMe) _passwordController.clear();
                    });
                  },
                  child: Text(
                    _isLogin
                        ? 'Hesabınız yok mu? Yeni Ofis Kaydet'
                        : 'Zaten hesabınız var mı? Giriş Yapın',
                    style: const TextStyle(color: Color(0xFF00ACC1)),
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
    bool isPassword = false,
    bool isEmail = false,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      textInputAction: textInputAction ?? TextInputAction.next,
      onSubmitted: (_) => onSubmitted?.call(),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00ACC1)),
        ),
      ),
    );
  }
}
