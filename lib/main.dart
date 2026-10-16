import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/dashboard/ana_ekran.dart';
import 'screens/auth/login_screen.dart';

const Color _kTeal = Color(0xFF00ACC1);
const Color _kBg = Color(0xFF101014);
const Color _kCard = Color(0xFF1A1A20);

// Şifre sıfırlama e-postası istendiğinde login ekranı bu anahtara zaman damgası yazar
const String _kPendingRecoveryKey = 'pending_recovery_at';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih formatı (tr_TR) verilerini yüklüyoruz
  await initializeDateFormatting('tr_TR', null);

  // Şifre sıfırlama bağlantısından mı geliyoruz?
  // Supabase.initialize, bağlantıdaki kodu işleyip olayı runApp'ten ÖNCE gönderdiği için
  // olayı dinleyerek yakalayamayız. Bunun yerine: adreste "code" var VE yakın zamanda
  // bu tarayıcıdan şifre sıfırlama istenmiş mi diye bakıyoruz.
  final prefs = await SharedPreferences.getInstance();
  final requestedAt = prefs.getInt(_kPendingRecoveryKey);
  final hasAuthCode = Uri.base.queryParameters.containsKey('code');
  final startInRecovery =
      hasAuthCode &&
      requestedAt != null &&
      DateTime.now().millisecondsSinceEpoch - requestedAt <
          2 * 60 * 60 * 1000; // 2 saat içinde istenmişse geçerli

  await Supabase.initialize(
    url: 'https://plgsxbpgbqjvrytgusjk.supabase.co',
    publishableKey: 'sb_publishable_r3cPr9t6Z_wpk90b__oGIQ_gonzAyU8',
  );

  runApp(MukellefTakipApp(startInRecovery: startInRecovery));
}

class MukellefTakipApp extends StatelessWidget {
  final bool startInRecovery;
  const MukellefTakipApp({super.key, this.startInRecovery = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mükellef Takip | Kurumsal Yönetim Sistemi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kTeal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: AuthGate(startInRecovery: startInRecovery),
    );
  }
}

class AuthGate extends StatefulWidget {
  final bool startInRecovery;
  const AuthGate({super.key, this.startInRecovery = false});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool _isPasswordRecovery;

  @override
  void initState() {
    super.initState();
    _isPasswordRecovery = widget.startInRecovery;

    // Uygulama açıkken gelen şifre sıfırlama olayları için ikinci güvence
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          setState(() => _isPasswordRecovery = true);
        }
      }
    });
  }

  Future<void> _clearRecoveryFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingRecoveryKey);
  }

  @override
  Widget build(BuildContext context) {
    if (_isPasswordRecovery) {
      return UpdatePasswordScreen(
        onPasswordUpdated: () async {
          await _clearRecoveryFlag();
          if (mounted) setState(() => _isPasswordRecovery = false);
        },
        onCancel: () async {
          await _clearRecoveryFlag();
          await Supabase.instance.client.auth.signOut();
          if (mounted) setState(() => _isPasswordRecovery = false);
        },
      );
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: _kBg,
            body: Center(child: CircularProgressIndicator(color: _kTeal)),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          return const AnaEkran();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// E-POSTADAKİ ŞİFRE SIFIRLAMA LİNKİNE TIKLANDIĞINDA AÇILAN EKRAN
class UpdatePasswordScreen extends StatefulWidget {
  final VoidCallback onPasswordUpdated;
  final VoidCallback onCancel;
  const UpdatePasswordScreen({
    super.key,
    required this.onPasswordUpdated,
    required this.onCancel,
  });

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSaving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _updatePassword() async {
    final pass = _passCtrl.text.trim();
    if (pass.length < 6) {
      _showMessage('Yeni şifreniz en az 6 karakter olmalıdır.', Colors.orange);
      return;
    }
    if (pass != _confirmCtrl.text.trim()) {
      _showMessage(
        'Girdiğiniz şifreler birbiriyle uyuşmuyor.',
        Colors.redAccent,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass),
      );
      if (!mounted) return;
      _showMessage('Şifreniz başarıyla güncellendi.', Colors.green);
      widget.onPasswordUpdated();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(
        'Şifre güncellenemedi: ${e.message}. Bağlantının süresi dolmuş olabilir; yeni bir sıfırlama bağlantısı isteyin.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Şifre güncellenemedi: $e', Colors.redAccent);
    }
  }

  InputDecoration _decoration(String label, {Widget? suffix}) {
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
        borderSide: BorderSide(
          color: _kTeal.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 500;

    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 24 : 40),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kTeal.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 8),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Yeni şifrenizi belirleyin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hesabınız için yeni bir şifre girin. Kaydettikten sonra doğrudan panele yönlendirileceksiniz.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: _decoration(
                      'Yeni şifre (en az 6 karakter)',
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white38,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: _decoration('Yeni şifre (tekrar)'),
                    onSubmitted: (_) => _updatePassword(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kTeal,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _updatePassword,
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Şifreyi Kaydet ve Giriş Yap',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isSaving ? null : widget.onCancel,
                    child: const Text(
                      'Vazgeç, giriş ekranına dön',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
