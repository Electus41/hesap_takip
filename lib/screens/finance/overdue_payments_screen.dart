import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class OverduePaymentsScreen extends StatefulWidget {
  const OverduePaymentsScreen({super.key});

  @override
  State<OverduePaymentsScreen> createState() => _OverduePaymentsScreenState();
}

class _OverduePaymentsScreenState extends State<OverduePaymentsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _companyId = '';

  List<Map<String, dynamic>> _overdueTransactions = [];
  double _totalOverdueAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchOverduePayments();
  }

  Future<void> _fetchOverduePayments() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'];

      final res = await supabase
          .from('transactions')
          .select('*, clients(title, phone, contact_name)')
          .eq('company_id', _companyId)
          .eq('is_paid', false)
          .order('due_date', ascending: true);

      double total = 0.0;
      final today = DateTime.now();
      List<Map<String, dynamic>> processedList = [];

      for (var t in res) {
        final totalAmount = double.tryParse(t['amount'].toString()) ?? 0.0;
        final paidAmount =
            double.tryParse(t['paid_amount']?.toString() ?? '0') ?? 0.0;
        final remainingAmount = totalAmount - paidAmount;

        if (remainingAmount <= 0) continue; // Hata payı kontrolü

        total += remainingAmount;

        bool isOverdue = false;
        int delayDays = 0;
        if (t['due_date'] != null) {
          final dueDate = DateTime.parse(t['due_date'].toString());
          if (dueDate.isBefore(DateTime(today.year, today.month, today.day))) {
            isOverdue = true;
            delayDays = today.difference(dueDate).inDays;
          }
        }

        var item = Map<String, dynamic>.from(t);
        item['is_overdue'] = isOverdue;
        item['delay_days'] = delayDays;
        item['remaining_amount'] = remainingAmount;
        item['paid_amount'] = paidAmount;
        processedList.add(item);
      }

      if (mounted) {
        setState(() {
          _overdueTransactions = processedList;
          _totalOverdueAmount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPartialPaymentDialog(
    Map<String, dynamic> transaction,
  ) async {
    final remaining = transaction['remaining_amount'] as double;
    final totalAmount =
        double.tryParse(transaction['amount'].toString()) ?? 0.0;
    final currentPaid = transaction['paid_amount'] as double;

    final controller = TextEditingController(
      text: remaining.toStringAsFixed(2),
    );
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
              'Tahsilat Alın',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Toplam Borç: ₺$totalAmount',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kalan Bakiye: ₺$remaining',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Alınan Tutar (₺)',
                          labelStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
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
                        final entered =
                            double.tryParse(
                              controller.text.replaceAll(',', '.'),
                            ) ??
                            0.0;
                        if (entered <= 0) return;

                        setDialogState(() => isProcessing = true);

                        try {
                          if (entered >= remaining) {
                            // Borcun tamamı veya fazlası ödendiyse işlemi kapat
                            await supabase
                                .from('transactions')
                                .update({
                                  'is_paid': true,
                                  'paid_amount': totalAmount,
                                })
                                .eq('id', transaction['id']);
                          } else {
                            // Kısmi tahsilat yapıldıysa sadece ödenen tutarı artır
                            await supabase
                                .from('transactions')
                                .update({'paid_amount': currentPaid + entered})
                                .eq('id', transaction['id']);
                          }

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Tahsilat başarıyla kasaya eklendi!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchOverduePayments();
                          }
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Hata oluştu.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                      ),
                      child: const Text(
                        'Kasaya Ekle',
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

  Future<void> _sendWhatsAppReminder(Map<String, dynamic> transaction) async {
    final clientInfo = transaction['clients'] as Map<String, dynamic>?;
    if (clientInfo == null ||
        clientInfo['phone'] == null ||
        clientInfo['phone'].toString().isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mükellefe ait kayıtlı telefon numarası bulunamadı!'),
            backgroundColor: Colors.orange,
          ),
        );
      return;
    }

    String phone = clientInfo['phone'].toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (!phone.startsWith('90') && phone.length == 10) phone = '90$phone';

    final amount = transaction['remaining_amount'] as double;
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final String msg =
        'Merhaba ${clientInfo['contact_name'] ?? clientInfo['title']},\n\nKayıtlarımıza göre ${transaction['description']} işlemine ait (Kalan Tutar: ${formatter.format(amount)}) ödemeniz gecikmiştir. Ödemenizi en kısa sürede tamamlamanızı rica ederiz.\n\nİyi çalışmalar dileriz.';

    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp başlatılamadı.'),
            backgroundColor: Colors.red,
          ),
        );
    }
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
          'Bekleyen / Gecikmiş Ödemeler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16161A),
                    border: Border(
                      bottom: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Toplam Bekleyen Alacak Tutarı',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormatter.format(_totalOverdueAmount),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bekleyen İşlem Sayısı: ${_overdueTransactions.length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _overdueTransactions.isEmpty
                      ? const Center(
                          child: Text(
                            'Harika! Tüm mükellefler ödemelerini yapmış.',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(32),
                          itemCount: _overdueTransactions.length,
                          itemBuilder: (context, index) {
                            final t = _overdueTransactions[index];
                            final clientInfo =
                                t['clients'] as Map<String, dynamic>?;
                            final remaining = t['remaining_amount'] as double;
                            final isOverdue = t['is_overdue'] as bool;
                            final delayDays = t['delay_days'] as int;

                            String dateText = '-';
                            if (t['due_date'] != null) {
                              try {
                                dateText = DateFormat(
                                  'dd.MM.yyyy',
                                ).format(DateTime.parse(t['due_date']));
                              } catch (_) {}
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A20),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isOverdue
                                            ? Colors.redAccent.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.orangeAccent.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isOverdue
                                            ? Icons.warning_amber_rounded
                                            : Icons.schedule,
                                        color: isOverdue
                                            ? Colors.redAccent
                                            : Colors.orangeAccent,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 24),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            clientInfo?['title'] ??
                                                'Bilinmeyen Mükellef',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${t['description']} • Vade: $dateText',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          if (isOverdue)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Vadesi $delayDays gün geçti',
                                                style: const TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          currencyFormatter.format(remaining),
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _sendWhatsAppReminder(t),
                                              icon: const Icon(
                                                Icons.chat,
                                                size: 16,
                                                color: Colors.greenAccent,
                                              ),
                                              label: const Text(
                                                'Hatırlat',
                                                style: TextStyle(
                                                  color: Colors.greenAccent,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                  color: Colors.greenAccent,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _showPartialPaymentDialog(t),
                                              icon: const Icon(
                                                Icons.point_of_sale,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                'Tahsil Et',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF00ACC1,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
    );
  }
}
