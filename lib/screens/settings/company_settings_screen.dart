import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  String _companyId = '';

  final _nameController = TextEditingController();
  final _officialNameController = TextEditingController();
  final _taxOfficeController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  List<Map<String, dynamic>> _paymentTypes = [];

  @override
  void initState() {
    super.initState();
    _fetchCompanyData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _officialNameController.dispose();
    _taxOfficeController.dispose();
    _taxNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanyData() async {
    try {
      final user = supabase.auth.currentUser;
      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user!.id)
          .single();
      _companyId = profile['company_id'];

      final companyData = await supabase
          .from('companies')
          .select()
          .eq('id', _companyId)
          .single();

      final paymentData = await supabase
          .from('payment_types')
          .select()
          .eq('company_id', _companyId)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _nameController.text = companyData['name'] ?? '';
          _officialNameController.text = companyData['official_name'] ?? '';
          _taxOfficeController.text = companyData['tax_office'] ?? '';
          _taxNumberController.text = companyData['tax_number'] ?? '';
          _phoneController.text = companyData['phone'] ?? '';
          _emailController.text = companyData['email'] ?? '';
          _addressController.text = companyData['address'] ?? '';

          _paymentTypes = List<Map<String, dynamic>>.from(paymentData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCompanyInfo() async {
    setState(() => _isSaving = true);
    try {
      await supabase
          .from('companies')
          .update({
            'name': _nameController.text.trim(),
            'official_name': _officialNameController.text.trim(),
            'tax_office': _taxOfficeController.text.trim(),
            'tax_number': _taxNumberController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'address': _addressController.text.trim(),
          })
          .eq('id', _companyId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şirket bilgileri başarıyla güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hata oluştu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addPaymentType() {
    final tController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Yeni Hizmet / Ödeme Kalemi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: tController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Hizmet Adı (Örn: Danışmanlık)',
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
            prefixIcon: const Icon(
              Icons.label_outline,
              color: Color(0xFF00ACC1),
              size: 20,
            ),
            filled: true,
            fillColor: const Color(0xFF101014),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00ACC1),
                width: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tController.text.trim().isNotEmpty) {
                await supabase.from('payment_types').insert({
                  'company_id': _companyId,
                  'name': tController.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
                _fetchCompanyData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ACC1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
    );
  }

  void _deletePaymentType(String id) async {
    await supabase.from('payment_types').delete().eq('id', id);
    _fetchCompanyData();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF101014),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16161A),
          elevation: 0,
          title: const Text(
            'Kurumsal Şirket Ayarları',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            isScrollable: isMobile,
            tabAlignment: isMobile ? TabAlignment.start : null,
            indicatorColor: const Color(0xFF00ACC1),
            labelColor: const Color(0xFF00ACC1),
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: const [
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
                children: [_buildCorporateInfoTab(), _buildPaymentTypesTab()],
              ),
      ),
    );
  }

  Widget _buildCorporateInfoTab() {
    final isMobile = MediaQuery.of(context).size.width < 650;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Center(
        child: Container(
          width: 800,
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resmi Firma Detayları',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ekstre ve raporlarda yer alacak kurumsal bilgilerinizi buradan güncelleyebilirsiniz.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
              if (isMobile) ...[
                _buildTextField(
                  'Kısa Ad / Marka',
                  _nameController,
                  Icons.business,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Resmi Firma Unvanı',
                  _officialNameController,
                  Icons.gavel,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Vergi Dairesi',
                  _taxOfficeController,
                  Icons.account_balance,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Vergi Numarası / TCKN',
                  _taxNumberController,
                  Icons.numbers,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'İletişim Telefonu',
                  _phoneController,
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'İletişim E-Postası',
                  _emailController,
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Kısa Ad / Marka',
                        _nameController,
                        Icons.business,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTextField(
                        'Resmi Firma Unvanı',
                        _officialNameController,
                        Icons.gavel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Vergi Dairesi',
                        _taxOfficeController,
                        Icons.account_balance,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTextField(
                        'Vergi Numarası / TCKN',
                        _taxNumberController,
                        Icons.numbers,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'İletişim Telefonu',
                        _phoneController,
                        Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTextField(
                        'İletişim E-Postası',
                        _emailController,
                        Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: isMobile ? 16 : 20),
              _buildTextField(
                'Resmi Şirket Adresi',
                _addressController,
                Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 28),
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
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Şirket Bilgilerini Kaydet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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

  Widget _buildPaymentTypesTab() {
    final isMobile = MediaQuery.of(context).size.width < 650;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Center(
        child: Container(
          width: 800,
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                const Text(
                  'Verilen Hizmetler / Ödeme Kalemleri',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addPaymentType,
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text(
                      'Yeni Kalem Ekle',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00ACC1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verilen Hizmetler / Ödeme Kalemleri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addPaymentType,
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Yeni Kalem Ekle',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(color: Colors.white12, height: 36),
              _paymentTypes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Henüz bir hizmet kalemi tanımlanmamış.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _paymentTypes.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white12, height: 1),
                      itemBuilder: (context, index) {
                        final pt = _paymentTypes[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.label,
                            color: Color(0xFF00ACC1),
                          ),
                          title: Text(
                            pt['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _deletePaymentType(pt['id']),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // Kayma veya Kesilme Yapmayan, Sabit Başlıklı Modern Input Yapısı
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF00ACC1), size: 20),
            filled: true,
            fillColor: const Color(0xFF101014),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00ACC1),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
