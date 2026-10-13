import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _companyId = '';
  Stream<List<Map<String, dynamic>>>? _paymentTypesStream;

  @override
  void initState() {
    super.initState();
    _initializeIsolation();
  }

  // GİRİŞ YAPAN KİŞİNİN ŞİRKETİNİ BUL VE AKIŞI BAŞLAT
  Future<void> _initializeIsolation() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'];

      setState(() {
        // SADECE BU ŞİRKETE AİT KALEMLERİ ÇEK
        _paymentTypesStream = supabase
            .from('payment_types')
            .stream(primaryKey: ['id'])
            .eq('company_id', _companyId)
            .order('name', ascending: true);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ayar İzolasyon hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // YENİ ÖDEME KALEMİ EKLEME DİALOGU
  void _showAddPaymentTypeDialog() {
    final nameController = TextEditingController();
    bool isProcessing = false;

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
                'Yeni Ödeme Kalemi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: isProcessing
                  ? const SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00ACC1),
                        ),
                      ),
                    )
                  : TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Kalem Adı (Örn: Muhasebe Ücreti)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF101014),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
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
                          if (nameController.text.trim().isEmpty) return;
                          setDialogState(() => isProcessing = true);

                          try {
                            // YENİ KALEM EKLERKEN ŞİRKET MÜHRÜNÜ (company_id) BASIYORUZ!
                            await supabase.from('payment_types').insert({
                              'company_id': _companyId,
                              'name': nameController.text.trim(),
                            });
                            if (mounted) Navigator.pop(context);
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hata: $e')),
                              );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ACC1),
                        ),
                        child: const Text(
                          'Kaydet',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Şirket Ayarları',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ödeme ve Tahakkuk Kalemleri',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ofisinize özel borçlandırma seçeneklerini buradan yönetebilirsiniz.',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _paymentTypesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00ACC1),
                            ),
                          );
                        }
                        final items = snapshot.data ?? [];

                        if (items.isEmpty) {
                          return const Center(
                            child: Text(
                              'Henüz bir ödeme kalemi eklenmemiş.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.category,
                                  color: Color(0xFF00ACC1),
                                ),
                                title: Text(
                                  item['name'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    // SİLERKEN DE GÜVENLİK: Sadece bu şirkete aitse silebilir
                                    await supabase
                                        .from('payment_types')
                                        .delete()
                                        .eq('id', item['id'])
                                        .eq('company_id', _companyId);
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentTypeDialog,
        backgroundColor: const Color(0xFF00ACC1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Yeni Kalem Ekle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
