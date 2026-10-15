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
  List<Map<String, dynamic>> _overdueList = [];
  double _totalOverdue = 0.0;

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
      final String companyId = profile['company_id'];

      // Şirkete bağlı tüm mükellefleri çekiyoruz
      final clientsRes = await supabase
          .from('clients')
          .select('id, title, phone')
          .eq('company_id', companyId);

      final Map<String, Map<String, dynamic>> clientMap = {};
      for (var c in clientsRes) {
        clientMap[c['id'].toString()] = c;
      }

      if (clientMap.isEmpty) {
        if (mounted) {
          setState(() {
            _overdueList = [];
            _totalOverdue = 0.0;
            _isLoading = false;
          });
        }
        return;
      }

      // Mükelleflere ait tüm işlemleri çekip ödenmemişleri filtreliyoruz (Ana Ekran ile %100 aynı mantık)
      final txRes = await supabase
          .from('transactions')
          .select()
          .inFilter('client_id', clientMap.keys.toList())
          .order('due_date', ascending: true);

      double total = 0.0;
      List<Map<String, dynamic>> unpaidList = [];

      for (var t in txRes) {
        final isPaid = t['is_paid'] == true;
        if (!isPaid) {
          final amount = double.tryParse(t['amount'].toString()) ?? 0.0;
          total += amount;
          final cInfo = clientMap[t['client_id'].toString()];
          unpaidList.add({
            ...t,
            'client_title': cInfo?['title'] ?? 'Bilinmeyen Mükellef',
            'client_phone': cInfo?['phone'] ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _overdueList = unpaidList;
          _totalOverdue = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsPaid(String transactionId) async {
    try {
      await supabase
          .from('transactions')
          .update({'is_paid': true})
          .eq('id', transactionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tahsilat başarıyla alındı olarak işaretlendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _fetchOverduePayments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tahsilat işlenirken hata oluştu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _sendWhatsAppReminder(
    String clientTitle,
    String phone,
    String desc,
    double amount,
  ) async {
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
    );
    final message =
        'Sayın $clientTitle, "$desc" kalemine ait ${currencyFormatter.format(amount)} tutarındaki ödemenizi hatırlatmak isteriz. İyi çalışmalar dileriz.';

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

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        title: const Text(
          'Bekleyen / Gecikmiş Ödemeler',
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
                // ÜST ÖZET ALANI
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 20 : 28,
                    horizontal: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16161A),
                    border: Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Toplam Bekleyen Alacak Tutarı',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormatter.format(_totalOverdue),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bekleyen İşlem Sayısı: ${_overdueList.length}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // LİSTE ALANI (DİKEY UZAMAYAN MODERN KARTLAR)
                Expanded(
                  child: _overdueList.isEmpty
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
                                'Bekleyen veya geciken alacağınız bulunmuyor!',
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
                          itemCount: _overdueList.length,
                          itemBuilder: (context, index) {
                            final item = _overdueList[index];
                            final clientTitle =
                                item['client_title'] ?? 'Mükellef';
                            final clientPhone = item['client_phone'] ?? '';
                            final amount =
                                double.tryParse(item['amount'].toString()) ??
                                0.0;
                            final desc =
                                item['description'] ?? 'Belirtilmemiş İşlem';
                            final freq = item['frequency']?.toString();

                            String dateStr = 'Belirtilmemiş';
                            if (item['due_date'] != null) {
                              try {
                                dateStr = DateFormat('dd.MM.yyyy').format(
                                  DateTime.parse(item['due_date'].toString()),
                                );
                              } catch (_) {}
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A20),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. SATIR: İKON + MÜKELLEF ADI + TUTAR
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.orangeAccent.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.schedule,
                                          color: Colors.orangeAccent,
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
                                            style: const TextStyle(
                                              color: Colors.redAccent,
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
                                              color: const Color(
                                                0xFF00ACC1,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _getFrequencyBadgeText(freq),
                                              style: const TextStyle(
                                                color: Color(0xFF00ACC1),
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

                                  // 2. SATIR: VADE TARİHİ + HATIRLAT & TAHSİL ET BUTONLARI
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Vade: $dateStr',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
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
                                            onPressed: () => _markAsPaid(
                                              item['id'].toString(),
                                            ),
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
