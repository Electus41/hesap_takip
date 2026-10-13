import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class DocumentArchiveScreen extends StatefulWidget {
  const DocumentArchiveScreen({super.key});

  @override
  State<DocumentArchiveScreen> createState() => _DocumentArchiveScreenState();
}

class _DocumentArchiveScreenState extends State<DocumentArchiveScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _companyId = '';

  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'];

      final clientsRes = await supabase
          .from('clients')
          .select('id, title')
          .eq('company_id', _companyId)
          .eq('is_active', true)
          .order('title', ascending: true);

      final docsRes = await supabase
          .from('documents')
          .select('*, clients(title)')
          .eq('company_id', _companyId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(clientsRes);
          _documents = List<Map<String, dynamic>>.from(docsRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Evrak veri hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showUploadDialog() async {
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce sisteme bir mükellef eklemelisiniz.'),
        ),
      );
      return;
    }

    String? selectedClientId;
    final titleController = TextEditingController();
    bool isUploading = false;
    PlatformFile? selectedFile;

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
                'Yeni Evrak Yükle',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: isUploading
                  ? const SizedBox(
                      height: 150,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF00ACC1)),
                            SizedBox(height: 16),
                            Text(
                              'Dosya buluta yükleniyor, lütfen bekleyin...',
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
                              labelText: 'İlgili Mükellef',
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
                            items: _clients
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c['id'].toString(),
                                    child: Text(c['title'].toString()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => selectedClientId = value),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: titleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Evrak Adı (Örn: 2026 Vergi Levhası)',
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

                          InkWell(
                            onTap: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'pdf',
                                      'jpg',
                                      'jpeg',
                                      'png',
                                    ],
                                    withData: true,
                                  );
                              if (result != null) {
                                setDialogState(
                                  () => selectedFile = result.files.first,
                                );
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: selectedFile != null
                                    ? Colors.greenAccent.withValues(alpha: 0.1)
                                    : const Color(0xFF101014),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedFile != null
                                      ? Colors.greenAccent
                                      : Colors.white12,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    selectedFile != null
                                        ? Icons.check_circle
                                        : Icons.upload_file,
                                    color: selectedFile != null
                                        ? Colors.greenAccent
                                        : const Color(0xFF00ACC1),
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    selectedFile != null
                                        ? selectedFile!.name
                                        : 'PDF veya Resim Seç',
                                    style: TextStyle(
                                      color: selectedFile != null
                                          ? Colors.greenAccent
                                          : Colors.white54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              actions: isUploading
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
                          if (selectedClientId == null ||
                              titleController.text.isEmpty ||
                              selectedFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Lütfen tüm alanları doldurun ve dosya seçin.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isUploading = true);

                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          final navigator = Navigator.of(context);

                          try {
                            final fileBytes = selectedFile!.bytes;
                            if (fileBytes == null)
                              throw Exception(
                                'Dosya okunamadı (Bayt verisi boş).',
                              );

                            final fileExt = selectedFile!.extension ?? 'pdf';
                            final fileName =
                                '${DateTime.now().millisecondsSinceEpoch}_$selectedClientId.$fileExt';

                            await supabase.storage
                                .from('documents')
                                .uploadBinary(fileName, fileBytes);
                            final publicUrl = supabase.storage
                                .from('documents')
                                .getPublicUrl(fileName);

                            await supabase.from('documents').insert({
                              'company_id': _companyId,
                              'client_id': selectedClientId,
                              'title': titleController.text.trim(),
                              'file_url': publicUrl,
                            });

                            if (!mounted) return;
                            navigator.pop();
                            _fetchData();
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Evrak başarıyla arşive eklendi!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() => isUploading = false);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Hata: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ACC1),
                        ),
                        child: const Text(
                          'Yükle ve Kaydet',
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
          'Dijital Evrak Arşivi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mükellef Dosyaları',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vergi levhası, imza sirküleri ve sözleşmeleri bulutta güvenle saklayın.',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _documents.isEmpty
                      ? const Center(
                          child: Text(
                            'Arşivinizde henüz hiç evrak bulunmuyor.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 8,
                          ),
                          itemCount: _documents.length,
                          itemBuilder: (context, index) {
                            final doc = _documents[index];
                            final clientInfo =
                                doc['clients'] as Map<String, dynamic>?;
                            final clientName =
                                clientInfo?['title'] ?? 'Bilinmeyen Mükellef';

                            String dateText = '-';
                            if (doc['created_at'] != null) {
                              try {
                                dateText = DateFormat(
                                  'dd MMM yyyy',
                                  'tr_TR',
                                ).format(DateTime.parse(doc['created_at']));
                              } catch (_) {}
                            }

                            final isPdf = doc['file_url']
                                .toString()
                                .toLowerCase()
                                .contains('.pdf');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isPdf
                                        ? Colors.redAccent.withValues(
                                            alpha: 0.1,
                                          )
                                        : Colors.blueAccent.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isPdf ? Icons.picture_as_pdf : Icons.image,
                                    color: isPdf
                                        ? Colors.redAccent
                                        : Colors.blueAccent,
                                  ),
                                ),
                                title: Text(
                                  doc['title'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '$clientName • Yüklenme: $dateText',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_red_eye,
                                        color: Color(0xFF00ACC1),
                                      ),
                                      tooltip: 'Görüntüle / İndir',
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Dosya linki: (İleride url_launcher ile tarayıcıda açılacak)',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        await supabase
                                            .from('documents')
                                            .delete()
                                            .eq('id', doc['id']);
                                        _fetchData();
                                      },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        backgroundColor: const Color(0xFF00ACC1),
        icon: const Icon(Icons.cloud_upload, color: Colors.white),
        label: const Text(
          'Evrak Yükle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
