import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/dashboard/ana_ekran.dart';
import 'screens/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih formatı (tr_TR) verilerini yüklüyoruz
  await initializeDateFormatting('tr_TR', null);

  await Supabase.initialize(
    url: 'https://plgsxbpgbqjvrytgusjk.supabase.co',
    publishableKey: 'sb_publishable_r3cPr9t6Z_wpk90b__oGIQ_gonzAyU8',
  );

  runApp(const MukellefTakipApp());
}

class MukellefTakipApp extends StatelessWidget {
  const MukellefTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mükellef Takip | Kurumsal Yönetim Sistemi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00ACC1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          setState(() => _isPasswordRecovery = true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPasswordRecovery) {
      return UpdatePasswordScreen(
        onPasswordUpdated: () {
          setState(() => _isPasswordRecovery = false);
        },
      );
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF101014),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            ),
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
  const UpdatePasswordScreen({super.key, required this.onPasswordUpdated});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSaving = false;

  Future<void> _updatePassword() async {
    final pass = _passCtrl.text.trim();
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeni şifreniz en az 6 karakter olmalıdır.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (pass != _confirmCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifreler birbiriyle eşleşmiyor!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifreniz başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onPasswordUpdated();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şifre güncellenemedi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: Center(
        child: Container(
          width: 400,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00ACC1).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_reset, color: Color(0xFF00ACC1), size: 54),
              const SizedBox(height: 16),
              const Text(
                'Yeni Şifrenizi Belirleyin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF101014),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre (Tekrar)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF101014),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ACC1),
                  ),
                  onPressed: _isSaving ? null : _updatePassword,
                  child: const Text(
                    'Şifreyi Kaydet ve Giriş Yap',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
