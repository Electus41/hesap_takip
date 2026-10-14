import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  String _companyId = '';

  double _totalAlacak = 0.0;
  double _totalKasa = 0.0;
  Map<String, double> _clientDebts = {};
  List<MapEntry<String, double>> _topDebtors = [];

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
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
          .select('amount, paid_amount, is_paid, clients(title)')
          .eq('company_id', _companyId);

      double kasa = 0.0;
      double alacak = 0.0;
      Map<String, double> debts = {};

      for (var t in res) {
        final totalAmount = double.tryParse(t['amount'].toString()) ?? 0.0;
        final paidAmount =
            double.tryParse(t['paid_amount']?.toString() ?? '0') ?? 0.0;
        final isPaid = t['is_paid'] as bool? ?? false;
        final clientTitle =
            (t['clients'] as Map<String, dynamic>?)?['title'] ??
            'Bilinmeyen Mükellef';

        if (isPaid) {
          kasa += totalAmount; // Tamamı ödendi
        } else {
          kasa += paidAmount; // Kısmi ödenen kısım kasada
          final remaining = totalAmount - paidAmount;
          if (remaining > 0) {
            alacak += remaining; // Kalan kısım alacakta
            debts[clientTitle] = (debts[clientTitle] ?? 0) + remaining;
          }
        }
      }

      var sortedDebts = debts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5 = sortedDebts.take(5).toList();

      if (mounted) {
        setState(() {
          _totalKasa = kasa;
          _totalAlacak = alacak;
          _clientDebts = debts;
          _topDebtors = top5;
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
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final bool isDataEmpty = _totalKasa == 0 && _totalAlacak == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        title: const Text(
          'Finansal Analiz & Raporlar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ofisinizin Genel Durumu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mükellef bazlı borç dağılımı ve genel tahsilat oranları.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 32),

                  Flex(
                    direction: isDesktop ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol Kart - Top 5 Borçlular
                      Expanded(
                        flex: isDesktop ? 1 : 0,
                        child: Container(
                          height: 400,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mükellef Bazlı Risk Dağılımı (Top 5)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'En çok borcu olan mükellefler',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Expanded(
                                child: _topDebtors.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Harika! Bekleyen borç yok.',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: _topDebtors.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                              color: Colors.white12,
                                              height: 24,
                                            ),
                                        itemBuilder: (context, index) {
                                          final entry = _topDebtors[index];
                                          final percentage = (_totalAlacak > 0)
                                              ? (entry.value / _totalAlacak) *
                                                    100
                                              : 0;
                                          return Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: Colors
                                                    .redAccent
                                                    .withValues(alpha: 0.1),
                                                radius: 16,
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      entry.key,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    LinearProgressIndicator(
                                                      value: percentage / 100,
                                                      backgroundColor:
                                                          Colors.white12,
                                                      color: Colors.redAccent,
                                                      minHeight: 4,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            2,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Text(
                                                currencyFormatter.format(
                                                  entry.value,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (isDesktop) const SizedBox(width: 24),
                      if (!isDesktop) const SizedBox(height: 24),

                      // Sağ Kart - Pasta Grafik
                      Expanded(
                        flex: isDesktop ? 1 : 0,
                        child: Container(
                          height: 400,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Genel Tahsilat Durumu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Toplam Kasa vs Toplam Alacak',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 24),

                              Expanded(
                                child: isDataEmpty
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.pie_chart_outline,
                                              color: Colors.white24,
                                              size: 64,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'Grafik oluşturulacak veri bulunamadı.',
                                              style: TextStyle(
                                                color: Colors.white54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          PieChart(
                                            PieChartData(
                                              sectionsSpace: 4,
                                              centerSpaceRadius: 80,
                                              sections: [
                                                PieChartSectionData(
                                                  color: const Color(
                                                    0xFF00ACC1,
                                                  ),
                                                  value: _totalKasa,
                                                  title: '',
                                                  radius: 30,
                                                ),
                                                PieChartSectionData(
                                                  color: Colors.redAccent,
                                                  value: _totalAlacak,
                                                  title: '',
                                                  radius: 30,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Toplam İşlem Hacmi',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                currencyFormatter.format(
                                                  _totalKasa + _totalAlacak,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),

                              // Alt Bilgi Alanı
                              if (!isDataEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 24.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF00ACC1),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Kasa: ${currencyFormatter.format(_totalKasa)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Alacak: ${currencyFormatter.format(_totalAlacak)}',
                                            style: const TextStyle(
                                              color: Colors.white,
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
