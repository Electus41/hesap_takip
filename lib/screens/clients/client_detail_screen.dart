import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/pdf_service.dart';

class ClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic>
  client; // Tıklanan mükellefin bilgileri buraya gelecek

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _companyName = 'Muhasebe Ofisi';
  List<Map<String, dynamic>> _transactions = [];
  double _totalDebt = 0;

  @override
  void initState() {
    super.initState();
    _fetchClientData();
  }

  Future<void> _fetchClientData() async {
    try {
      // Şirket adını çek (PDF'e basmak için lazım)
      final profile = await supabase
          .from('profiles')
          .select('companies(name)')
          .eq('id', supabase.auth.currentUser!.id)
          .single();
      final compData = profile['companies'] as Map<String, dynamic>?;
      if (compData != null) _companyName = compData['name'] ?? 'Muhasebe Ofisi';

      // Bu mükellefe ait TÜM hareketleri çek
      final txRes = await supabase
          .from('transactions')
          .select()
          .eq('client_id', widget.client['id'])
          .order('created_at', ascending: false);

      double debt = 0;
      for (var t in txRes) {
        if (t['is_paid'] == false) {
          debt += double.tryParse(t['amount'].toString()) ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(txRes);
          _totalDebt = debt;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text(
          widget.client['title'],
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Column(
              children: [
                // ÖZET VE PAYLAŞ BUTONU ALANI
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16161A),
                    border: Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Toplam Bekleyen Borç',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormatter.format(_totalDebt),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),

                      // İŞTE O SİHİRLİ PDF BUTONU
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Ekrana yükleniyor animasyonu verelim
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PDF Oluşturuluyor...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          await PdfService.generateAndShareEkstre(
                            companyName: _companyName,
                            client: widget.client,
                            transactions: _transactions,
                          );
                        },
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Ekstre PDF Gönder',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ACC1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // HAREKETLER LİSTESİ
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(32),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final t = _transactions[index];
                      final isPaid = t['is_paid'] as bool? ?? false;
                      final amount =
                          double.tryParse(t['amount'].toString()) ?? 0;

                      String dateText = '-';
                      if (t['created_at'] != null) {
                        try {
                          dateText = DateFormat(
                            'dd MMM yyyy HH:mm',
                            'tr_TR',
                          ).format(DateTime.parse(t['created_at']));
                        } catch (_) {}
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                              color: isPaid
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                              width: 4,
                            ),
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            t['description'] ?? 'İşlem',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            dateText,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            '${isPaid ? '+' : '-'}₺${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isPaid
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
