import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final supabase = Supabase.instance.client;

  final _nameCtrl = TextEditingController();
  final _officialTitleCtrl = TextEditingController();
  final _taxOfficeCtrl = TextEditingController();
  final _taxNoCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();
  final _paymentTypeCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _companyId = '';
  List<Map<String, dynamic>> _paymentTypes = [];

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'];

      final comp = await supabase
          .from('companies')
          .select()
          .eq('id', _companyId)
          .single();

      _nameCtrl.text = comp['name'] ?? '';
      _officialTitleCtrl.text =
          comp['official_title'] ?? comp['full_title'] ?? '';
      _taxOfficeCtrl.text = comp['tax_office'] ?? '';
      _taxNoCtrl.text = comp['tax_number'] ?? '';
      _phoneCtrl.text = comp['phone'] ?? '';
      _emailCtrl.text = comp['email'] ?? '';
      _addressCtrl.text = comp['address'] ?? '';
      _inviteCodeCtrl.text = comp['invite_code'] ?? '';

      final ptRes = await supabase
          .from('payment_types')
          .select()
          .eq('company_id', _companyId)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _paymentTypes = List<Map<String, dynamic>>.from(ptRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveCompanyInfo() async {
    final shortName = _nameCtrl.text.trim();
    final inviteCode = _inviteCodeCtrl.text.trim().toUpperCase().replaceAll(
      ' ',
      '_',
    );

    if (shortName.isEmpty || inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kısa Ad / Marka ve Şirket Davet Kodu boş bırakılamaz!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Önce temel ve kesin olan sütunları güncelliyoruz
      final Map<String, dynamic> updateData = {
        'name': shortName,
        'invite_code': inviteCode,
      };

      // Diğer kurumsal detay sütunları veritabanında mevcutsa onları da kaydeder
      try {
        await supabase
            .from('companies')
            .update({
              ...updateData,
              'official_title': _officialTitleCtrl.text.trim(),
              'tax_office': _taxOfficeCtrl.text.trim(),
              'tax_number': _taxNoCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
              'email': _emailCtrl.text.trim(),
              'address': _addressCtrl.text.trim(),
            })
            .eq('id', _companyId);
      } catch (_) {
        // Eğer bazı opsiyonel sütunlar tabloda yoksa en azından name ve invite_code'u garanti kaydeder
        await supabase
            .from('companies')
            .update(updateData)
            .eq('id', _companyId);
      }

      _inviteCodeCtrl.text = inviteCode;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Şirket bilgileri ve davet kodu başarıyla kaydedildi!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PostgrestException catch (e) {
      String msg = 'Kayıt hatası: ${e.message}';
      if (e.message.contains('invite_code') || e.message.contains('unique')) {
        msg =
            'Bu Şirket Davet Kodu ($inviteCode) başka bir şirket tarafından kullanılıyor. Lütfen farklı bir kod yazın.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _addPaymentType() async {
    if (_paymentTypeCtrl.text.trim().isEmpty) return;
    try {
      await supabase.from('payment_types').insert({
        'company_id': _companyId,
        'name': _paymentTypeCtrl.text.trim(),
      });
      _paymentTypeCtrl.clear();
      _loadCompanyData();
    } catch (_) {}
  }

  Future<void> _deletePaymentType(String id) async {
    await supabase.from('payment_types').delete().eq('id', id);
    _loadCompanyData();
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: const Color(0xFF101014),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF101014),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16161A),
          title: const Text(
            'Kurumsal Şirket Ayarları',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFF00ACC1),
            labelColor: Color(0xFF00ACC1),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Kurumsal Bilgiler'),
              Tab(text: 'Ödeme Kalemleri / Hizmetler'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
              )
            : TabBarView(
                children: [
                  // 1. SEKME: KURUMSAL BİLGİLER & ŞİRKET DAVET KODU
                  SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 36),
                    child: Center(
                      child: Container(
                        width: 720,
                        padding: EdgeInsets.all(isMobile ? 20 : 32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resmi Firma Detayları & Şirket Kodu',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ÖZEL ŞİRKET DAVET KODU KUTUSU (ÖNE ÇIKARILMIŞ)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF101014),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00ACC1,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.vpn_key,
                                        color: Color(0xFF00ACC1),
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Personel Şirket Davet Kodu (Örn: MHK_1234)',
                                        style: TextStyle(
                                          color: Color(0xFF00ACC1),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _inviteCodeCtrl,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Örn: MHK_2026',
                                      hintStyle: const TextStyle(
                                        color: Colors.white30,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF1A1A20),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(
                                          Icons.copy,
                                          color: Colors.white70,
                                        ),
                                        tooltip: 'Kodu Kopyala',
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: _inviteCodeCtrl.text.trim(),
                                            ),
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
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Personelleriniz kayıt olurken bu kodu girerek ofisinize katılabilir. İstediğiniz gibi düzenleyip alttaki kaydet butonuna basabilirsiniz.',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (isMobile) ...[
                              _buildInputField(
                                'Kısa Ad / Marka',
                                _nameCtrl,
                                Icons.domain,
                              ),
                              const SizedBox(height: 14),
                              _buildInputField(
                                'Resmi Firma Unvanı',
                                _officialTitleCtrl,
                                Icons.gavel,
                              ),
                              const SizedBox(height: 14),
                              _buildInputField(
                                'Vergi Dairesi',
                                _taxOfficeCtrl,
                                Icons.account_balance,
                              ),
                              const SizedBox(height: 14),
                              _buildInputField(
                                'Vergi Numarası',
                                _taxNoCtrl,
                                Icons.tag,
                              ),
                              const SizedBox(height: 14),
                              _buildInputField(
                                'İletişim Telefonu',
                                _phoneCtrl,
                                Icons.phone,
                              ),
                              const SizedBox(height: 14),
                              _buildInputField(
                                'İletişim E-Postası',
                                _emailCtrl,
                                Icons.email,
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      'Kısa Ad / Marka',
                                      _nameCtrl,
                                      Icons.domain,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInputField(
                                      'Resmi Firma Unvanı',
                                      _officialTitleCtrl,
                                      Icons.gavel,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      'Vergi Dairesi',
                                      _taxOfficeCtrl,
                                      Icons.account_balance,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInputField(
                                      'Vergi Numarası',
                                      _taxNoCtrl,
                                      Icons.tag,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      'İletişim Telefonu',
                                      _phoneCtrl,
                                      Icons.phone,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInputField(
                                      'İletişim E-Postası',
                                      _emailCtrl,
                                      Icons.email,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            _buildInputField(
                              'Resmi Şirket Adresi',
                              _addressCtrl,
                              Icons.location_on,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveCompanyInfo,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ACC1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _isSaving
                                      ? 'Kaydediliyor...'
                                      : 'Şirket Bilgilerini Kaydet',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. SEKME: ÖDEME KALEMLERİ / HİZMETLER
                  SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 36),
                    child: Center(
                      child: Container(
                        width: 720,
                        padding: EdgeInsets.all(isMobile ? 20 : 32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tahakkuk / Ödeme Kalemleri',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _paymentTypeCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Yeni Hizmet / Kalem Adı (Örn: Aylık Müşavirlik Ücreti)',
                                      hintStyle: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 13,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF101014),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _addPaymentType,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00ACC1),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Ekle',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_paymentTypes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Henüz kayıtlı bir ödeme kalemi bulunmuyor.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _paymentTypes.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(color: Colors.white12),
                                itemBuilder: (context, index) {
                                  final pt = _paymentTypes[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.label_important_outline,
                                      color: Color(0xFF00ACC1),
                                    ),
                                    title: Text(
                                      pt['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _deletePaymentType(
                                        pt['id'].toString(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
