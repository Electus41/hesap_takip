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

  static const List<String> _turkishMonths = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

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
      _companyId = profile['company_id'].toString();

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

  void _showClientDialog({Map<String, dynamic>? existingClient}) {
    final isEdit = existingClient != null;
    final titleCtrl = TextEditingController(
      text: existingClient?['title']?.toString() ?? '',
    );
    final contactCtrl = TextEditingController(
      text:
          (existingClient?['contact_person'] ??
                  existingClient?['contact_name'] ??
                  '')
              .toString(),
    );
    final taxOfficeCtrl = TextEditingController(
      text: existingClient?['tax_office']?.toString() ?? '',
    );
    final taxNoCtrl = TextEditingController(
      text: existingClient?['tax_number']?.toString() ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: existingClient?['phone']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: existingClient?['email']?.toString() ?? '',
    );
    final addressCtrl = TextEditingController(
      text: existingClient?['address']?.toString() ?? '',
    );
    final notesCtrl = TextEditingController(
      text: existingClient?['notes']?.toString() ?? '',
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
                          'contact_person': contactCtrl.text.trim(),
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
                          if (e.toString().contains('contact_person')) {
                            data.remove('contact_person');
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
                              }
                              return;
                            } catch (_) {}
                          }

                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'İşlem kaydedilirken bir hata oluştu: $e',
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

  Future<void> _confirmDeleteClient(Map<String, dynamic> client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mükellefi Sil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${client['title']}" isimli mükellefi silmek istediğinize emin misiniz?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Evet, Sil',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await supabase.from('clients').delete().eq('id', client['id']);
      _fetchClients();
    }
  }

  // TEK MÜKELLEFE ÖZEL VADE SEÇİMLİ TAHAKKUK EKLEME PENCERESİ
  void _showAddSingleChargeDialog(Map<String, dynamic> client) {
    final now = DateTime.now();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedPtId = _paymentTypes.isNotEmpty
        ? _paymentTypes.first['id'].toString()
        : null;
    String selectedPtName = _paymentTypes.isNotEmpty
        ? _paymentTypes.first['name'].toString()
        : 'Danışmanlık Hizmeti';
    String selectedFrequency = 'monthly';

    int selectedDay = now.day;
    int selectedMonth = now.month;
    int selectedYear = now.year;

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;
          final maxDaysInSelectedMonth = DateTime(
            selectedYear,
            selectedMonth + 1,
            0,
          ).day;
          if (selectedDay > maxDaysInSelectedMonth) {
            selectedDay = maxDaysInSelectedMonth;
          }

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
              '${client['title']} • Tahakkuk Tanımla',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: isMobile ? screenWidth : 450,
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

                    // DİNAMİK VADE GÜNÜ / TARİHİ SEÇİMİ
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101014),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00ACC1).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.event_available,
                                color: Color(0xFF00ACC1),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedFrequency == 'monthly'
                                    ? 'Son Ödeme Günü (Her Ayın Kaçı?)'
                                    : selectedFrequency == 'yearly'
                                    ? 'Yıllık Vade Tarihi (Gün ve Ay)'
                                    : 'Son Ödeme / Vade Tarihi Seçin',
                                style: const TextStyle(
                                  color: Color(0xFF00ACC1),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (selectedFrequency == 'monthly')
                            DropdownButtonFormField<int>(
                              value: selectedDay,
                              dropdownColor: const Color(0xFF222222),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF1A1A20),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: List.generate(31, (i) => i + 1)
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(
                                        'Her Ayın $d. Günü Son Ödeme',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedDay = val);
                                }
                              },
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<int>(
                                    value: selectedDay,
                                    dropdownColor: const Color(0xFF222222),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Gün',
                                      labelStyle: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF1A1A20),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    items:
                                        List.generate(
                                              maxDaysInSelectedMonth,
                                              (i) => i + 1,
                                            )
                                            .map(
                                              (d) => DropdownMenuItem(
                                                value: d,
                                                child: Text(
                                                  d.toString().padLeft(2, '0'),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() => selectedDay = val);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: DropdownButtonFormField<int>(
                                    value: selectedMonth,
                                    dropdownColor: const Color(0xFF222222),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Ay',
                                      labelStyle: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF1A1A20),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    items: List.generate(12, (i) => i + 1)
                                        .map(
                                          (m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(_turkishMonths[m - 1]),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(
                                          () => selectedMonth = val,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                if (selectedFrequency == 'one_time') ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<int>(
                                      value: selectedYear,
                                      dropdownColor: const Color(0xFF222222),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Yıl',
                                        labelStyle: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFF1A1A20),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      items:
                                          List.generate(6, (i) => now.year + i)
                                              .map(
                                                (y) => DropdownMenuItem(
                                                  value: y,
                                                  child: Text(y.toString()),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(
                                            () => selectedYear = val,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
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

                        DateTime finalDueDate;
                        if (selectedFrequency == 'monthly') {
                          final maxD = DateTime(now.year, now.month + 1, 0).day;
                          final d = selectedDay > maxD ? maxD : selectedDay;
                          finalDueDate = DateTime(now.year, now.month, d);
                        } else if (selectedFrequency == 'yearly') {
                          final maxD = DateTime(
                            now.year,
                            selectedMonth + 1,
                            0,
                          ).day;
                          final d = selectedDay > maxD ? maxD : selectedDay;
                          finalDueDate = DateTime(now.year, selectedMonth, d);
                        } else {
                          final maxD = DateTime(
                            selectedYear,
                            selectedMonth + 1,
                            0,
                          ).day;
                          final d = selectedDay > maxD ? maxD : selectedDay;
                          finalDueDate = DateTime(
                            selectedYear,
                            selectedMonth,
                            d,
                          );
                        }

                        final baseDesc = descCtrl.text.trim().isNotEmpty
                            ? descCtrl.text.trim()
                            : selectedPtName;

                        final periodLabel = selectedFrequency == 'monthly'
                            ? DateFormat(
                                'MMMM yyyy',
                                'tr_TR',
                              ).format(finalDueDate)
                            : selectedFrequency == 'yearly'
                            ? '${finalDueDate.year} Yılı'
                            : '';

                        final finalDesc = periodLabel.isEmpty
                            ? baseDesc
                            : '$baseDesc • $periodLabel';

                        final periodKey = selectedFrequency == 'monthly'
                            ? DateFormat('yyyy-MM').format(finalDueDate)
                            : selectedFrequency == 'yearly'
                            ? DateFormat('yyyy').format(finalDueDate)
                            : 'ONCE_${now.millisecondsSinceEpoch}';

                        try {
                          await supabase.from('transactions').insert({
                            'company_id': _companyId,
                            'client_id': client['id'],
                            'payment_type_id': selectedPtId,
                            'description': finalDesc,
                            'amount': amount,
                            'is_paid': false,
                            'due_date': DateFormat(
                              'yyyy-MM-dd',
                            ).format(finalDueDate),
                            'frequency': selectedFrequency,
                            'period_key': periodKey,
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Tahakkuk (Vade: ${DateFormat('dd.MM.yyyy').format(finalDueDate)}) başarıyla eklendi!',
                                ),
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
      final contact = (c['contact_person'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || taxNo.contains(q) || contact.contains(q);
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
                      hintText:
                          'Mükellef unvanı, Yetkili adı veya Vergi/TC No ile ara...',
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
                              final contactName = (c['contact_person'] ?? '')
                                  .toString()
                                  .trim();

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
                                      '${contactName.isNotEmpty ? 'Yetkili: $contactName • ' : ''}Vergi Dairesi: ${c['tax_office'] ?? '-'} • VKN/TC: ${c['tax_number'] ?? '-'}\nTel: ${c['phone'] ?? '-'}',
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
                                        _confirmDeleteClient(c);
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
