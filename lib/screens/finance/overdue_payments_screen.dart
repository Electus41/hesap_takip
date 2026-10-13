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

  List<Map<String, dynamic>> _overdueClients = [];

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

      // SADECE ödenmemiş (is_paid: false) işlemleri mükellef bilgisiyle çek
      final txRes = await supabase
          .from('transactions')
          .select('amount, clients(id, title)')
          .eq('company_id', _companyId)
          .eq('is_paid', false);

      // Borçları mükellefe göre grupla ve toplam tutarı bul
      Map<String, Map<String, dynamic>> grouped = {};

      for (var t in txRes) {
        final client = t['clients'] as Map<String, dynamic>?;
        if (client == null) continue;

        final clientId = client['id'].toString();
        final amount = double.tryParse(t['amount'].toString()) ?? 0.0;

        if (grouped.containsKey(clientId)) {
          grouped[clientId]!['total_debt'] += amount;
        } else {
          grouped[clientId] = {
            'id': clientId,
            'title': client['title'],
            'total_debt': amount,
          };
        }
      }

      if (mounted) {
        setState(() {
          _overdueClients = grouped.values.toList();
          // Borcu en yüksek olandan en düşüğe doğru sırala
          _overdueClients.sort(
            (a, b) => b['total_debt'].compareTo(a['total_debt']),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Geciken ödemeler hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // İŞTE SİHİRLİ WHATSAPP FONKSİYONU
  Future<void> _sendWhatsAppMessage(String clientTitle, double debt) async {
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
    );
    final formattedDebt = currencyFormatter.format(debt);

    // Gönderilecek otomatik mesaj metni
    final message =
        "Merhaba Sayın $clientTitle yetkilisi,\n\nSistemimizde bekleyen $formattedDebt tutarında muhasebe / hizmet bedeli ödemeniz bulunmaktadır. Müsait olduğunuzda hesaplarımızı kontrol etmenizi rica ederiz.\n\nİyi çalışmalar dileriz.";

    // Telefon numarasını zorunlu tutmadan, direkt WhatsApp'ı açıp kişiyi seçmeni sağlayan evrensel link
    final Uri url = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'WhatsApp açılamadı. Cihazınızda yüklü olduğundan emin olun.',
              ),
            ),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
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
          'Geciken Ödemeler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : _overdueClients.isEmpty
          ? const Center(
              child: Text(
                'Harika! Geciken hiçbir ödeme yok.',
                style: TextStyle(color: Colors.greenAccent, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(32),
              itemCount: _overdueClients.length,
              itemBuilder: (context, index) {
                final client = _overdueClients[index];
                final debt = client['total_debt'] as double;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                    title: Text(
                      client['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Toplam Bekleyen Bakiye',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currencyFormatter.format(debt),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 24),
                        // WHATSAPP BUTONU
                        ElevatedButton.icon(
                          onPressed: () =>
                              _sendWhatsAppMessage(client['title'], debt),
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'WhatsApp',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF25D366,
                            ), // Orijinal WhatsApp Yeşili
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
