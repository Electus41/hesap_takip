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

  Future<void> _fetchDashboardData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        return;
      }

      final profileData = await supabase
          .from('profiles')
          .select('full_name, role, company_id, companies(name)')
          .eq('id', user.id)
          .single();
      _userName = profileData['full_name'] ?? 'Kullanıcı';
      _userRole = profileData['role'] ?? 'personel';
      _companyId = profileData['company_id'];
      final companyInfo = profileData['companies'] as Map<String, dynamic>?;
      _companyName = companyInfo != null
          ? companyInfo['name']
          : 'Bilinmeyen Şirket';

      final clientsData = await supabase
          .from('clients')
          .select('id')
          .eq('company_id', _companyId);
      final transactionsData = await supabase
          .from('transactions')
          .select('amount, is_paid, due_date, description, clients(title)')
          .eq('company_id', _companyId);

      double bekleyen = 0.0;
      double gelir = 0.0;
      List<Map<String, dynamic>> newAlerts = [];
      final today = DateTime.now();
      final limitDate = today.add(const Duration(days: 3));

      for (var t in transactionsData) {
        final amount = double.tryParse(t['amount'].toString()) ?? 0.0;
        final isPaid = t['is_paid'] as bool? ?? false;
        if (isPaid) {
          gelir += amount;
        } else {
          bekleyen += amount;
          if (t['due_date'] != null) {
            final dueDate = DateTime.parse(t['due_date'].toString());
            if (dueDate.isBefore(limitDate)) {
              newAlerts.add({
                'amount': amount,
                'description': t['description'] ?? 'Belirtilmemiş İşlem',
                'due_date': dueDate,
                'client': t['clients'] != null
                    ? t['clients']['title']
                    : 'Bilinmeyen Mükellef',
                'is_overdue': dueDate.isBefore(
                  DateTime(today.year, today.month, today.day),
                ),
              });
            }
          }
        }
      }
      newAlerts.sort(
        (a, b) =>
            (a['due_date'] as DateTime).compareTo(b['due_date'] as DateTime),
      );

      final recentTxData = await supabase
          .from('transactions')
          .select('amount, is_paid, description, created_at, clients(title)')
          .eq('company_id', _companyId)
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _aktifMukellefCount = clientsData.length;
          _bekleyenTahsilat = bekleyen;
          _toplamGelir = gelir;
          _alerts = newAlerts;
          _recentTransactions = List<Map<String, dynamic>>.from(recentTxData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNotificationPanel() {
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A20),
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
          width: 500,
          height: _alerts.isEmpty ? 100 : 400,
          child: _alerts.isEmpty
              ? const Center(
                  child: Text(
                    'Şu an için yaklaşan veya geciken ödeme yok.\nKasanız güvende! 🎉',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lütfen önce Şirket Ayarları\'ndan bir ödeme kalemi ekleyin.',
            ),
          ),
        );
      return;
    }
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String? selectedPaymentTypeId;
    String? selectedPaymentTypeName;
    bool isProcessing = false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Toplu Tahakkuk İşlemi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                              'Borç yansıtılıyor...',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF222222),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Ödeme Kalemi',
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
                            onChanged: (value) => setDialogState(() {
                              selectedPaymentTypeId = value;
                              selectedPaymentTypeName = paymentTypes.firstWhere(
                                (pt) => pt['id'].toString() == value,
                              )['name'];
                            }),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: descController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Dönem / Açıklama (Örn: Ekim Ayı)',
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
                          ),
                        ],
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
                              amountController.text.isEmpty)
                            return;
                          setDialogState(() => isProcessing = true);
                          try {
                            final clientsRes = await supabase
                                .from('clients')
                                .select('id')
                                .eq('company_id', _companyId)
                                .eq('is_active', true);
                            final amount =
                                double.tryParse(
                                  amountController.text.replaceAll(',', '.'),
                                ) ??
                                0.0;
                            final finalDesc = descController.text.trim().isEmpty
                                ? selectedPaymentTypeName!
                                : '$selectedPaymentTypeName - ${descController.text.trim()}';
                            final today = DateTime.now()
                                .toIso8601String()
                                .split('T')[0];
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
                                        'due_date': today,
                                      },
                                    )
                                    .toList();
                            if (batchInserts.isNotEmpty)
                              await supabase
                                  .from('transactions')
                                  .insert(batchInserts);

                            if (mounted) {
                              Navigator.pop(context);
                              _fetchDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${clientsRes.length} mükellefe başarıyla borç yansıtıldı!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sistemsel hata, lütfen tekrar deneyin.',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ACC1),
                        ),
                        child: const Text(
                          'Tahakkuk Et',
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
    if (mounted)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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
          size: 28,
        ),
      ),
      onPressed: _showNotificationPanel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      drawer: !isDesktop ? _buildSidebar() : null,
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: const Color(0xFF16161A),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                _companyName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [_buildNotificationBell(), const SizedBox(width: 8)],
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
                : SingleChildScrollView(
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
                                            ? Colors.redAccent.withValues(
                                                alpha: 0.2,
                                              )
                                            : Colors.blueAccent.withValues(
                                                alpha: 0.2,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _userRole == 'admin'
                                              ? Colors.redAccent
                                              : Colors.blueAccent,
                                        ),
                                      ),
                                      child: Text(
                                        _userRole == 'admin'
                                            ? 'Yönetici'
                                            : 'Personel',
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
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                            if (isDesktop)
                              Row(
                                children: [
                                  _buildNotificationBell(),
                                  const SizedBox(width: 16),
                                  InkWell(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ProfileSettingsScreen(),
                                      ),
                                    ).then((_) => _fetchDashboardData()),
                                    borderRadius: BorderRadius.circular(20),
                                    child: CircleAvatar(
                                      backgroundColor: const Color(0xFF00ACC1),
                                      child: Text(
                                        _userName.isNotEmpty
                                            ? _userName[0].toUpperCase()
                                            : 'M',
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
                            double statCardWidth = isDesktop
                                ? (constraints.maxWidth - 48) / 3
                                : double.infinity;
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
                                  value: currencyFormatter.format(
                                    _bekleyenTahsilat,
                                  ),
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
                            double cardWidth;
                            if (constraints.maxWidth > 1200)
                              cardWidth = (constraints.maxWidth - 48) / 3;
                            else if (constraints.maxWidth > 800)
                              cardWidth = (constraints.maxWidth - 24) / 2;
                            else
                              cardWidth = double.infinity;
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
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ClientListScreen(),
                                    ),
                                  ).then((_) => _fetchDashboardData()),
                                ),
                                if (_userRole == 'admin')
                                  _buildActionCard(
                                    title: 'Ekip Yönetimi (Personeller)',
                                    description:
                                        'Ofisinize yeni personel ekleyin.',
                                    icon: Icons.admin_panel_settings,
                                    width: cardWidth,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const TeamManagementScreen(),
                                      ),
                                    ).then((_) => _fetchDashboardData()),
                                  ),
                                _buildActionCard(
                                  title: 'Toplu Tahakkuk',
                                  description:
                                      'Tüm mükelleflere tek tuşla borç yansıt.',
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
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const OverduePaymentsScreen(),
                                    ),
                                  ).then((_) => _fetchDashboardData()),
                                ),
                                _buildActionCard(
                                  title: 'Kasa & Hareketler',
                                  description:
                                      'Tüm nakit ve banka tahsilatlarını listele.',
                                  icon: Icons.point_of_sale,
                                  width: cardWidth,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CashTransactionsScreen(),
                                    ),
                                  ).then((_) => _fetchDashboardData()),
                                ),
                                _buildActionCard(
                                  title: 'Dijital Evrak Arşivi',
                                  description:
                                      'Mükellef evraklarını (Vergi Levhası vb.) bulutta sakla.',
                                  icon: Icons.folder_shared,
                                  width: cardWidth,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DocumentArchiveScreen(),
                                    ),
                                  ).then((_) => _fetchDashboardData()),
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
                        _buildRecentTransactionsTable(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsTable() {
    if (_recentTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Text(
          'Ofisinizde henüz hiçbir finansal hareket kaydedilmemiş.',
          style: TextStyle(color: Colors.white54, fontSize: 15),
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
          final isPaid = t['is_paid'] as bool? ?? false;
          final amount = double.tryParse(t['amount'].toString()) ?? 0.0;
          final clientTitle =
              (t['clients'] as Map<String, dynamic>?)?['title'] ??
              'Bilinmeyen Mükellef';
          String dateText = '-';
          if (t['created_at'] != null) {
            try {
              dateText = DateFormat(
                'dd MMM yyyy HH:mm',
                'tr_TR',
              ).format(DateTime.parse(t['created_at']));
            } catch (_) {}
          }
          return ListTile(
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
                color: isPaid ? Colors.greenAccent : Colors.orangeAccent,
                size: 20,
              ),
            ),
            title: Text(
              clientTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${t['description'] ?? ''} • $dateText',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            trailing: Text(
              '${isPaid ? '+' : '-'}₺${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isPaid ? Colors.greenAccent : Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              children: [
                const Icon(
                  Icons.layers_rounded,
                  color: Color(0xFF00ACC1),
                  size: 32,
                ), // YENİ LOGO
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
                ), // YENİ İSİM
              ],
            ),
          ),
          _buildSidebarItem(
            icon: Icons.dashboard,
            title: 'Gösterge Paneli',
            index: 0,
          ),
          _buildSidebarItem(icon: Icons.people, title: 'Mükellefler', index: 1),
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
            title: 'Raporlar',
            index: 4,
          ),
          const Spacer(),
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
          const SizedBox(height: 24),
        ],
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
        setState(() => _selectedIndex = index);
        if (MediaQuery.of(context).size.width <= 800) Navigator.pop(context);
        if (index == 1)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ClientListScreen()),
          ).then((_) => _fetchDashboardData());
        else if (index == 2)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CashTransactionsScreen(),
            ),
          ).then((_) => _fetchDashboardData());
        else if (index == 3)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TaskManagementScreen(),
            ),
          ).then((_) => _fetchDashboardData());
        else if (index == 4)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportsScreen()),
          ).then((_) => _fetchDashboardData());
        else if (index == 5)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CompanySettingsScreen(),
            ),
          ).then((_) => _fetchDashboardData());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
