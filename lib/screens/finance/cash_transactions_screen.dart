import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CashTransactionsScreen extends StatefulWidget {
  const CashTransactionsScreen({super.key});

  @override
  State<CashTransactionsScreen> createState() => _CashTransactionsScreenState();
}

class _CashTransactionsScreenState extends State<CashTransactionsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _companyId = '';

  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _expenses = [];

  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCashData();
  }

  Future<void> _fetchCashData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'];

      // 1. Şirketin tüm mükelleflerini al (Gelirleri eşleştirmek için)
      final clientsRes = await supabase
          .from('clients')
          .select('id, title')
          .eq('company_id', _companyId);

      final Map<String, String> clientMap = {};
      for (var c in clientsRes) {
        clientMap[c['id'].toString()] = (c['title'] ?? 'Mükellef').toString();
      }

      // 2. Tahsil edilmiş (is_paid == true) gelirleri çek
      List<Map<String, dynamic>> paidIncomes = [];
      double incomeSum = 0.0;

      if (clientMap.isNotEmpty) {
        final txRes = await supabase
            .from('transactions')
            .select()
            .inFilter('client_id', clientMap.keys.toList())
            .order('created_at', ascending: false);

        for (var t in txRes) {
          if (t['is_paid'] == true) {
            final amt = double.tryParse(t['amount'].toString()) ?? 0.0;
            incomeSum += amt;
            paidIncomes.add({
              ...t,
              'client_title':
                  clientMap[t['client_id'].toString()] ?? 'Mükellef',
            });
          }
        }
      }

      // 3. Ofis Masraflarını / Giderlerini çek (expenses tablosu varsa)
      List<Map<String, dynamic>> expenseList = [];
      double expenseSum = 0.0;
      try {
        final expRes = await supabase
            .from('expenses')
            .select()
            .eq('company_id', _companyId)
            .order('created_at', ascending: false);

        for (var ex in expRes) {
          final amt = double.tryParse(ex['amount'].toString()) ?? 0.0;
          expenseSum += amt;
          expenseList.add(ex);
        }
      } catch (_) {
        // Eğer expenses tablosu henüz yoksa hata vermeden 0 olarak devam eder
      }

      if (mounted) {
        setState(() {
          _incomes = paidIncomes;
          _expenses = expenseList;
          _totalIncome = incomeSum;
          _totalExpense = expenseSum;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // MOBİL VE WEB UYUMLU YENİ GİDER / MASRAF EKLEME PENCERESİ
  void _showAddExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'Ofis Gideri (Kira / Fatura)';
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
                Icon(Icons.trending_down, color: Colors.redAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Yeni Masraf / Gider Ekle',
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
                width: isMobile ? screenWidth : 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF222222),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Gider Kategorisi',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          color: Colors.white38,
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
                          value: 'Ofis Gideri (Kira / Fatura)',
                          child: Text(
                            'Ofis Gideri (Kira / Elektrik / İnternet)',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Personel / Maaş / Yemek',
                          child: Text('Personel / Maaş / Yemek Gideri'),
                        ),
                        DropdownMenuItem(
                          value: 'Kırtasiye & Donanım',
                          child: Text('Kırtasiye / Yazılım / Donanım'),
                        ),
                        DropdownMenuItem(
                          value: 'Vergi & Resmi Harçlar',
                          child: Text('Vergi & Resmi Harçlar'),
                        ),
                        DropdownMenuItem(
                          value: 'Diğer Masraflar',
                          child: Text('Diğer Genel Masraflar'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText:
                            'Masraf Açıklaması (Örn: Ekim Ayı Ofis Kirası)',
                        labelStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.description_outlined,
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
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Tutar (₺)',
                        labelStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.currency_lira,
                          color: Colors.redAccent,
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
                        final amount =
                            double.tryParse(
                              amountCtrl.text.replaceAll(',', '.'),
                            ) ??
                            0.0;
                        if (titleCtrl.text.trim().isEmpty || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lütfen masraf açıklamasını ve geçerli bir tutarı girin.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          await supabase.from('expenses').insert({
                            'company_id': _companyId,
                            'title': titleCtrl.text.trim(),
                            'category': selectedCategory,
                            'amount': amount,
                            'expense_date': DateTime.now()
                                .toIso8601String()
                                .split('T')[0],
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchCashData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Masraf kaydı başarıyla eklendi!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gider kaydedilemedi: $e'),
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
                        'Masrafı Kaydet',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  Future<void> _revertIncomeToUnpaid(String txId) async {
    await supabase
        .from('transactions')
        .update({'is_paid': false})
        .eq('id', txId);
    _fetchCashData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tahsilat geri alındı (Bekleyen ödemelere aktarıldı).'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _deleteExpense(String expId) async {
    await supabase.from('expenses').delete().eq('id', expId);
    _fetchCashData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masraf kaydı silindi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    final isMobile = MediaQuery.of(context).size.width < 600;
    final netProfit = _totalIncome - _totalExpense;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF101014),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16161A),
          elevation: 0,
          title: const Text(
            'Kasa & Gider Yönetimi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFF00ACC1),
            labelColor: Color(0xFF00ACC1),
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'Tahsilatlar (Gelir)'),
              Tab(text: 'Masraflar (Gider)'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddExpenseDialog,
          backgroundColor: Colors.redAccent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Masraf Ekle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
              )
            : Column(
                children: [
                  // ===========================================================
                  // ÜST ÖZET KARTI (TAŞMA YAPMAYAN ESNEK FITTEDBOX TASARIMI)
                  // ===========================================================
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.all(isMobile ? 14 : 24),
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 18 : 24,
                      horizontal: isMobile ? 12 : 24,
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
                        // 1. KUTU: TOPLAM KASA (GİRİŞ)
                        Expanded(
                          child: _buildSummaryColumn(
                            label: 'Toplam Giriş',
                            amountText: currencyFormatter.format(_totalIncome),
                            color: Colors.greenAccent,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: Colors.white12,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        // 2. KUTU: TOPLAM GİDER (ÇIKIŞ)
                        Expanded(
                          child: _buildSummaryColumn(
                            label: 'Toplam Çıkış',
                            amountText: currencyFormatter.format(_totalExpense),
                            color: Colors.redAccent,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: Colors.white12,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        // 3. KUTU: NET KÂR / BAKİYE
                        Expanded(
                          child: _buildSummaryColumn(
                            label: 'Net Kasa / Kâr',
                            amountText: currencyFormatter.format(netProfit),
                            color: const Color(0xFF00ACC1),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ===========================================================
                  // SEKMELİ LİSTE ALANI (MODERN KART GÖRÜNÜMÜ)
                  // ===========================================================
                  Expanded(
                    child: TabBarView(
                      children: [
                        // 1. SEKME: TAHSİLATLAR (GELİR)
                        _incomes.isEmpty
                            ? const Center(
                                child: Text(
                                  'Henüz tamamlanmış bir tahsilat bulunmuyor.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 14 : 24,
                                  vertical: 4,
                                ),
                                itemCount: _incomes.length,
                                itemBuilder: (context, index) {
                                  final item = _incomes[index];
                                  final clientTitle =
                                      item['client_title'] ?? 'Mükellef';
                                  final desc =
                                      item['description'] ?? 'Tahsilat İşlemi';
                                  final amt =
                                      double.tryParse(
                                        item['amount'].toString(),
                                      ) ??
                                      0.0;

                                  String dateStr = '';
                                  final rawDate =
                                      item['due_date'] ?? item['created_at'];
                                  if (rawDate != null) {
                                    try {
                                      dateStr = DateFormat('dd.MM.yyyy').format(
                                        DateTime.parse(rawDate.toString()),
                                      );
                                    } catch (_) {}
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A20),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent
                                                .withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_downward_rounded,
                                            color: Colors.greenAccent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                clientTitle,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                desc,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (dateStr.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Tarih: $dateStr',
                                                  style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '+ ${currencyFormatter.format(amt)}',
                                              style: const TextStyle(
                                                color: Colors.greenAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(
                                                Icons.more_horiz,
                                                color: Colors.white38,
                                                size: 20,
                                              ),
                                              color: const Color(0xFF222222),
                                              onSelected: (val) {
                                                if (val == 'unpaid') {
                                                  _revertIncomeToUnpaid(
                                                    item['id'].toString(),
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'unpaid',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.undo,
                                                        color:
                                                            Colors.orangeAccent,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Tahsilatı Geri Al',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                        // 2. SEKME: MASRAFLAR (GİDER)
                        _expenses.isEmpty
                            ? const Center(
                                child: Text(
                                  'Henüz kaydedilmiş bir ofis masrafı bulunmuyor.\nSağ alttaki "Masraf Ekle" butonundan ekleyebilirsiniz.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 14 : 24,
                                  vertical: 4,
                                ),
                                itemCount: _expenses.length,
                                itemBuilder: (context, index) {
                                  final exp = _expenses[index];
                                  final title = exp['title'] ?? 'Ofis Gideri';
                                  final category =
                                      exp['category'] ?? 'Genel Masraf';
                                  final amt =
                                      double.tryParse(
                                        exp['amount'].toString(),
                                      ) ??
                                      0.0;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A20),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withValues(
                                              alpha: 0.12,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_upward_rounded,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                category,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          children: [
                                            Text(
                                              '- ${currencyFormatter.format(amt)}',
                                              style: const TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.white38,
                                                size: 20,
                                              ),
                                              onPressed: () => _deleteExpense(
                                                exp['id'].toString(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryColumn({
    required String label,
    required String amountText,
    required Color color,
  }) {
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
            amountText,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
