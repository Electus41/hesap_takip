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

  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'];

      final txRes = await supabase
          .from('transactions')
          .select('*, clients(title)')
          .eq('company_id', _companyId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(txRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('İşlemler çekilirken hata: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // SİLME İŞLEMİ
  Future<void> _deleteTransaction(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A20),
        title: const Text('İşlemi Sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu finansal kaydı kalıcı olarak silmek istediğinize emin misiniz? (Bu işlem geri alınamaz).',
          style: TextStyle(color: Colors.white70),
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
              'Evet, Sil',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('transactions').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarıyla silindi.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchTransactions();
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Silinirken hata oluştu: $e')));
      }
    }
  }

  // DÜZENLEME İŞLEMİ DİYALOĞU
  void _showEditDialog(Map<String, dynamic> tx) {
    final amountController = TextEditingController(
      text: tx['amount'].toString(),
    );
    final descController = TextEditingController(text: tx['description'] ?? '');
    bool isPaid = tx['is_paid'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A20),
            title: const Text(
              'İşlemi Düzenle',
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                      'Ödendi (Tahsil Edildi) mi?',
                      style: TextStyle(color: Colors.white),
                    ),
                    activeColor: Colors.greenAccent,
                    value: isPaid,
                    onChanged: (val) => setDialogState(() => isPaid = val),
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
                onPressed: () async {
                  final amount =
                      double.tryParse(
                        amountController.text.replaceAll(',', '.'),
                      ) ??
                      0.0;
                  try {
                    await supabase
                        .from('transactions')
                        .update({
                          'description': descController.text.trim(),
                          'amount': amount,
                          'is_paid': isPaid,
                        })
                        .eq('id', tx['id']);

                    if (mounted) {
                      Navigator.pop(context);
                      _fetchTransactions();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kayıt güncellendi!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Hata: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                ),
                child: const Text(
                  'Kaydet',
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

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        title: const Text(
          'Kasa & Tüm Hareketler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : _transactions.isEmpty
          ? const Center(
              child: Text(
                'Kayıtlı hiçbir finansal hareket bulunamadı.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(32),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                final isPaid = tx['is_paid'] as bool? ?? false;
                final amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
                final clientInfo = tx['clients'] as Map<String, dynamic>?;
                final clientName =
                    clientInfo?['title'] ?? 'Bilinmeyen Mükellef';

                String dateText = '-';
                if (tx['created_at'] != null) {
                  try {
                    dateText = DateFormat(
                      'dd MMM yyyy HH:mm',
                      'tr_TR',
                    ).format(DateTime.parse(tx['created_at']));
                  } catch (_) {}
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isPaid
                          ? Colors.greenAccent.withValues(alpha: 0.1)
                          : Colors.orangeAccent.withValues(alpha: 0.1),
                      child: Icon(
                        isPaid ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isPaid
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      clientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${tx['description'] ?? 'İşlem'} • $dateText',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${isPaid ? '+' : '-'} ${currencyFormatter.format(amount)}',
                          style: TextStyle(
                            color: isPaid
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // DÜZENLE VE SİL MENÜSÜ
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white54,
                          ),
                          color: const Color(0xFF222222),
                          onSelected: (value) {
                            if (value == 'edit')
                              _showEditDialog(tx);
                            else if (value == 'delete')
                              _deleteTransaction(tx['id'].toString());
                          },
                          itemBuilder: (context) => [
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
                                    'Düzenle',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sil',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
