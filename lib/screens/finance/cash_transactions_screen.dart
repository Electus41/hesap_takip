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
    _fetchFinancialData();
  }

  Future<void> _fetchFinancialData() async {
    try {
      final user = supabase.auth.currentUser;
      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user!.id)
          .single();
      _companyId = profile['company_id'];

      // 1. Gelirleri Çek (Ödenen Tahsilatlar)
      final incomeRes = await supabase
          .from('transactions')
          .select('*, clients(title)')
          .eq('company_id', _companyId)
          .gt('paid_amount', 0)
          .order('created_at', ascending: false);

      // 2. Giderleri Çek
      final expenseRes = await supabase
          .from('expenses')
          .select()
          .eq('company_id', _companyId)
          .order('expense_date', ascending: false);

      double tIncome = 0.0;
      for (var inc in incomeRes) {
        tIncome += double.tryParse(inc['paid_amount'].toString()) ?? 0.0;
      }

      double tExpense = 0.0;
      for (var exp in expenseRes) {
        tExpense += double.tryParse(exp['amount'].toString()) ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _incomes = List<Map<String, dynamic>>.from(incomeRes);
          _expenses = List<Map<String, dynamic>>.from(expenseRes);
          _totalIncome = tIncome;
          _totalExpense = tExpense;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addExpense() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Yeni Gider / Masraf Ekle',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: isProcessing
                ? const SizedBox(
                    height: 100,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00ACC1),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Gider Açıklaması (Örn: Kira, Elektrik)',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF101014),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tutar (₺)',
                          labelStyle: const TextStyle(color: Colors.white54),
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
            actions: isProcessing
                ? []
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
                        if (titleController.text.isEmpty ||
                            amountController.text.isEmpty)
                          return;
                        setDialogState(() => isProcessing = true);
                        try {
                          final amt =
                              double.tryParse(
                                amountController.text.replaceAll(',', '.'),
                              ) ??
                              0.0;
                          await supabase.from('expenses').insert({
                            'company_id': _companyId,
                            'title': titleController.text.trim(),
                            'amount': amt,
                            'expense_date': DateTime.now().toIso8601String(),
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            _fetchFinancialData();
                          }
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text(
                        'Masrafı Kaydet',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
    );
    final netKar = _totalIncome - _totalExpense;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF101014),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16161A),
          title: const Text(
            'Kasa & Gider Yönetimi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFF00ACC1),
            labelColor: Color(0xFF00ACC1),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Tahsilatlar (Gelir)'),
              Tab(text: 'Masraflar (Gider)'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16161A),
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Toplam Kasa (Giriş)',
                              style: TextStyle(color: Colors.white54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(_totalIncome),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(height: 40, width: 1, color: Colors.white12),
                        Column(
                          children: [
                            const Text(
                              'Toplam Gider (Çıkış)',
                              style: TextStyle(color: Colors.white54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(_totalExpense),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(height: 40, width: 1, color: Colors.white12),
                        Column(
                          children: [
                            const Text(
                              'Net Kâr',
                              style: TextStyle(color: Colors.white54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(netKar),
                              style: TextStyle(
                                color: netKar >= 0
                                    ? const Color(0xFF00ACC1)
                                    : Colors.redAccent,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // GELİRLER LİSTESİ
                        ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: _incomes.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white12),
                          itemBuilder: (context, index) {
                            final inc = _incomes[index];
                            final amt =
                                double.tryParse(
                                  inc['paid_amount'].toString(),
                                ) ??
                                0.0;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.greenAccent.withValues(
                                  alpha: 0.1,
                                ),
                                child: const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              title: Text(
                                inc['clients']?['title'] ?? 'Bilinmeyen',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                inc['description'] ?? '',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: Text(
                                '+ ${currencyFormatter.format(amt)}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          },
                        ),
                        // GİDERLER LİSTESİ
                        Stack(
                          children: [
                            ListView.separated(
                              padding: const EdgeInsets.all(24),
                              itemCount: _expenses.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(color: Colors.white12),
                              itemBuilder: (context, index) {
                                final exp = _expenses[index];
                                final amt =
                                    double.tryParse(exp['amount'].toString()) ??
                                    0.0;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.redAccent
                                        .withValues(alpha: 0.1),
                                    child: const Icon(
                                      Icons.arrow_upward,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  title: Text(
                                    exp['title'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateFormat('dd.MM.yyyy').format(
                                      DateTime.parse(exp['expense_date']),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                    ),
                                  ),
                                  trailing: Text(
                                    '- ${currencyFormatter.format(amt)}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              bottom: 32,
                              right: 32,
                              child: FloatingActionButton.extended(
                                onPressed: _addExpense,
                                backgroundColor: Colors.redAccent,
                                icon: const Icon(
                                  Icons.money_off,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Gider Ekle',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
