import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../dashboard/ana_ekran.dart';
import 'register_screen.dart';

// ============================================================================
// ORTAK RENKLER VE STİLLER
// ============================================================================
const Color _kTeal = Color(0xFF00ACC1);
const Color _kBg = Color(0xFF101014);
const Color _kCard = Color(0xFF1A1A20);

// LİSANS İÇİN İLETİŞİM BİLGİLERİ (kendi bilgilerinizle değiştirin)
// WhatsApp numarası: başında + ve boşluk olmadan, ülke koduyla (örn. 905321234567)
const String _kContactWhatsApp = '905079669522';
const String _kContactEmail = 'mustafakcbyk92@gmail.com';

const TextStyle _kInputText = TextStyle(
  color: Colors.white,
  fontSize: 15,
  letterSpacing: 0.2,
);

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  Color? iconColor,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: Colors.white54,
      fontSize: 14,
      letterSpacing: 0.2,
    ),
    floatingLabelStyle: const TextStyle(
      color: _kTeal,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    prefixIcon: Icon(icon, color: iconColor ?? Colors.white38, size: 22),
    suffixIcon: suffix,
    filled: true,
    fillColor: _kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _kTeal.withValues(alpha: 0.8), width: 1.2),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AnaEkran()),
          );
        }
      });
    }
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember) {
      setState(() {
        _emailController.text = prefs.getString('saved_email') ?? '';
        _passwordController.text = prefs.getString('saved_password') ?? '';
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen e-posta adresinizi ve şifrenizi girin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setString(
          'saved_password',
          _passwordController.text.trim(),
        );
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AnaEkran()),
        );
      }
    } on AuthException catch (e) {
      setState(() => _isLoading = false);
      String errorMsg = 'Giriş başarısız: ${e.message}';
      if (e.message.contains('Invalid login')) {
        errorMsg = 'E-posta adresi veya şifre hatalı.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ŞİFREMİ UNUTTUM PENCERESİ (E-POSTA İLE SIFIRLAMA BAĞLANTISI GÖNDERİR)
  void _showForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _kCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _kTeal.withValues(alpha: 0.3)),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: _kTeal, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Şifre sıfırlama',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kayıtlı e-posta adresinizi girin. Şifrenizi yenilemeniz için size güvenli bir bağlantı gönderelim.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: resetEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: _kInputText,
                    decoration: _fieldDecoration(
                      label: 'E-posta adresi',
                      icon: Icons.mail_outline_rounded,
                      iconColor: _kTeal,
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Vazgeç',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isSending
                    ? null
                    : () async {
                        final email = resetEmailCtrl.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lütfen geçerli bir e-posta adresi girin.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSending = true);
                        try {
                          await Supabase.instance.client.auth
                              .resetPasswordForEmail(
                                email,
                                redirectTo: 'https://mukelleftakip.net',
                              );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi. Lütfen gelen kutunuzu ve spam klasörünüzü kontrol edin.',
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 5),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSending = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gönderim başarısız: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                icon: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                label: const Text(
                  'Bağlantı Gönder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth < 500;

    return Scaffold(
      backgroundColor: _kBg,
      body: Row(
        children: [
          // SOL TARAF: TANITIM VİTRİNİ (MASAÜSTÜ / WEB GÖRÜNÜMÜ)
          if (isDesktop)
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 72,
                  vertical: 48,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D1B2A),
                      Color(0xFF1B263B),
                      Color(0xFF101014),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _kTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _kTeal.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'MHK YAZILIM  •  KURUMSAL OFİS YÖNETİMİ',
                        style: TextStyle(
                          color: _kTeal,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Mükellef takibi ve ofis\nyönetimi, tek panelde.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Mali müşavirlik ve danışmanlık ofisleri için tahakkuk, tahsilat, görev ve evrak yönetimini bir araya getiren platform.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16.5,
                        height: 1.65,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 44),
                    _buildFeatureItem(
                      'Otomatik periyodik tahakkuk',
                      'Aylık ve yıllık alacaklarınızı tüm mükelleflere tek adımda yansıtın; kısmi ya da tam tahsilatı kolayca takip edin.',
                    ),
                    const SizedBox(height: 24),
                    _buildFeatureItem(
                      'Cari ekstre ve ödeme hatırlatma',
                      'Tarih aralığına göre PDF ekstre hazırlayın, geciken ödemeleri WhatsApp ile hatırlatın.',
                    ),
                    const SizedBox(height: 24),
                    _buildFeatureItem(
                      'Güvenli ve izole veri yapısı',
                      'Bulut altyapısında ya da kendi sunucunuzda (On-Premise), ofisinize özel ayrı bir veri yapısıyla çalışın.',
                    ),
                    const Spacer(),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '© 2026 MHK Yazılım. Tüm hakları saklıdır.',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          'Kurumsal Sürüm v1.0',
                          style: TextStyle(
                            color: _kTeal,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // SAĞ TARAF: GİRİŞ FORMU
          Expanded(
            flex: isDesktop ? 5 : 1,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 24 : 40),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 95,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _kTeal.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.layers_rounded,
                                  color: _kTeal,
                                  size: 48,
                                ),
                              ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Hoş geldiniz',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Mükellef Takip hesabınızla oturum açın',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            letterSpacing: 0.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: _kInputText,
                          decoration: _fieldDecoration(
                            label: 'E-posta adresi',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: _kInputText,
                          decoration: _fieldDecoration(
                            label: 'Şifre',
                            icon: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white38,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () =>
                                    setState(() => _rememberMe = !_rememberMe),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (val) => setState(
                                            () => _rememberMe = val ?? false,
                                          ),
                                          activeColor: _kTeal,
                                          checkColor: Colors.white,
                                          side: const BorderSide(
                                            color: Colors.white54,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Beni hatırla',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13.5,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                'Şifremi unuttum',
                                style: TextStyle(
                                  color: _kTeal,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kTeal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CompanyRegisterScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.key_rounded,
                                color: Colors.white60,
                                size: 18,
                              ),
                              label: const Text(
                                'Lisans anahtarıyla yeni ofis kur',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegisterScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Personel misiniz? Davet koduyla katılın',
                                style: TextStyle(
                                  color: _kTeal,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Telif satırı masaüstünde sol panelde zaten var; yalnızca dar ekranda göster
                            if (!isDesktop) ...[
                              const SizedBox(height: 14),
                              const Text(
                                '© 2026 MHK Yazılım',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11.5,
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _kTeal.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: _kTeal.withValues(alpha: 0.5)),
          ),
          child: const CustomPaint(painter: _CheckPainter()),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13.5,
                  height: 1.55,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// İkon fontuna bağlı olmayan, kodla çizilen tik işareti
class _CheckPainter extends CustomPainter {
  const _CheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kTeal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.44, h * 0.67)
      ..lineTo(w * 0.73, h * 0.36);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// LİSANS KORUMALI ŞİRKET KURULUM EKRANI
// ============================================================================
class CompanyRegisterScreen extends StatefulWidget {
  const CompanyRegisterScreen({super.key});

  @override
  State<CompanyRegisterScreen> createState() => _CompanyRegisterScreenState();
}

class _CompanyRegisterScreenState extends State<CompanyRegisterScreen> {
  final supabase = Supabase.instance.client;
  final _licenseKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _customCodeController = TextEditingController();
  bool _isLoading = false;

  // SADECE ÜCRETİ ÖDEYİP BU ANAHTARI ALAN MÜŞTERİLER OFİS AÇABİLİR
  static const List<String> _validLicenseKeys = [
    'MHK2026',
    'MHK-2026-PRO',
    'MHK-KURUMSAL',
    'NHK2026',
  ];

  String _generateInviteCode(String companyName) {
    final clean = companyName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final prefix = clean.length >= 3
        ? clean.substring(0, 3)
        : (clean.isEmpty ? 'OFS' : clean);
    final randomNum = 1000 + Random().nextInt(9000);
    return '${prefix}_$randomNum';
  }

  Future<void> _registerCompany() async {
    final enteredLicense = _licenseKeyController.text.trim().toUpperCase();
    if (!_validLicenseKeys.contains(enteredLicense)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Geçersiz lisans anahtarı. Lisans almak için aşağıdaki iletişim bilgilerinden bize ulaşabilirsiniz.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _companyNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen zorunlu alanların tümünü doldurun.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifreniz en az 6 karakter olmalıdır.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final companyName = _companyNameController.text.trim();
      final adminName = _nameController.text.trim();

      final inviteCode = _customCodeController.text.trim().isNotEmpty
          ? _customCodeController.text.trim().toUpperCase().replaceAll(' ', '_')
          : _generateInviteCode(companyName);

      final authRes = await supabase.auth.signUp(
        email: email,
        password: _passwordController.text.trim(),
      );

      final user = authRes.user;
      if (user != null) {
        final companyRes = await supabase
            .from('companies')
            .insert({'name': companyName, 'invite_code': inviteCode})
            .select('id, invite_code')
            .single();

        final newCompanyId = companyRes['id'];
        final finalCode = companyRes['invite_code'] ?? inviteCode;

        await supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': adminName,
          'company_id': newCompanyId,
          'role': 'admin',
        });

        if (mounted) {
          await _showSuccessCodeDialog(companyName, finalCode);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AnaEkran()),
            );
          }
        }
      }
    } on PostgrestException catch (e) {
      String msg = 'Veritabanı hatası: ${e.message}';
      if (e.message.contains('invite_code')) {
        msg =
            'Bu şirket kodu başka bir ofis tarafından kullanılıyor. Lütfen farklı bir kod girin.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } on AuthException catch (e) {
      String msg = e.message.contains('already registered')
          ? 'Bu e-posta adresi sistemde zaten kayıtlı.'
          : 'Kayıt işlemi yapılamadı: ${e.message}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSuccessCodeDialog(
    String companyName,
    String inviteCode,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.greenAccent,
              size: 28,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ofisiniz kuruldu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lisansınız doğrulandı ve $companyName başarıyla oluşturuldu.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'ŞİRKET DAVET KODUNUZ',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kTeal),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    inviteCode,
                    style: const TextStyle(
                      color: _kTeal,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Şirket kodu kopyalandı.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Personellerinizi "Ekip Yönetimi" menüsünden kendiniz ekleyebilir veya bu kodu paylaşarak ekibinizin katılmasını sağlayabilirsiniz.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Panele Geç',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 500;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 24 : 40),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.business_rounded,
                      color: _kTeal,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Yeni ofis kurulumu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'MHK Yazılım\'ın size verdiği lisans anahtarıyla ofisinizi etkinleştirin.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 26),
                  _buildTextField(
                    'Lisans anahtarı *',
                    _licenseKeyController,
                    Icons.key_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Yönetici adı soyadı *',
                    _nameController,
                    Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Ofis / şirket unvanı *',
                    _companyNameController,
                    Icons.store_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Özel şirket kodu (boşsa otomatik üretilir)',
                    _customCodeController,
                    Icons.vpn_key_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'E-posta adresi *',
                    _emailController,
                    Icons.mail_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Şifre (en az 6 karakter) *',
                    _passwordController,
                    Icons.lock_outline_rounded,
                    obscureText: true,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerCompany,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kTeal,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Lisansı Doğrula ve Ofisi Kur',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 14),
                  const Text(
                    'Lisans anahtarınız yok mu?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Lisans satın almak veya bilgi almak için bize yazın, en kısa sürede dönüş yapalım.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _contactWhatsApp,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kTeal.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'WhatsApp ile yazın',
                        style: TextStyle(
                          color: _kTeal,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  /*
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _contactEmail,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'E-posta gönderin',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  */
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bağlantı açılamadı. Lütfen daha sonra tekrar deneyin.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bağlantı açılamadı. Lütfen daha sonra tekrar deneyin.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _contactWhatsApp() {
    final msg = Uri.encodeComponent(
      'Merhaba, Mükellef Takip için lisans anahtarı almak istiyorum.',
    );
    _openLink(Uri.parse('https://wa.me/$_kContactWhatsApp?text=$msg'));
  }

  void _contactEmail() {
    final subject = Uri.encodeComponent('Mükellef Takip lisans talebi');
    final body = Uri.encodeComponent(
      'Merhaba, Mükellef Takip için lisans anahtarı almak istiyorum.',
    );
    _openLink(Uri.parse('mailto:$_kContactEmail?subject=$subject&body=$body'));
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: _kInputText,
      decoration: _fieldDecoration(label: label, icon: icon, iconColor: _kTeal),
    );
  }
}
