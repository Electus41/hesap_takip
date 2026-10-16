import 'package:flutter/material.dart';
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

  List<Map<String, dynamic>> _clients = [];
  String? _selectedClientId;
  DateTimeRange? _range;

  List<Map<String, dynamic>> _transactions = [];
  double _totalDebt = 0.0;
  double _totalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'].toString();

      final res = await supabase
          .from('clients')
          .select('id, title')
          .eq('company_id', _companyId)
          .order('title', ascending: true);

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatement() async {
    if (_selectedClientId == null) return;
    setState(() => _isLoadingStatement = true);

    try {
      var query = supabase
          .from('transactions')
          .select()
          .eq('client_id', _selectedClientId!);

      if (_range != null) {
        query = query
            .gte('due_date', _range!.start.toIso8601String().split('T')[0])
            .lte('due_date', _range!.end.toIso8601String().split('T')[0]);
      }

      final res = await query.order('due_date', ascending: true);
      final list = List<Map<String, dynamic>>.from(res);

      double debt = 0.0;
      double paid = 0.0;
      for (var t in list) {
        final amt = double.tryParse(t['amount'].toString()) ?? 0.0;
        debt += amt;
        if (t['is_paid'] == true) paid += amt;
      }

      if (mounted) {
        setState(() {
          _transactions = list;
          _totalDebt = debt;
          _totalPaid = paid;
          _isLoadingStatement = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStatement = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ekstre yüklenemedi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ŞIK, KOYU TEMALI VE TÜRKÇE ÖZEL TARİH SEÇİCİ DİYALOĞU
  Future<void> _pickRange() async {
    DateTime? tempStart = _range?.start;
    DateTime? tempEnd = _range?.end;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Rapor Tarih Aralığı Seçin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text(
                        'Başlangıç Tarihi',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      subtitle: Text(
                        tempStart == null
                            ? 'Seçilmedi'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'tr_TR',
                              ).format(tempStart!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF00ACC1),
                        size: 18,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempStart ?? DateTime.now(),
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2035),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (picked != null) {
                          setDialogState(() => tempStart = picked);
                        }
                      },
                    ),
                    const Divider(color: Colors.white12),
                    ListTile(
                      title: const Text(
                        'Bitiş Tarihi',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      subtitle: Text(
                        tempEnd == null
                            ? 'Seçilmedi'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'tr_TR',
                              ).format(tempEnd!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF00ACC1),
                        size: 18,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempEnd ?? DateTime.now(),
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2035),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (picked != null) {
                          setDialogState(() => tempEnd = picked);
                        }
                      },
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ACC1),
                  ),
                  onPressed: () {
                    if (tempStart != null && tempEnd != null) {
                      setState(() {
                        _range = DateTimeRange(
                          start: tempStart!,
                          end: tempEnd!,
                        );
                      });
                      Navigator.pop(context);
                      _loadStatement();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Lütfen başlangıç ve bitiş tarihlerini seçin.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Uygula',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _exportPdf() {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce PDF raporu için bir mükellef seçin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    // PDF İndirme / Paylaşma Aksiyonu
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF ekstre raporu hazırlanıyor...'),
        backgroundColor: Color(0xFF00ACC1),
      ),
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
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            tooltip: 'PDF Rapor İndir',
            onPressed: _exportPdf,
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
                  DropdownButtonFormField<String>(
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
                    items: _clients
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c['id'].toString(),
                            child: Text((c['title'] ?? 'Mükellef').toString()),
                          ),
                        )
                        .toList(),
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
                            Icons.date_range,
                            color: Color(0xFF00ACC1),
                            size: 18,
                          ),
                          label: Text(
                            _range == null
                                ? 'Tarih Aralığı (Tümü)'
                                : '${DateFormat('dd.MM.yyyy', 'tr_TR').format(_range!.start)} - ${DateFormat('dd.MM.yyyy', 'tr_TR').format(_range!.end)}',
                            style: const TextStyle(color: Colors.white),
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
                            'Toplam Borç',
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
    if (_selectedClientId == null) {
      return const Center(
        child: Text(
          'Ekstre görmek için bir mükellef seçin.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }
    if (_isLoadingStatement) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
      );
    }
    if (_transactions.isEmpty) {
      return const Center(
        child: Text(
          'Bu mükellef için kayıt bulunamadı.',
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
                      (t['description'] ?? 'İşlem').toString(),
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
