import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isLoadingStatement = false;
  String _companyId = '';
  String _companyName = 'Mükellef Takip';

  List<Map<String, dynamic>> _clients = [];
  Map<String, String> _clientNames = {};
  String? _selectedClientId; // null = Tüm Mükellefler
  DateTimeRange? _range;

  List<Map<String, dynamic>> _transactions = [];
  double _totalDebt = 0.0; // Toplam Tahakkuk
  double _totalPaid = 0.0; // Tahsil Edilen

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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id, companies(name)')
          .eq('id', user.id)
          .single();

      _companyId = profile['company_id'].toString();
      if (profile['companies'] != null && profile['companies'] is Map) {
        _companyName =
            profile['companies']['name']?.toString() ?? 'Mükellef Takip';
      }

      final res = await supabase
          .from('clients')
          .select('id, title')
          .eq('company_id', _companyId)
          .order('title', ascending: true);

      _clients = List<Map<String, dynamic>>.from(res);
      _clientNames = {
        for (var c in _clients)
          c['id'].toString(): (c['title'] ?? 'Mükellef').toString(),
      };

      await _loadStatement();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ANA EKRAN İLE %100 SENKRONİZE VERİ ÇEKME VE HESAPLAMA MANTIĞI
  Future<void> _loadStatement() async {
    setState(() => _isLoadingStatement = true);

    try {
      List<Map<String, dynamic>> allTx = [];

      try {
        final txByCompany = await supabase
            .from('transactions')
            .select()
            .eq('company_id', _companyId)
            .order('due_date', ascending: false);
        allTx = List<Map<String, dynamic>>.from(txByCompany);
      } catch (_) {}

      if (_clientNames.isNotEmpty) {
        try {
          final txByClients = await supabase
              .from('transactions')
              .select()
              .inFilter('client_id', _clientNames.keys.toList())
              .order('due_date', ascending: false);

          final existingIds = allTx.map((e) => e['id'].toString()).toSet();
          for (var tx in txByClients) {
            if (!existingIds.contains(tx['id'].toString())) {
              allTx.add(tx);
            }
          }
        } catch (_) {}
      }

      List<Map<String, dynamic>> filtered = [];
      double unpaidTotal = 0.0;
      double paidTotal = 0.0;

      for (var t in allTx) {
        final cId = t['client_id']?.toString() ?? '';
        if (_selectedClientId != null && cId != _selectedClientId) {
          continue;
        }

        final rawDate = (t['due_date'] ?? t['created_at'] ?? '').toString();
        DateTime? txDate;
        if (rawDate.isNotEmpty) {
          try {
            txDate = DateTime.parse(rawDate);
          } catch (_) {}
        }

        if (_range != null && txDate != null) {
          final dOnly = DateTime(txDate.year, txDate.month, txDate.day);
          final startOnly = DateTime(
            _range!.start.year,
            _range!.start.month,
            _range!.start.day,
          );
          final endOnly = DateTime(
            _range!.end.year,
            _range!.end.month,
            _range!.end.day,
          );
          if (dOnly.isBefore(startOnly) || dOnly.isAfter(endOnly)) {
            continue;
          }
        }

        final amt = double.tryParse(t['amount'].toString()) ?? 0.0;
        final isPaid = t['is_paid'] == true;

        if (isPaid) {
          paidTotal += amt;
        } else {
          unpaidTotal += amt;
        }

        filtered.add({...t, 'client_title': _clientNames[cId] ?? 'Mükellef'});
      }

      if (mounted) {
        setState(() {
          _transactions = filtered;
          _totalDebt = unpaidTotal + paidTotal; // Toplam Tahakkuk
          _totalPaid = paidTotal; // Tahsil Edilen
          _isLoadingStatement = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStatement = false;
          _isLoading = false;
        });
      }
    }
  }

  // %100 TÜRKÇE ÖZEL TARİH ARALIĞI SEÇİCİ PENCERESİ (İNGİLİZCE TAKVİM AÇILMAZ!)
  Future<void> _pickRange() async {
    final now = DateTime.now();
    DateTime start = _range?.start ?? DateTime(now.year, now.month, 1);
    DateTime end = _range?.end ?? now;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: const Color(0xFF00ACC1).withValues(alpha: 0.35),
              ),
            ),
            title: const Row(
              children: [
                Icon(Icons.calendar_month, color: Color(0xFF00ACC1)),
                SizedBox(width: 10),
                Text(
                  'Rapor Dönemi / Tarih Seçimi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hızlı Dönem Filtreleri:',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _quickDateChip('Bu Ay', () {
                        setDialogState(() {
                          start = DateTime(now.year, now.month, 1);
                          end = DateTime(now.year, now.month + 1, 0);
                        });
                      }),
                      _quickDateChip('Geçen Ay', () {
                        setDialogState(() {
                          start = DateTime(now.year, now.month - 1, 1);
                          end = DateTime(now.year, now.month, 0);
                        });
                      }),
                      _quickDateChip('Son 3 Ay', () {
                        setDialogState(() {
                          start = DateTime(now.year, now.month - 2, 1);
                          end = DateTime(now.year, now.month + 1, 0);
                        });
                      }),
                      _quickDateChip('Bu Yıl (${now.year})', () {
                        setDialogState(() {
                          start = DateTime(now.year, 1, 1);
                          end = DateTime(now.year, 12, 31);
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Başlangıç Tarihi (Gün / Ay / Yıl):',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTurkishDateDropdowns(start, (newDate) {
                    setDialogState(() => start = newDate);
                  }),
                  const SizedBox(height: 16),
                  const Text(
                    'Bitiş Tarihi (Gün / Ay / Yıl):',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTurkishDateDropdowns(end, (newDate) {
                    setDialogState(() => end = newDate);
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _range = null);
                  Navigator.pop(context);
                  _loadStatement();
                },
                child: const Text(
                  'Tüm Zamanlar',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (end.isBefore(start)) {
                    final tmp = start;
                    start = end;
                    end = tmp;
                  }
                  setState(
                    () => _range = DateTimeRange(start: start, end: end),
                  );
                  Navigator.pop(context);
                  _loadStatement();
                },
                icon: const Icon(Icons.check, color: Colors.white, size: 16),
                label: const Text(
                  'Dönemi Uygula',
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

  Widget _buildTurkishDateDropdowns(
    DateTime current,
    ValueChanged<DateTime> onChanged,
  ) {
    final maxDaysInMonth = DateTime(current.year, current.month + 1, 0).day;
    final safeDay = current.day > maxDaysInMonth ? maxDaysInMonth : current.day;

    return Row(
      children: [
        // GÜN SEÇİMİ
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF101014),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: safeDay,
                dropdownColor: const Color(0xFF222222),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: List.generate(maxDaysInMonth, (i) => i + 1)
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.toString().padLeft(2, '0')),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    onChanged(DateTime(current.year, current.month, val));
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // TÜRKÇE AY SEÇİMİ
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF101014),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: current.month,
                dropdownColor: const Color(0xFF222222),
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
                    final maxD = DateTime(current.year, val + 1, 0).day;
                    final d = current.day > maxD ? maxD : current.day;
                    onChanged(DateTime(current.year, val, d));
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // YIL SEÇİMİ
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF101014),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: current.year,
                dropdownColor: const Color(0xFF222222),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: List.generate(12, (i) => 2020 + i)
                    .map(
                      (y) =>
                          DropdownMenuItem(value: y, child: Text(y.toString())),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    onChanged(DateTime(val, current.month, safeDay));
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickDateChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00ACC1).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF00ACC1).withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF00ACC1),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // KURUMSAL A4 RAPOR & PDF BASKI ÖNİZLEME PENCERESİ
  void _showPrintableReportDialog() {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Rapor oluşturmak için listede en az 1 hareket olmalıdır.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final fmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    final balance = _totalDebt - _totalPaid;
    final scopeTitle = _selectedClientId == null
        ? 'TÜM MÜKELLEFLER (GENEL OFİS EKSTRESİ)'
        : (_clientNames[_selectedClientId] ?? 'Mükellef').toUpperCase();
    final periodText = _range == null
        ? 'Tüm Zamanlar'
        : '${DateFormat('dd.MM.yyyy').format(_range!.start)} - ${DateFormat('dd.MM.yyyy').format(_range!.end)}';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 780,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ÜST ANTET
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _companyName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'RESMİ CARİ HESAP EKSTRESİ & FİNANSAL ÖZET RAPORU',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Dönem: $periodText',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.black26, height: 28, thickness: 1.2),
              Text(
                'İlgili Cari / Kapsam: $scopeTitle',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // ÖZET KUTULARI
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _reportStatItem(
                      'Toplam Tahakkuk',
                      fmt.format(_totalDebt),
                      Colors.orange.shade800,
                    ),
                    _reportStatItem(
                      'Tahsil Edilen',
                      fmt.format(_totalPaid),
                      Colors.green.shade700,
                    ),
                    _reportStatItem(
                      'Kalan Net Bakiye',
                      fmt.format(balance),
                      Colors.red.shade700,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // TABLO BAŞLIĞI
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: Colors.blueGrey.shade800,
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Tarih',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Mükellef',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Açıklama',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Durum',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Tutar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              // HAREKET LİSTESİ
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _transactions.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade300, height: 1),
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    final isPaid = t['is_paid'] == true;
                    final amt = double.tryParse(t['amount'].toString()) ?? 0.0;
                    final rawDate = (t['due_date'] ?? t['created_at'] ?? '')
                        .toString();
                    String dStr = '-';
                    if (rawDate.isNotEmpty) {
                      try {
                        dStr = DateFormat(
                          'dd.MM.yyyy',
                        ).format(DateTime.parse(rawDate));
                      } catch (_) {}
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              dStr,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              (t['client_title'] ?? '').toString(),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              (t['description'] ?? '').toString(),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              isPaid ? 'Ödendi' : 'Bekliyor',
                              style: TextStyle(
                                color: isPaid
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              fmt.format(amt),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MHK Yazılım Teknolojileri • Kurumsal Finans ve Raporlama Altyapısı',
                    style: TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          final buffer = StringBuffer();
                          buffer.writeln(
                            '$_companyName - CARİ HESAP EKSTRESİ ($scopeTitle)',
                          );
                          buffer.writeln('Dönem: $periodText');
                          buffer.writeln(
                            'Toplam Tahakkuk: ${fmt.format(_totalDebt)} | Tahsil Edilen: ${fmt.format(_totalPaid)} | Kalan Bakiye: ${fmt.format(balance)}',
                          );
                          buffer.writeln(
                            '--------------------------------------------------',
                          );
                          for (var t in _transactions) {
                            final isPaid = t['is_paid'] == true;
                            final amt =
                                double.tryParse(t['amount'].toString()) ?? 0.0;
                            buffer.writeln(
                              '• ${t['client_title']} | ${t['description']} | ${isPaid ? 'Ödendi' : 'Bekliyor'} | ${fmt.format(amt)}',
                            );
                          }
                          Clipboard.setData(
                            ClipboardData(text: buffer.toString()),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Ekstre metni panoya kopyalandı! WhatsApp veya E-postaya yapıştırabilirsiniz.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Metin Olarak Kopyala'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade900,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Kapat',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    final isMobile = MediaQuery.of(context).size.width < 600;
    final balance = _totalDebt - _totalPaid;

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mükellef Cari Ekstre & Raporlar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _showPrintableReportDialog,
              icon: const Icon(
                Icons.picture_as_pdf,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Ekstre / PDF Rapor Al',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 24),
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    value: _selectedClientId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF222222),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Mükellef Seçin',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.business,
                        color: Color(0xFF00ACC1),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1A20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tüm Mükellefler (Genel Ofis Raporu)'),
                      ),
                      ..._clients.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c['id'].toString(),
                          child: Text((c['title'] ?? 'Mükellef').toString()),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedClientId = val);
                      _loadStatement();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickRange,
                          icon: const Icon(
                            Icons.calendar_month,
                            color: Color(0xFF00ACC1),
                            size: 18,
                          ),
                          label: Text(
                            _range == null
                                ? 'Tarih Aralığı: Tüm Zamanlar (Dönem Seçmek İçin Tıklayın)'
                                : 'Seçili Dönem: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(_range!.start)} - ${DateFormat('dd MMMM yyyy', 'tr_TR').format(_range!.end)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (_range != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Tarih Filtresini Temizle',
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () {
                            setState(() => _range = null);
                            _loadStatement();
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _summary(
                            'Toplam Tahakkuk',
                            fmt.format(_totalDebt),
                            Colors.orangeAccent,
                          ),
                        ),
                        Expanded(
                          child: _summary(
                            'Tahsil Edilen',
                            fmt.format(_totalPaid),
                            Colors.greenAccent,
                          ),
                        ),
                        Expanded(
                          child: _summary(
                            'Kalan Bakiye',
                            fmt.format(balance),
                            balance > 0
                                ? Colors.redAccent
                                : const Color(0xFF00ACC1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildList(fmt)),
                ],
              ),
            ),
    );
  }

  Widget _buildList(NumberFormat fmt) {
    if (_isLoadingStatement) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
      );
    }
    if (_transactions.isEmpty) {
      return const Center(
        child: Text(
          'Seçilen kriterlere uygun finansal hareket bulunamadı.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final t = _transactions[index];
        final isPaid = t['is_paid'] == true;
        final amt = double.tryParse(t['amount'].toString()) ?? 0.0;
        final clientTitle = (t['client_title'] ?? '').toString();

        String dateStr = '-';
        final rawDate = t['due_date'] ?? t['created_at'];
        if (rawDate != null) {
          try {
            dateStr = DateFormat(
              'dd.MM.yyyy',
              'tr_TR',
            ).format(DateTime.parse(rawDate.toString()));
          } catch (_) {}
        }
        final color = isPaid ? Colors.greenAccent : Colors.orangeAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaid ? Icons.check_circle_outline : Icons.schedule,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedClientId == null && clientTitle.isNotEmpty
                          ? '$clientTitle • ${t['description'] ?? 'İşlem'}'
                          : (t['description'] ?? 'İşlem').toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr • ${isPaid ? 'Ödendi' : 'Bekliyor'}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                fmt.format(amt),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summary(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
