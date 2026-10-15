import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _companyId = '';
  String _companyName = '';
  String _inviteCode = '';
  String _currentUserId = '';
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _fetchTeam();
  }

  Future<void> _fetchTeam() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      _currentUserId = user.id;

      final profile = await supabase
          .from('profiles')
          .select('full_name, company_id, companies(name, invite_code)')
          .eq('id', user.id)
          .single();

      _companyId = profile['company_id'];
      final comp = profile['companies'] as Map<String, dynamic>?;
      _companyName = comp?['name'] ?? 'Ofis';
      _inviteCode = comp?['invite_code'] ?? _companyId;

      final teamRes = await supabase
          .from('profiles')
          .select('id, full_name, role')
          .eq('company_id', _companyId)
          .order('role', ascending: true);

      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(teamRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getFriendlyErrorMessage(dynamic error) {
    final errStr = error.toString();
    if (errStr.contains('EMAIL_EXISTS') ||
        errStr.contains('already registered') ||
        errStr.contains('unique constraint')) {
      return 'Bu e-posta adresi sistemde zaten kayıtlı! Lütfen farklı bir e-posta girin.';
    }
    if (errStr.contains('create_personnel_account')) {
      return 'Veritabanı fonksiyonu güncel değil. Lütfen Supabase SQL Editor\'de güncel personel oluşturma kodunu çalıştırın.';
    }
    if (errStr.contains('Failed to fetch') ||
        errStr.contains('SocketException')) {
      return 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.';
    }
    return 'İşlem sırasında beklenmeyen bir durum oluştu. Lütfen bilgileri kontrol edip tekrar deneyin.';
  }

  // ŞİRKET DAVET KODUNU DOĞRUDAN BU EKRANDAN DÜZENLEME PENCERESİ
  void _showEditInviteCodeDialog() {
    final codeCtrl = TextEditingController(text: _inviteCode);
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A20),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 40,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.vpn_key, color: Color(0xFF00ACC1)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Şirket Davet Kodunu Değiştir',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? screenWidth : 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personellerinizin kayıt olurken kullanacağı özel şirket kodunu aşağıdan belirleyebilirsiniz (Örn: MHK_2026):',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeCtrl,
                    style: const TextStyle(
                      color: Color(0xFF00ACC1),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Yeni Şirket Kodu',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.edit,
                        color: Color(0xFF00ACC1),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF101014),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton.icon(
                onPressed: isUpdating
                    ? null
                    : () async {
                        final newCode = codeCtrl.text
                            .trim()
                            .toUpperCase()
                            .replaceAll(' ', '_');
                        if (newCode.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Şirket kodu boş bırakılamaz!'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isUpdating = true);

                        try {
                          await supabase
                              .from('companies')
                              .update({'invite_code': newCode})
                              .eq('id', _companyId);

                          if (mounted) {
                            setState(() => _inviteCode = newCode);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Şirket davet kodu "$newCode" olarak güncellendi!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isUpdating = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bu kod başka bir şirket tarafından kullanılıyor olabilir. Lütfen farklı bir kod deneyin.',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.save, color: Colors.white, size: 18),
                label: Text(
                  isUpdating ? 'Kaydediliyor...' : 'Kodu Kaydet',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // MEVCUT EKİP ÜYESİNİN YETKİSİNİ DEĞİŞTİRME (YÖNETİCİ <-> PERSONEL)
  Future<void> _changeMemberRole(
    String memberId,
    String memberName,
    String newRole,
  ) async {
    try {
      await supabase
          .from('profiles')
          .update({'role': newRole})
          .eq('id', memberId);
      await _fetchTeam();
      if (mounted) {
        final roleTitle = newRole == 'admin'
            ? 'Tam Yetkili Yönetici'
            : 'Personel';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$memberName adlı kişinin yetkisi "$roleTitle" olarak güncellendi.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yetki güncellenirken bir hata oluştu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // MOBİL VE WEB UYUMLU TAM GENİŞLİKTE YENİ EKİP ÜYESİ OLUŞTURMA PENCERESİ
  void _showCreatePersonnelDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'personel';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A20),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 40,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1, color: Color(0xFF00ACC1)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Yeni Ekip Üyesi Oluştur',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: isMobile ? screenWidth : 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ekip üyesinin bilgilerini, şifresini ve yetki düzeyini belirleyin. Hesap anında sizin ofisinize bağlı olarak açılacaktır.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Adı Soyadı',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.white38,
                        ),
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
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'E-Posta Adresi',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.email,
                          color: Colors.white38,
                        ),
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
                      controller: passwordCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Başlangıç Şifresi (En az 6 hane)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF101014),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF222222),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Sistem Yetki Seviyesi',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: Icon(
                          selectedRole == 'admin'
                              ? Icons.admin_panel_settings
                              : Icons.badge_outlined,
                          color: selectedRole == 'admin'
                              ? Colors.redAccent
                              : const Color(0xFF00ACC1),
                        ),
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
                          child: Text(
                            'Standart Personel (İşlem & Takip Yetkisi)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(
                            'Yönetici (Tam Yetkili - Her Şeye Müdahale Edebilir)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            (selectedRole == 'admin'
                                    ? Colors.redAccent
                                    : Colors.blueAccent)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: selectedRole == 'admin'
                                ? Colors.redAccent
                                : Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedRole == 'admin'
                                  ? 'Yönetici: Şirket ayarlarını değiştirebilir, personel ekleyip çıkarabilir ve tüm finansal verilere tam müdahale edebilir.'
                                  : 'Personel: Mükellef, tahsilat, evrak ve görev işlemlerini yürütebilir; şirket ayarlarına ve ekip yönetimine giremez.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: isSaving
                ? [
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF00ACC1),
                      ),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'İptal',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final password = passwordCtrl.text.trim();

                        if (name.isEmpty ||
                            email.isEmpty ||
                            !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lütfen personelin adını ve geçerli bir e-posta adresini girin.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        if (password.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Başlangıç şifresi en az 6 karakter olmalıdır.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          await supabase.rpc(
                            'create_personnel_account',
                            params: {
                              'p_email': email,
                              'p_password': password,
                              'p_full_name': name,
                              'p_company_id': _companyId,
                              'p_role': selectedRole,
                            },
                          );

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchTeam();
                            _showCredentialsCreatedDialog(
                              name,
                              email,
                              password,
                              selectedRole,
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_getFriendlyErrorMessage(e)),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Hesabı Oluştur',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  void _showCredentialsCreatedDialog(
    String name,
    String email,
    String password,
    String role,
  ) {
    final roleName = role == 'admin' ? 'Yönetici (Tam Yetkili)' : 'Personel';
    final shareText =
        '''Merhaba $name,
$_companyName ofisi Mükellef Takip sistemi hesabınız oluşturulmuştur.

Yetki Seviyesi: $roleName
Giriş E-Postanız: $email
Şifreniz: $password''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hesap Oluşturuldu!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
              '$name artık "$roleName" yetkisiyle $_companyName ekibinde! Aşağıdaki giriş bilgilerini kopyalayıp kendisine iletebilirsiniz:',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                shareText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: shareText));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Giriş bilgileri kopyalandı!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.copy, color: Colors.white, size: 18),
            label: const Text(
              'Bilgileri Kopyala',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ACC1),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Ekipten Çıkar',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '$name isimli kullanıcıyı ofis ekibinizden çıkarmak istediğinize emin misiniz?',
          style: const TextStyle(color: Colors.white70),
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
              'Ekibimden Çıkar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.from('profiles').update({'company_id': null}).eq('id', id);
      _fetchTeam();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        title: const Text(
          'Ekip & Yetki Yönetimi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00ACC1).withValues(alpha: 0.4),
                      ),
                    ),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ŞİRKET DAVET KODUNUZ',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _inviteCode,
                                      style: const TextStyle(
                                        color: Color(0xFF00ACC1),
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy,
                                          color: Colors.white70,
                                        ),
                                        tooltip: 'Kodu Kopyala',
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: _inviteCode),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Şirket kodu kopyalandı!',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Color(0xFF00ACC1),
                                        ),
                                        tooltip: 'Kodu Değiştir',
                                        onPressed: _showEditInviteCodeDialog,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _showCreatePersonnelDialog,
                                  icon: const Icon(
                                    Icons.person_add,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Yeni Ekip Üyesi Oluştur',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00ACC1),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ŞİRKET DAVET KODUNUZ (Kalem İkonuna Tıklayarak Değiştirebilirsiniz)',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        _inviteCode,
                                        style: const TextStyle(
                                          color: Color(0xFF00ACC1),
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy,
                                          color: Colors.white70,
                                        ),
                                        tooltip: 'Kodu Kopyala',
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: _inviteCode),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Şirket kodu kopyalandı!',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Color(0xFF00ACC1),
                                        ),
                                        tooltip: 'Şirket Kodunu Değiştir',
                                        onPressed: _showEditInviteCodeDialog,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _showCreatePersonnelDialog,
                                icon: const Icon(
                                  Icons.person_add,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Yeni Ekip Üyesi Oluştur',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ACC1),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Kayıtlı Ekip Üyeleri & Yetkiler',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final m = _members[index];
                        final isAdmin = m['role'] == 'admin';
                        final isMe = m['id'] == _currentUserId;
                        final memberName = m['full_name'] ?? 'İsimsiz';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAdmin
                                  ? Colors.redAccent.withValues(alpha: 0.15)
                                  : const Color(
                                      0xFF00ACC1,
                                    ).withValues(alpha: 0.15),
                              child: Icon(
                                isAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                                color: isAdmin
                                    ? Colors.redAccent
                                    : const Color(0xFF00ACC1),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    memberName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  const Text(
                                    '(Siz)',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              isAdmin
                                  ? 'Tam Yetkili Yönetici (Her şeye müdahale edebilir)'
                                  : 'Standart Personel',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdmin
                                        ? Colors.redAccent.withValues(
                                            alpha: 0.2,
                                          )
                                        : Colors.blueAccent.withValues(
                                            alpha: 0.2,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isAdmin ? 'Yönetici' : 'Personel',
                                    style: TextStyle(
                                      color: isAdmin
                                          ? Colors.redAccent
                                          : Colors.blueAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (!isMe) ...[
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.white54,
                                    ),
                                    color: const Color(0xFF222222),
                                    onSelected: (value) {
                                      if (value == 'make_admin') {
                                        _changeMemberRole(
                                          m['id'],
                                          memberName,
                                          'admin',
                                        );
                                      } else if (value == 'make_personel') {
                                        _changeMemberRole(
                                          m['id'],
                                          memberName,
                                          'personel',
                                        );
                                      } else if (value == 'remove') {
                                        _removeMember(m['id'], memberName);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (!isAdmin)
                                        const PopupMenuItem(
                                          value: 'make_admin',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.admin_panel_settings,
                                                color: Colors.redAccent,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Yönetici Yap (Tam Yetki Ver)',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (isAdmin)
                                        const PopupMenuItem(
                                          value: 'make_personel',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.person,
                                                color: Colors.blueAccent,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Standart Personele Düşür',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.person_remove_outlined,
                                              color: Colors.redAccent,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Ekipten Çıkar',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
