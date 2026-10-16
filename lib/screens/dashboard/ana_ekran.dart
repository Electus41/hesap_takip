import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../clients/client_list_screen.dart';
import '../settings/company_settings_screen.dart';
import '../settings/profile_settings_screen.dart';
import '../auth/login_screen.dart';
import '../team/team_management_screen.dart';
import '../finance/cash_transactions_screen.dart';
import '../finance/overdue_payments_screen.dart';
import '../documents/document_archive_screen.dart';
import '../tasks/task_management_screen.dart';
import '../reports/reports_screen.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  int _selectedIndex = 0;
  String _userName = '';
  String _companyName = '';
  String _userRole = '';
  String _companyId = '';
  bool _isLoading = true;

  bool _isLicenseExpired = false;
  int _remainingLicenseDays = 365;
  String _planType = 'Kurumsal Lisans';

  int _aktifMukellefCount = 0;
  double _bekleyenTahsilat = 0.0;
  double _toplamGelir = 0.0;

  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _alerts = [];
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _checkAndGenerateRecurringTransactions(
    List<String> activeClientIds,
    List<Map<String, dynamic>> allTransactions,
  ) async {
    try {
      if (activeClientIds.isEmpty || allTransactions.isEmpty) return;

      final now = DateTime.now();
      final currentMonthKey = DateFormat('yyyy-MM').format(now);
      final currentYearKey = DateFormat('yyyy').format(now);
      final monthName = DateFormat('MMMM yyyy', 'tr_TR').format(now);

      final Map<String, Map<String, dynamic>> recurringTemplates = {};

      for (var t in allTransactions) {
        final freq = t['frequency']?.toString() ?? 'one_time';
        if (freq == 'monthly' || freq == 'yearly') {
          final clientId = t['client_id']?.toString() ?? '';
          if (clientId.isEmpty || !activeClientIds.contains(clientId)) continue;

          final rawDesc = (t['description'] ?? 'Hizmet Bedeli').toString();
          final baseDesc = rawDesc.split(' • ').first.trim();
          final templateKey = '${clientId}_${baseDesc}_$freq';

          if (!recurringTemplates.containsKey(templateKey)) {
            recurringTemplates[templateKey] = {
              'client_id': clientId,
              'base_desc': baseDesc,
              'amount': double.tryParse(t['amount'].toString()) ?? 0.0,
              'payment_type_id': t['payment_type_id'],
              'frequency': freq,
            };
          }
        }
      }

      if (recurringTemplates.isEmpty) return;

      final List<Map<String, dynamic>> newInserts = [];

      for (var entry in recurringTemplates.entries) {
        final tmpl = entry.value;
        final clientId = tmpl['client_id'];
        final baseDesc = tmpl['base_desc'];
        final freq = tmpl['frequency'];
        final targetPeriodKey = freq == 'monthly'
            ? currentMonthKey
            : currentYearKey;

        final alreadyExists = allTransactions.any((t) {
          if (t['client_id']?.toString() != clientId) return false;
          final tDesc = (t['description'] ?? '').toString();
          final tBaseDesc = tDesc.split(' • ').first.trim();
          if (tBaseDesc != baseDesc) return false;

          final pKey = t['period_key']?.toString();
          if (pKey == targetPeriodKey) return true;

          final dateStr = (t['due_date'] ?? t['created_at'] ?? '').toString();
          if (dateStr.startsWith(targetPeriodKey)) return true;

          return false;
        });

        if (!alreadyExists) {
          final periodLabel = freq == 'monthly'
              ? monthName
              : '${now.year} Yılı';
          newInserts.add({
            'company_id': _companyId,
            'client_id': clientId,
            'payment_type_id': tmpl['payment_type_id'],
            'description': '$baseDesc • $periodLabel',
            'amount': tmpl['amount'],
            'is_paid': false,
            'due_date': now.toIso8601String().split('T')[0],
            'frequency': freq,
            'period_key': targetPeriodKey,
          });
        }
      }

      if (newInserts.isNotEmpty) {
        await supabase.from('transactions').insert(newInserts);
      }
    } catch (_) {}
  }

  Future<void> _fetchDashboardData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return;
      }

      final profileData = await supabase
          .from('profiles')
          .select('full_name, role, company_id, companies(*)')
          .eq('id', user.id)
          .single();

      _userName = profileData['full_name'] ?? 'Kullanıcı';
      _userRole = profileData['role'] ?? 'personel';
      _companyId = profileData['company_id'].toString();
      final companyInfo = profileData['companies'] as Map<String, dynamic>?;
      _companyName = companyInfo != null
          ? (companyInfo['name'] ?? 'Mükellef Takip')
          : 'Mükellef Takip';

      bool licenseExpired = false;
      int remainingDays = 365;
      String plan = 'Kurumsal Lisans';

      if (companyInfo != null) {
        final isCompanyActive = companyInfo['is_active'] != false;
        plan = (companyInfo['plan_type'] ?? 'Kurumsal Lisans').toString();

        if (!isCompanyActive) {
          licenseExpired = true;
          remainingDays = 0;
        } else if (companyInfo['license_end_date'] != null) {
          try {
            final endDate = DateTime.parse(
              companyInfo['license_end_date'].toString(),
            );
            final diff = endDate.difference(DateTime.now()).inDays;
            remainingDays = diff;
            if (diff < 0) {
              licenseExpired = true;
            }
          } catch (_) {}
        }
      }

      final clientsRes = await supabase
          .from('clients')
          .select()
          .eq('company_id', _companyId);
      final clientsList = List<Map<String, dynamic>>.from(clientsRes);

      final Map<String, String> clientNames = {};
      final List<String> activeClientIds = [];
      for (var c in clientsList) {
        final cId = c['id'].toString();
        clientNames[cId] = (c['title'] ?? 'Mükellef').toString();
        if (c['is_active'] != false) {
          activeClientIds.add(cId);
        }
      }

      List<Map<String, dynamic>> transactionsData = [];
      try {
        final txByCompany = await supabase
            .from('transactions')
            .select('*, clients(title)')
            .eq('company_id', _companyId)
            .order('created_at', ascending: false);
        transactionsData = List<Map<String, dynamic>>.from(txByCompany);
      } catch (_) {}

      if (clientNames.isNotEmpty) {
        try {
          final txByClients = await supabase
              .from('transactions')
              .select()
              .inFilter('client_id', clientNames.keys.toList())
              .order('created_at', ascending: false);

          final existingIds = transactionsData
              .map((e) => e['id'].toString())
              .toSet();
          for (var tx in txByClients) {
            if (!existingIds.contains(tx['id'].toString())) {
              transactionsData.add(tx);
            }
          }
        } catch (_) {}
      }

      if (activeClientIds.isNotEmpty && transactionsData.isNotEmpty) {
        await _checkAndGenerateRecurringTransactions(
          activeClientIds,
          transactionsData,
        );
      }

      double toplamBorc = 0.0;
      double gelir = 0.0;
      List<Map<String, dynamic>> newAlerts = [];
      final today = DateTime.now();
      final limitDate = today.add(const Duration(days: 3));

      for (var t in transactionsData) {
        final amount = double.tryParse(t['amount'].toString()) ?? 0.0;
        final isPaid = t['is_paid'] == true;

        String cTitle = 'Mükellef';
        if (t['clients'] != null && t['clients'] is Map) {
          cTitle = t['clients']['title']?.toString() ?? 'Mükellef';
        } else if (t['client_id'] != null &&
            clientNames.containsKey(t['client_id'].toString())) {
          cTitle = clientNames[t['client_id'].toString()]!;
        }

        if (isPaid) {
          gelir += amount;
        } else {
          toplamBorc += amount;
          if (t['due_date'] != null) {
            try {
              final dueDate = DateTime.parse(t['due_date'].toString());
              if (dueDate.isBefore(limitDate)) {
                newAlerts.add({
                  'amount': amount,
                  'description': t['description'] ?? 'Belirtilmemiş İşlem',
                  'due_date': dueDate,
                  'client': cTitle,
                  'is_overdue': dueDate.isBefore(
                    DateTime(today.year, today.month, today.day),
                  ),
                });
              }
            } catch (_) {}
          }
        }
      }

      // Net Bekleyen Alacak doğrudan ödenmemiş borçların toplamıdır
      double bekleyen = toplamBorc;

      newAlerts.sort(
        (a, b) =>
            (a['due_date'] as DateTime).compareTo(b['due_date'] as DateTime),
      );

      final recentFive = transactionsData.take(5).map((t) {
        String cTitle = 'Mükellef';
        if (t['clients'] != null && t['clients'] is Map) {
          cTitle = t['clients']['title']?.toString() ?? 'Mükellef';
        } else if (t['client_id'] != null &&
            clientNames.containsKey(t['client_id'].toString())) {
          cTitle = clientNames[t['client_id'].toString()]!;
        }
        return {...t, 'client_title': cTitle};
      }).toList();

      if (mounted) {
        setState(() {
          _isLicenseExpired = licenseExpired;
          _remainingLicenseDays = remainingDays;
          _planType = plan;
          _aktifMukellefCount = clientsList.length;
          _bekleyenTahsilat = bekleyen;
          _toplamGelir = gelir;
          _alerts = newAlerts;
          _recentTransactions = recentFive;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLicenseExpiredScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: Center(
        child: Container(
          width: 460,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock,
                  color: Colors.redAccent,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Lisans Süreniz Sona Ermiştir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '$_companyName ofisine ait Mükellef Takip yazılım lisansınızın kullanım süresi dolmuş veya hesabınız askıya alınmıştır.\n\nVerileriniz bulutta güvenle saklanmaktadır. Hizmete devam etmek için lütfen sistem yöneticinizle iletişime geçerek lisansınızı yenileyin.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Oturumu Kapat',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationPanel() {
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A20),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 40,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'Bildirim Merkezi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: isMobile ? screenWidth : 500,
          height: _alerts.isEmpty ? 100 : 400,
          child: _alerts.isEmpty
              ? const Center(
                  child: Text(
                    'Şu an için yaklaşan veya geciken ödeme yok.\nKasanız güvende! 🎉',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _alerts.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    final isOverdue = alert['is_overdue'] as bool;
                    final dateText = DateFormat(
                      'dd.MM.yyyy',
                    ).format(alert['due_date']);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isOverdue
                            ? Colors.redAccent.withValues(alpha: 0.1)
                            : Colors.orangeAccent.withValues(alpha: 0.1),
                        child: Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.schedule,
                          color: isOverdue
                              ? Colors.redAccent
                              : Colors.orangeAccent,
                        ),
                      ),
                      title: Text(
                        alert['client'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '${alert['description']} • Son Gün: $dateText\n${isOverdue ? '⚠️ Vadesi Geçti' : '⏳ Vadesi Yaklaşıyor'}',
                          style: TextStyle(
                            color: isOverdue
                                ? Colors.redAccent
                                : Colors.orangeAccent,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                      trailing: Text(
                        currencyFormatter.format(alert['amount']),
                        style: TextStyle(
                          color: isOverdue
                              ? Colors.redAccent
                              : Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Future<void> _showTopluTahakkukDialog() async {
    final paymentTypesRes = await supabase
        .from('payment_types')
        .select()
        .eq('company_id', _companyId)
        .order('name', ascending: true);
    final paymentTypes = List<Map<String, dynamic>>.from(paymentTypesRes);

    if (paymentTypes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lütfen önce Şirket Ayarları\'ndan bir ödeme/hizmet kalemi ekleyin.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final amountController = TextEditingController();
    final customNoteController = TextEditingController();
    String? selectedPaymentTypeId = paymentTypes.first['id'].toString();
    String selectedPaymentTypeName = paymentTypes.first['name'].toString();
    String selectedFrequency = 'monthly';
    bool isProcessing = false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
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
              title: const Text(
                'Toplu Tahakkuk / Hizmet Tanımla',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: isProcessing
                  ? const SizedBox(
                      height: 150,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF00ACC1)),
                            SizedBox(height: 16),
                            Text(
                              'Tahakkuk işlemi uygulanıyor...',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: SizedBox(
                        width: isMobile ? screenWidth : 440,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedPaymentTypeId,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF222222),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Hizmet / Ödeme Kalemi Seçin',
                                labelStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF101014),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: paymentTypes
                                  .map(
                                    (pt) => DropdownMenuItem<String>(
                                      value: pt['id'].toString(),
                                      child: Text(pt['name'].toString()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedPaymentTypeId = value;
                                    selectedPaymentTypeName = paymentTypes
                                        .firstWhere(
                                          (pt) => pt['id'].toString() == value,
                                        )['name'];
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: selectedFrequency,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF222222),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Tekrar Sıklığı (Periyot)',
                                labelStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                prefixIcon: const Icon(
                                  Icons.repeat,
                                  color: Color(0xFF00ACC1),
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
                                  value: 'monthly',
                                  child: Text('Aylık (Her Ay Otomatik Yansır)'),
                                ),
                                DropdownMenuItem(
                                  value: 'yearly',
                                  child: Text(
                                    'Yıllık (Her Yıl Otomatik Yansır)',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'one_time',
                                  child: Text('1 Defalık (Tek Seferlik İşlem)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedFrequency = val);
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Tutar (₺) - Örn: 1000',
                                labelStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                prefixIcon: const Icon(
                                  Icons.currency_lira,
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
                              controller: customNoteController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText:
                                    'Ek Not (İsteğe Bağlı - Boş Bırakılabilir)',
                                labelStyle: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
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
                          if (selectedPaymentTypeId == null ||
                              amountController.text.isEmpty) {
                            return;
                          }
                          setDialogState(() => isProcessing = true);
                          try {
                            final clientsRes = await supabase
                                .from('clients')
                                .select('id')
                                .eq('company_id', _companyId);

                            final amount =
                                double.tryParse(
                                  amountController.text.replaceAll(',', '.'),
                                ) ??
                                0.0;

                            final now = DateTime.now();
                            final periodLabel = selectedFrequency == 'monthly'
                                ? DateFormat('MMMM yyyy', 'tr_TR').format(now)
                                : selectedFrequency == 'yearly'
                                ? '${now.year} Yılı'
                                : DateFormat('dd.MM.yyyy').format(now);

                            final periodKey = selectedFrequency == 'monthly'
                                ? DateFormat('yyyy-MM').format(now)
                                : selectedFrequency == 'yearly'
                                ? DateFormat('yyyy').format(now)
                                : 'ONCE_${now.millisecondsSinceEpoch}';

                            final baseTitle =
                                customNoteController.text.trim().isEmpty
                                ? selectedPaymentTypeName
                                : '$selectedPaymentTypeName (${customNoteController.text.trim()})';

                            final finalDesc = selectedFrequency == 'one_time'
                                ? baseTitle
                                : '$baseTitle • $periodLabel';

                            final todayStr = now.toIso8601String().split(
                              'T',
                            )[0];

                            final List<Map<String, dynamic>> batchInserts =
                                List<Map<String, dynamic>>.from(clientsRes)
                                    .map(
                                      (c) => {
                                        'company_id': _companyId,
                                        'client_id': c['id'],
                                        'payment_type_id':
                                            selectedPaymentTypeId,
                                        'description': finalDesc,
                                        'amount': amount,
                                        'is_paid': false,
                                        'due_date': todayStr,
                                        'frequency': selectedFrequency,
                                        'period_key': periodKey,
                                      },
                                    )
                                    .toList();

                            if (batchInserts.isNotEmpty) {
                              await supabase
                                  .from('transactions')
                                  .insert(batchInserts);
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              _fetchDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${clientsRes.length} mükellefe tahakkuk başarıyla tanımlandı!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ACC1),
                        ),
                        child: const Text(
                          'Tahakkuk Tanımla',
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

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Widget _buildNotificationBell() {
    return IconButton(
      icon: Badge(
        isLabelVisible: _alerts.isNotEmpty,
        label: Text(
          _alerts.length.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
        child: const Icon(
          Icons.notifications_active,
          color: Colors.white,
          size: 26,
        ),
      ),
      onPressed: _showNotificationPanel,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _isLicenseExpired) {
      return _buildLicenseExpiredScreen();
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      drawer: !isDesktop
          ? Drawer(
              backgroundColor: const Color(0xFF16161A),
              child: _buildSidebar(),
            )
          : null,
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: const Color(0xFF16161A),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 30,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.layers_rounded,
                      color: Color(0xFF00ACC1),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _companyName.isNotEmpty ? _companyName : 'Mükellef Takip',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                _buildNotificationBell(),
                IconButton(
                  icon: CircleAvatar(
                    radius: 15,
                    backgroundColor: const Color(0xFF00ACC1),
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'M',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileSettingsScreen(),
                    ),
                  ).then((_) => _fetchDashboardData()),
                ),
                const SizedBox(width: 6),
              ],
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
                  )
                : isDesktop
                ? _buildDesktopDashboard(currencyFormatter)
                : _buildMobileStockStyleDashboard(currencyFormatter),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStockStyleDashboard(NumberFormat currencyFormatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E3C72),
                  Color(0xFF2A5298),
                  Color(0xFF00ACC1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00ACC1).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'CANLI OFİS & FİNANS ÖZETİ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _aktifMukellefCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Aktif Mükellef',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, color: Colors.white24),
                    Expanded(
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currencyFormatter.format(_bekleyenTahsilat),
                              style: const TextStyle(
                                color: Color(0xFFFF8A80),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Bekleyen Alacak',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, color: Colors.white24),
                    Expanded(
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currencyFormatter.format(_toplamGelir),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Net Tahsilat',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildCompactMenuRow(
            title: 'Mükellef Yönetimi',
            icon: Icons.group_add,
            iconColor: Colors.greenAccent,
            onTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClientListScreen(),
                  ),
                ).then((_) {
                  if (mounted) setState(() => _selectedIndex = 0);
                  _fetchDashboardData();
                }),
          ),
          _buildCompactMenuRow(
            title: 'Görev & İş Takibi',
            icon: Icons.assignment_turned_in,
            iconColor: Colors.blueAccent,
            onTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TaskManagementScreen(),
                  ),
                ).then((_) {
                  if (mounted) setState(() => _selectedIndex = 0);
                  _fetchDashboardData();
                }),
          ),
          _buildCompactMenuRow(
            title: 'Toplu Tahakkuk (Borç Yansıt)',
            icon: Icons.receipt_long,
            iconColor: Colors.purpleAccent,
            onTap: _showTopluTahakkukDialog,
          ),
          _buildCompactMenuRow(
            title: 'Kasa & Gün Sonu Hareketleri',
            icon: Icons.point_of_sale,
            iconColor: Colors.amberAccent,
            onTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CashTransactionsScreen(),
                  ),
                ).then((_) {
                  if (mounted) setState(() => _selectedIndex = 0);
                  _fetchDashboardData();
                }),
          ),
          _buildCompactMenuRow(
            title: 'Geciken Ödemeler & Ekstre',
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.redAccent,
            onTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OverduePaymentsScreen(),
                  ),
                ).then((_) {
                  if (mounted) setState(() => _selectedIndex = 0);
                  _fetchDashboardData();
                }),
          ),
          _buildCompactMenuRow(
            title: 'Dijital Evrak Arşivi',
            icon: Icons.folder_shared,
            iconColor: const Color(0xFF00ACC1),
            onTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DocumentArchiveScreen(),
                  ),
                ).then((_) {
                  if (mounted) setState(() => _selectedIndex = 0);
                  _fetchDashboardData();
                }),
          ),
          _buildCompactMenuRow(
            title: 'Mükellef Cari Ekstre & Raporlar',
            icon: Icons.picture_as_pdf,
            iconColor: Colors.deepOrangeAccent,
            onTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportsScreen(),
                  ),
                ).then((_) {
                  if (mounted) setState(() => _selectedIndex = 0);
                  _fetchDashboardData();
                }),
          ),
          if (_userRole == 'admin')
            _buildCompactMenuRow(
              title: 'Ekip Yönetimi (Personeller)',
              icon: Icons.admin_panel_settings,
              iconColor: Colors.indigoAccent,
              onTap: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeamManagementScreen(),
                    ),
                  ).then((_) {
                    if (mounted) setState(() => _selectedIndex = 0);
                    _fetchDashboardData();
                  }),
            ),
          const SizedBox(height: 24),
          const Text(
            'Son Finansal Hareketler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentTransactionsTable(false),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCompactMenuRow({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white54,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildDesktopDashboard(NumberFormat currencyFormatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Hoş Geldin, $_userName',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _userRole == 'admin'
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _userRole == 'admin'
                                ? Colors.redAccent
                                : Colors.blueAccent,
                          ),
                        ),
                        child: Text(
                          _userRole == 'admin' ? 'Yönetici' : 'Personel',
                          style: TextStyle(
                            color: _userRole == 'admin'
                                ? Colors.redAccent
                                : Colors.blueAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_companyName ofisinin bugünkü genel durumu.',
                    style: const TextStyle(fontSize: 16, color: Colors.white54),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildNotificationBell(),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileSettingsScreen(),
                          ),
                        ).then((_) {
                          if (mounted) setState(() => _selectedIndex = 0);
                          _fetchDashboardData();
                        }),
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF00ACC1),
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'M',
                        style: const TextStyle(
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
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              double statCardWidth = (constraints.maxWidth - 48) / 3;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _buildModernStatCard(
                    title: 'Aktif Mükellef',
                    value: _aktifMukellefCount.toString(),
                    trend: 'Sistemdeki toplam kayıt',
                    icon: Icons.business_center,
                    color: const Color(0xFF00ACC1),
                    width: statCardWidth,
                  ),
                  _buildModernStatCard(
                    title: 'Bekleyen Tahsilat',
                    value: currencyFormatter.format(_bekleyenTahsilat),
                    trend: 'Tahsil edilmeyi bekliyor',
                    icon: Icons.account_balance_wallet,
                    color: Colors.redAccent,
                    width: statCardWidth,
                    trendColor: Colors.redAccent,
                  ),
                  _buildModernStatCard(
                    title: 'Toplam Kasa / Gelir',
                    value: currencyFormatter.format(_toplamGelir),
                    trend: 'Tamamlanan tahsilatlar',
                    icon: Icons.trending_up,
                    color: Colors.greenAccent,
                    width: statCardWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          const Text(
            'Hızlı İşlemler & Modüller',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              double cardWidth = constraints.maxWidth > 1200
                  ? (constraints.maxWidth - 48) / 3
                  : (constraints.maxWidth - 24) / 2;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _buildActionCard(
                    title: 'Mükellef Yönetimi',
                    description:
                        'Yeni mükellef ekle veya mevcut profilleri düzenle.',
                    icon: Icons.group_add,
                    width: cardWidth,
                    onTap: () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ClientListScreen(),
                          ),
                        ).then((_) {
                          if (mounted) setState(() => _selectedIndex = 0);
                          _fetchDashboardData();
                        }),
                  ),
                  if (_userRole == 'admin')
                    _buildActionCard(
                      title: 'Ekip Yönetimi (Personeller)',
                      description: 'Ofisinize yeni personel ekleyin.',
                      icon: Icons.admin_panel_settings,
                      width: cardWidth,
                      onTap: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TeamManagementScreen(),
                            ),
                          ).then((_) {
                            if (mounted) setState(() => _selectedIndex = 0);
                            _fetchDashboardData();
                          }),
                    ),
                  _buildActionCard(
                    title: 'Toplu Tahakkuk',
                    description:
                        'Tüm mükelleflere periyodik veya tek seferlik borç yansıt.',
                    icon: Icons.receipt_long,
                    width: cardWidth,
                    onTap: _showTopluTahakkukDialog,
                  ),
                  _buildActionCard(
                    title: 'Geciken Ödemeler',
                    description:
                        'Vadesi geçmiş alacakları görüntüle ve ekstre al.',
                    icon: Icons.warning_amber_rounded,
                    width: cardWidth,
                    onTap: () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OverduePaymentsScreen(),
                          ),
                        ).then((_) {
                          if (mounted) setState(() => _selectedIndex = 0);
                          _fetchDashboardData();
                        }),
                  ),
                  _buildActionCard(
                    title: 'Kasa & Hareketler',
                    description: 'Tüm nakit ve banka tahsilatlarını listele.',
                    icon: Icons.point_of_sale,
                    width: cardWidth,
                    onTap: () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CashTransactionsScreen(),
                          ),
                        ).then((_) {
                          if (mounted) setState(() => _selectedIndex = 0);
                          _fetchDashboardData();
                        }),
                  ),
                  _buildActionCard(
                    title: 'Dijital Evrak Arşivi',
                    description:
                        'Mükellef evraklarını (Vergi Levhası vb.) bulutta sakla.',
                    icon: Icons.folder_shared,
                    width: cardWidth,
                    onTap: () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DocumentArchiveScreen(),
                          ),
                        ).then((_) {
                          if (mounted) setState(() => _selectedIndex = 0);
                          _fetchDashboardData();
                        }),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          const Text(
            'Son Finansal Hareketler',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          _buildRecentTransactionsTable(true),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsTable(bool isDesktop) {
    if (_recentTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isDesktop ? 32 : 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Text(
          'Ofisinizde henüz hiçbir finansal hareket kaydedilmemiş.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentTransactions.length,
        separatorBuilder: (context, index) =>
            const Divider(color: Colors.white12, height: 1),
        itemBuilder: (context, index) {
          final t = _recentTransactions[index];
          final isPaid = t['is_paid'] == true;
          final amount = double.tryParse(t['amount'].toString()) ?? 0.0;
          final clientTitle = t['client_title'] ?? 'Bilinmeyen Mükellef';
          String dateText = '-';
          if (t['created_at'] != null) {
            try {
              dateText = DateFormat(
                'dd MMM yyyy HH:mm',
                'tr_TR',
              ).format(DateTime.parse(t['created_at'].toString()));
            } catch (_) {}
          }
          return ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: isPaid
                  ? Colors.greenAccent.withValues(alpha: 0.1)
                  : Colors.orangeAccent.withValues(alpha: 0.1),
              child: Icon(
                isPaid ? Icons.arrow_downward : Icons.arrow_upward,
                color: isPaid ? Colors.greenAccent : Colors.orangeAccent,
                size: 20,
              ),
            ),
            title: Text(
              clientTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${t['description'] ?? ''}\n$dateText',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
            trailing: Text(
              '${isPaid ? '+' : '-'}₺${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isPaid ? Colors.greenAccent : Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF16161A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.layers_rounded,
                      color: Color(0xFF00ACC1),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _companyName.isNotEmpty ? _companyName : 'Mükellef Takip',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            _buildSidebarItem(
              icon: Icons.home_rounded,
              title: 'Ana Sayfa',
              index: 0,
            ),
            _buildSidebarItem(
              icon: Icons.people,
              title: 'Mükellefler',
              index: 1,
            ),
            _buildSidebarItem(
              icon: Icons.account_balance_wallet,
              title: 'Kasa & Tahsilat',
              index: 2,
            ),
            _buildSidebarItem(
              icon: Icons.assignment_turned_in,
              title: 'Görev & İş Takibi',
              index: 3,
            ),
            _buildSidebarItem(
              icon: Icons.picture_as_pdf,
              title: 'Cari Ekstre & Rapor',
              index: 4,
            ),
            const Spacer(),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00ACC1).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        color: Color(0xFF00ACC1),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _planType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kalan Süre: $_remainingLicenseDays Gün',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 12),
                  const Text(
                    '© 2026 Mükellef Takip • Tüm hakları saklıdır.MHK Yazılım Çözümleri',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),
            if (_userRole == 'admin')
              _buildSidebarItem(
                icon: Icons.settings,
                title: 'Şirket Ayarları',
                index: 5,
              ),
            InkWell(
              onTap: _signOut,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 22),
                    SizedBox(width: 16),
                    Text(
                      'Çıkış Yap',
                      style: TextStyle(color: Colors.redAccent, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        if (index == 0) {
          setState(() => _selectedIndex = 0);
          if (MediaQuery.of(context).size.width <= 800) {
            Navigator.pop(context);
          }
          return;
        }

        setState(() => _selectedIndex = index);
        if (MediaQuery.of(context).size.width <= 800) {
          Navigator.pop(context);
        }

        Widget? targetScreen;
        if (index == 1) {
          targetScreen = const ClientListScreen();
        } else if (index == 2) {
          targetScreen = const CashTransactionsScreen();
        } else if (index == 3) {
          targetScreen = const TaskManagementScreen();
        } else if (index == 4) {
          targetScreen = const ReportsScreen();
        } else if (index == 5) {
          targetScreen = const CompanySettingsScreen();
        }

        if (targetScreen != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen!),
          ).then((_) {
            if (mounted) {
              setState(() => _selectedIndex = 0);
              _fetchDashboardData();
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: isSelected ? const Color(0xFF00ACC1) : Colors.transparent,
              width: 4,
            ),
          ),
          color: isSelected
              ? const Color(0xFF00ACC1).withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00ACC1) : Colors.white54,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Color color,
    required double width,
    Color trendColor = Colors.greenAccent,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(trend, style: TextStyle(color: trendColor, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required double width,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF00ACC1), size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}
