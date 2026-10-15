import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _companyId = '';
  String _searchQuery = '';
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _paymentTypes = [];

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'];

      final clientsRes = await supabase
          .from('clients')
          .select()
          .eq('company_id', _companyId)
          .order('title', ascending: true);

      final ptRes = await supabase
          .from('payment_types')
          .select()
          .eq('company_id', _companyId)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(clientsRes);
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

  // TAM GENİŞLİKTE MOBİL UYUMLU YENİ MÜKELLEF EKLEME / DÜZENLEME PENCERESİ
  void _showClientDialog({Map<String, dynamic>? existingClient}) {
    final isEdit = existingClient != null;
    final titleCtrl = TextEditingController(
      text: existingClient?['title'] ?? '',
    );
    final contactCtrl = TextEditingController(
      text: existingClient?['contact_person'] ?? '',
    );
    final taxOfficeCtrl = TextEditingController(
      text: existingClient?['tax_office'] ?? '',
    );
    final taxNoCtrl = TextEditingController(
      text: existingClient?['tax_number'] ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: existingClient?['phone'] ?? '',
    );
    final emailCtrl = TextEditingController(
      text: existingClient?['email'] ?? '',
    );
    final addressCtrl = TextEditingController(
      text: existingClient?['address'] ?? '',
    );
    final notesCtrl = TextEditingController(
      text: existingClient?['notes'] ?? '',
    );
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
            title: Text(
              isEdit ? 'Mükellef Bilgilerini Düzenle' : 'Yeni Mükellef Ekle',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: isMobile ? screenWidth : 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogField(
                      'Firma / Mükellef Unvanı *',
                      titleCtrl,
                      Icons.business,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Yetkili Kişi Adı Soyadı',
                      contactCtrl,
                      Icons.person,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Vergi Dairesi',
                      taxOfficeCtrl,
                      Icons.account_balance,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Vergi Numarası / TC Kimlik No',
                      taxNoCtrl,
                      Icons.tag,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'İletişim Telefonu',
                      phoneCtrl,
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'E-Posta Adresi',
                      emailCtrl,
                      Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Açık Adres / İl / İlçe',
                      addressCtrl,
                      Icons.location_on,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Mükellefe Ait Özel Notlar',
                      notesCtrl,
                      Icons.edit_note,
                      maxLines: 2,
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
                    ElevatedButton(
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lütfen Firma / Mükellef Unvanını girin.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        final Map<String, dynamic> data = {
                          'company_id': _companyId,
                          'title': titleCtrl.text.trim(),
                          'tax_office': taxOfficeCtrl.text.trim(),
                          'tax_number': taxNoCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'address': addressCtrl.text.trim(),
                          'notes': notesCtrl.text.trim(),
                          'is_active': true,
                        };

                        try {
                          if (isEdit) {
                            await supabase
                                .from('clients')
                                .update(data)
                                .eq('id', existingClient['id']);
                          } else {
                            await supabase.from('clients').insert(data);
                          }

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchClients();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Mükellef bilgileri güncellendi!'
                                      : 'Yeni mükellef başarıyla eklendi!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'İşlem kaydedilirken bir hata oluştu.',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isEdit ? 'Güncelle' : 'Sisteme Ekle',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  // TEK MÜKELLEFE ÖZEL PERİYODİK (AYLIK / YILLIK / 1 DEFALIK) TAHAKKUK EKLEME
  void _showAddSingleChargeDialog(Map<String, dynamic> client) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedPtId = _paymentTypes.isNotEmpty
        ? _paymentTypes.first['id'].toString()
        : null;
    String selectedPtName = _paymentTypes.isNotEmpty
        ? _paymentTypes.first['name'].toString()
        : 'Danışmanlık Hizmeti';
    String selectedFrequency = 'monthly';
    bool isSaving = false;

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
            title: Text(
              '${client['title']} - Tahakkuk Tanımla',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: isMobile ? screenWidth : 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_paymentTypes.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedPtId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF222222),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Hizmet / Ödeme Kalemi',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF101014),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _paymentTypes
                            .map(
                              (pt) => DropdownMenuItem<String>(
                                value: pt['id'].toString(),
                                child: Text(pt['name'].toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedPtId = val;
                            selectedPtName = _paymentTypes.firstWhere(
                              (pt) => pt['id'].toString() == val,
                            )['name'];
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF222222),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Ödeme Sıklığı (Periyot)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.repeat,
                          color: Color(0xFF00ACC1),
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
                          value: 'monthly',
                          child: Text('Aylık (Her Ay Otomatik Yansır)'),
                        ),
                        DropdownMenuItem(
                          value: 'yearly',
                          child: Text('Yıllık (Her Yıl Otomatik Yansır)'),
                        ),
                        DropdownMenuItem(
                          value: 'one_time',
                          child: Text('1 Defalık (Tek Seferlik İşlem)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedFrequency = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Tutar (₺) - Örn: 1000',
                      amountCtrl,
                      Icons.currency_lira,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Özel Açıklama (Boş bırakılırsa kalem adı yazılır)',
                      descCtrl,
                      Icons.description_outlined,
                    ),
                  ],
                ),
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
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(
                              amountCtrl.text.replaceAll(',', '.'),
                            ) ??
                            0.0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen geçerli bir tutar girin.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        final now = DateTime.now();
                        final baseDesc = descCtrl.text.trim().isNotEmpty
                            ? descCtrl.text.trim()
                            : selectedPtName;

                        final periodLabel = selectedFrequency == 'monthly'
                            ? DateFormat('MMMM yyyy', 'tr_TR').format(now)
                            : selectedFrequency == 'yearly'
                            ? '${now.year} Yılı'
                            : '';

                        final finalDesc = periodLabel.isEmpty
                            ? baseDesc
                            : '$baseDesc • $periodLabel';

                        final periodKey = selectedFrequency == 'monthly'
                            ? DateFormat('yyyy-MM').format(now)
                            : selectedFrequency == 'yearly'
                            ? DateFormat('yyyy').format(now)
                            : 'ONCE_${now.millisecondsSinceEpoch}';

                        try {
                          await supabase.from('transactions').insert({
                            'company_id': _companyId,
                            'client_id': client['id'],
                            'payment_type_id': selectedPtId,
                            'description': finalDesc,
                            'amount': amount,
                            'is_paid': false,
                            'due_date': now.toIso8601String().split('T')[0],
                            'frequency': selectedFrequency,
                            'period_key': periodKey,
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tahakkuk başarıyla eklendi!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                ),
                child: const Text(
                  'Kaydet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: const Color(0xFF101014),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final filteredClients = _clients.where((c) {
      final title = (c['title'] ?? '').toString().toLowerCase();
      final taxNo = (c['tax_number'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery.toLowerCase()) ||
          taxNo.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        title: const Text(
          'Mükellef Yönetimi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClientDialog(),
        backgroundColor: const Color(0xFF00ACC1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Yeni Mükellef',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 28),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Mükellef unvanı veya Vergi/TC No ile ara...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF00ACC1),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1A20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredClients.isEmpty
                        ? const Center(
                            child: Text(
                              'Kayıtlı mükellef bulunamadı.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 15,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredClients.length,
                            itemBuilder: (context, index) {
                              final c = filteredClients[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A20),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(
                                      0xFF00ACC1,
                                    ).withValues(alpha: 0.15),
                                    child: Text(
                                      (c['title'] ?? 'M')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF00ACC1),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    c['title'] ?? 'İsimsiz Mükellef',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Vergi Dairesi: ${c['tax_office'] ?? '-'} • VKN/TC: ${c['tax_number'] ?? '-'}\nTel: ${c['phone'] ?? '-'}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.white70,
                                    ),
                                    color: const Color(0xFF222222),
                                    onSelected: (val) async {
                                      if (val == 'charge') {
                                        _showAddSingleChargeDialog(c);
                                      } else if (val == 'edit') {
                                        _showClientDialog(existingClient: c);
                                      } else if (val == 'delete') {
                                        await supabase
                                            .from('clients')
                                            .delete()
                                            .eq('id', c['id']);
                                        _fetchClients();
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'charge',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.receipt_long,
                                              color: Color(0xFF00ACC1),
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Tahakkuk / Hizmet Tanımla',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit,
                                              color: Colors.white70,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Bilgileri Düzenle',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Mükellefi Sil',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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
