import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
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

  // Pasta grafik için (En çok borcu olan mükellefler)
  List<Map<String, dynamic>> _topDebtors = [];

  // Sütun grafik için (Aylık gelir/gider trendi)
  double _totalIncome = 0;
  double _totalUnpaid = 0;

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

      final txRes = await supabase
          .from('transactions')
          .select('amount, is_paid, created_at, clients(id, title)')
          .eq('company_id', _companyId);

      // --- MÜKELLEF BAZLI BORÇ HESAPLAMA (PASTA GRAFİK İÇİN) ---
      Map<String, Map<String, dynamic>> debtorsMap = {};
      double income = 0;
      double unpaid = 0;

      for (var t in txRes) {
        final amount = double.tryParse(t['amount'].toString()) ?? 0.0;
        final isPaid = t['is_paid'] as bool? ?? false;

        if (isPaid) {
          income += amount;
        } else {
          unpaid += amount;

          final client = t['clients'] as Map<String, dynamic>?;
          if (client != null) {
            final clientId = client['id'].toString();
            if (debtorsMap.containsKey(clientId)) {
              debtorsMap[clientId]!['amount'] += amount;
            } else {
              debtorsMap[clientId] = {
                'title': client['title'],
                'amount': amount,
              };
            }
          }
        }
      }

      // Borçluları büyükten küçüğe sırala ve sadece ilk 5'ini al
      List<Map<String, dynamic>> sortedDebtors = debtorsMap.values.toList();
      sortedDebtors.sort((a, b) => b['amount'].compareTo(a['amount']));

      if (mounted) {
        setState(() {
          _topDebtors = sortedDebtors
              .take(5)
              .toList(); // Sadece en borçlu 5 kişi
          _totalIncome = income;
          _totalUnpaid = unpaid;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Rapor çekme hatası: $e');
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
                  const SizedBox(height: 40),

                  // GRAFİKLERİ YAN YANA (Veya mobilde alt alta) DİZ
                  Wrap(
                    spacing: 32,
                    runSpacing: 32,
                    children: [
                      // 1. GRAFİK: MÜKELLEF BAZLI PASTA GRAFİK
                      Container(
                        width: isDesktop ? 450 : double.infinity,
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'En çok borcu olan mükellefler',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 32),
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
                                  : PieChart(
                                      PieChartData(
                                        sectionsSpace: 4,
                                        centerSpaceRadius: 60,
                                        sections: _buildPieChartSections(),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      // 2. GRAFİK: GENEL TAHSİLAT SÜTUN GRAFİĞİ
                      Container(
                        width: isDesktop ? 450 : double.infinity,
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Toplam Kasa vs Toplam Alacak',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Expanded(
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY:
                                      (_totalIncome > _totalUnpaid
                                          ? _totalIncome
                                          : _totalUnpaid) *
                                      1.2, // Grafiğin tavanını ayarla
                                  barTouchData: BarTouchData(enabled: true),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 16.0,
                                            ),
                                            child: Text(
                                              value.toInt() == 0
                                                  ? 'Kasadaki Para'
                                                  : 'Bekleyen Alacak',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: const FlGridData(show: false),
                                  barGroups: [
                                    BarChartGroupData(
                                      x: 0,
                                      barRods: [
                                        BarChartRodData(
                                          toY: _totalIncome,
                                          color: Colors.greenAccent,
                                          width: 40,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    BarChartGroupData(
                                      x: 1,
                                      barRods: [
                                        BarChartRodData(
                                          toY: _totalUnpaid,
                                          color: Colors.redAccent,
                                          width: 40,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // MÜKELLEF BORÇ LİSTESİ (LEJANT)
                  if (_topDebtors.isNotEmpty) ...[
                    const SizedBox(height: 40),
                    const Text(
                      'Riskli Mükellefler Listesi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: isDesktop ? 932 : double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _topDebtors.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: Colors.white12, height: 1),
                        itemBuilder: (context, index) {
                          final debtor = _topDebtors[index];
                          final colors = [
                            Colors.redAccent,
                            Colors.orangeAccent,
                            Colors.blueAccent,
                            Colors.purpleAccent,
                            Colors.cyanAccent,
                          ];

                          return ListTile(
                            leading: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              debtor['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Text(
                              currencyFormatter.format(debtor['amount']),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // Pasta grafiğin dilimlerini mükelleflere göre oluşturur
  List<PieChartSectionData> _buildPieChartSections() {
    final colors = [
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.cyanAccent,
    ];

    return List.generate(_topDebtors.length, (index) {
      final debtor = _topDebtors[index];
      final amount = debtor['amount'] as double;
      // Yüzde hesaplama
      final percentage = (amount / _totalUnpaid) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amount,
        title:
            '%${percentage.toStringAsFixed(1)}', // Sadece yüzde oranını göster
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }
}
