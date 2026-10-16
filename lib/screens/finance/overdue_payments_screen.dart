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
  String _filterType = 'all'; // 'all' | 'overdue' | 'upcoming'

  List<Map<String, dynamic>> _unpaidList = [];
  double _totalOverdueAmount = 0.0;
  double _totalUpcomingAmount = 0.0;

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
      _companyId = profile['company_id'].toString();

      final clientsRes = await supabase
          .from('clients')
          .select('id, title, phone')
          .eq('company_id', _companyId);

      final Map<String, Map<String, dynamic>> clientMap = {};
      for (var c in clientsRes) {
        clientMap[c['id'].toString()] = c;
      }

      if (clientMap.isEmpty) {
        if (mounted) {
          setState(() {
            _unpaidList = [];
            _totalOverdueAmount = 0.0;
            _totalUpcomingAmount = 0.0;
            _isLoading = false;
          });
        }
        return;
      }

      final txRes = await supabase
          .from('transactions')
          .select()
          .inFilter('client_id', clientMap.keys.toList())
          .order('due_date', ascending: true);

      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);

      double overdueSum = 0.0;
      double upcomingSum = 0.0;
      List<Map<String, dynamic>> list = [];

      for (var t in txRes) {
        final isPaid = t['is_paid'] == true;
        if (!isPaid) {
          final amount = double.tryParse(t['amount'].toString()) ?? 0.0;
          final cInfo = clientMap[t['client_id'].toString()];

          DateTime dueOnly = todayOnly;
          if (t['due_date'] != null) {
            try {
              final p = DateTime.parse(t['due_date'].toString());
              dueOnly = DateTime(p.year, p.month, p.day);
            } catch (_) {}
          }

          final diffDays = dueOnly.difference(todayOnly).inDays;
          final bool isOverdue = diffDays < 0;

          if (isOverdue) {
            overdueSum += amount;
          } else {
            upcomingSum += amount;
          }

          list.add({
            ...t,
            'client_title': cInfo?['title'] ?? 'Bilinmeyen Mükellef',
            'client_phone': cInfo?['phone'] ?? '',
            'parsed_due': dueOnly,
            'diff_days': diffDays,
            'is_overdue': isOverdue,
          });
        }
      }

      if (mounted) {
        setState(() {
          _unpaidList = list;
          _totalOverdueAmount = overdueSum;
          _totalUpcomingAmount = upcomingSum;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // KISMİ VEYA TAM TAHSİLAT PENCERESİ (KISMİ ÖDEMEYİ KASAYA DA GELİR OLARAK EKLER!)
  void _showPaymentDialog(Map<String, dynamic> item) {
    final double maxAmount = double.tryParse(item['amount'].toString()) ?? 0.0;
    final amountController = TextEditingController(
      text: maxAmount.toStringAsFixed(0),
    );
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Tahsilat Al: ${item['client_title']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kalem: ${item['description'] ?? ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kalan Alacak: ₺${maxAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ActionChip(
                        label: const Text('Tamamını Seç'),
                        backgroundColor: const Color(
                          0xFF00ACC1,
                        ).withValues(alpha: 0.2),
                        labelStyle: const TextStyle(
                          color: Color(0xFF00ACC1),
                          fontSize: 12,
                        ),
                        onPressed: () {
                          amountController.text = maxAmount.toStringAsFixed(0);
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('Yarısını Seç (%50)'),
                        backgroundColor: Colors.white10,
                        labelStyle: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        onPressed: () {
                          amountController.text = (maxAmount / 2)
                              .toStringAsFixed(0);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Tahsil Edilecek Tutar (₺)',
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
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final enteredAmount = double.tryParse(
                            amountController.text.replaceAll(',', '.'),
                          );
                          if (enteredAmount == null || enteredAmount <= 0) {
                            return;
                          }

                          setDialogState(() => isProcessing = true);

                          try {
                            final transactionId = item['id'].toString();

                            if (enteredAmount >= maxAmount) {
                              // Tam ödeme: doğrudan borcu ödendi yap
                              await supabase
                                  .from('transactions')
                                  .update({'is_paid': true})
                                  .eq('id', transactionId);
                            } else {
                              // Kısmi ödeme:
                              // 1. Kalan borcu güncelle
                              final remainingAmount = maxAmount - enteredAmount;
                              await supabase
                                  .from('transactions')
                                  .update({'amount': remainingAmount})
                                  .eq('id', transactionId);

                              // 2. Tahsil edilen kısmı kasaya (is_paid: true) gelir olarak ekle!
                              await supabase.from('transactions').insert({
                                'company_id': item['company_id'] ?? _companyId,
                                'client_id': item['client_id'],
                                'payment_type_id': item['payment_type_id'],
                                'description':
                                    '${item['description'] ?? 'Hizmet'} (Kısmi Tahsilat)',
                                'amount': enteredAmount,
                                'is_paid': true,
                                'due_date': DateFormat(
                                  'yyyy-MM-dd',
                                ).format(DateTime.now()),
                                'frequency': 'one_time',
                                'period_key':
                                    'PARTIAL_${DateTime.now().millisecondsSinceEpoch}',
                              });
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tahsilat başarıyla kasaya işlendi!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _fetchOverduePayments();
                            }
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tahsilat işlenirken hata oluştu.',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                  child: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Tahsilatı Onayla',
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

  Future<void> _sendWhatsAppReminder(
    String clientTitle,
    String phone,
    String desc,
    double amount,
    String dueDateStr,
  ) async {
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
    );
    final message =
        'Sayın $clientTitle, "$desc" kalemine ait (Son Ödeme: $dueDateStr) ${currencyFormatter.format(amount)} tutarındaki ödemenizi hatırlatmak isteriz. İyi çalışmalar dileriz.';

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '90${cleanPhone.substring(1)}';
    } else if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('90')) {
      cleanPhone = '90$cleanPhone';
    }

    final Uri whatsappUri = Uri.parse(
      cleanPhone.isNotEmpty
          ? 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}'
          : 'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  String _getFrequencyBadgeText(String? freq) {
    if (freq == 'monthly') return 'Aylık Düzenli';
    if (freq == 'yearly') return 'Yıllık Düzenli';
    return '1 Defalık';
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
    );
    final isMobile = MediaQuery.of(context).size.width < 600;

    final filteredList = _unpaidList.where((item) {
      if (_filterType == 'overdue') return item['is_overdue'] == true;
      if (_filterType == 'upcoming') return item['is_overdue'] == false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        title: const Text(
          'Bekleyen & Gecikmiş Alacaklar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Column(
              children: [
                // ÜST ÖZET VE FİLTRE ALANI
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 16 : 22,
                    horizontal: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16161A),
                    border: Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Vadesi Geçmiş (Geciken)',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currencyFormatter.format(_totalOverdueAmount),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white12,
                          ),
                          Column(
                            children: [
                              const Text(
                                'Vadesi Beklenen (Gelecek)',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currencyFormatter.format(_totalUpcomingAmount),
                                style: const TextStyle(
                                  color: Color(0xFF00ACC1),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        children: [
                          ChoiceChip(
                            label: Text('Tümü (${_unpaidList.length})'),
                            selected: _filterType == 'all',
                            selectedColor: const Color(0xFF00ACC1),
                            labelStyle: TextStyle(
                              color: _filterType == 'all'
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) =>
                                setState(() => _filterType = 'all'),
                          ),
                          ChoiceChip(
                            label: Text(
                              '🚨 Vadesi Geçenler (${_unpaidList.where((e) => e['is_overdue'] == true).length})',
                            ),
                            selected: _filterType == 'overdue',
                            selectedColor: Colors.redAccent,
                            labelStyle: TextStyle(
                              color: _filterType == 'overdue'
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) =>
                                setState(() => _filterType = 'overdue'),
                          ),
                          ChoiceChip(
                            label: Text(
                              '⏳ Vadesi Beklenenler (${_unpaidList.where((e) => e['is_overdue'] == false).length})',
                            ),
                            selected: _filterType == 'upcoming',
                            selectedColor: Colors.orangeAccent,
                            labelStyle: TextStyle(
                              color: _filterType == 'upcoming'
                                  ? Colors.black
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) =>
                                setState(() => _filterType = 'upcoming'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // LİSTE ALANI
                Expanded(
                  child: filteredList.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.greenAccent,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Bu filtrede bekleyen alacak bulunmuyor!',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final item = filteredList[index];
                            final clientTitle =
                                item['client_title'] ?? 'Mükellef';
                            final clientPhone = item['client_phone'] ?? '';
                            final amount =
                                double.tryParse(item['amount'].toString()) ??
                                0.0;
                            final desc =
                                item['description'] ?? 'Belirtilmemiş İşlem';
                            final freq = item['frequency']?.toString();
                            final int diffDays = item['diff_days'] as int;
                            final bool isOverdue = item['is_overdue'] as bool;

                            final String dateStr = DateFormat(
                              'dd.MM.yyyy',
                            ).format(item['parsed_due'] as DateTime);

                            // VADE DURUMUNA GÖRE RENK VE ETİKET
                            Color statusColor;
                            String statusText;
                            IconData statusIcon;

                            if (isOverdue) {
                              statusColor = Colors.redAccent;
                              statusText = '${diffDays.abs()} Gün Gecikti!';
                              statusIcon = Icons.warning_amber_rounded;
                            } else if (diffDays == 0) {
                              statusColor = Colors.orangeAccent;
                              statusText = 'Son Gün Bugün!';
                              statusIcon = Icons.notification_important;
                            } else if (diffDays <= 3) {
                              statusColor = Colors.orangeAccent;
                              statusText = 'Vadeye $diffDays Gün Kaldı';
                              statusIcon = Icons.schedule;
                            } else {
                              statusColor = const Color(0xFF00ACC1);
                              statusText =
                                  'Vadesi Bekleniyor ($diffDays gün var)';
                              statusIcon = Icons.event_available;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A20),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          statusIcon,
                                          color: statusColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              clientTitle,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              desc,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            currencyFormatter.format(amount),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _getFrequencyBadgeText(freq),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(
                                    color: Colors.white12,
                                    height: 1,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Son Ödeme: $dateStr',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _sendWhatsAppReminder(
                                                  clientTitle,
                                                  clientPhone,
                                                  desc,
                                                  amount,
                                                  dateStr,
                                                ),
                                            icon: const Icon(
                                              Icons.chat_bubble_outline,
                                              color: Colors.greenAccent,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Hatırlat',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.greenAccent,
                                                width: 0.8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _showPaymentDialog(item),
                                            icon: const Icon(
                                              Icons.point_of_sale,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Tahsil Et',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF00ACC1,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
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
                ),
              ],
            ),
    );
  }
}
