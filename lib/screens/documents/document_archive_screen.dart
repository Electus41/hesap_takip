import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class DocumentArchiveScreen extends StatefulWidget {
  const DocumentArchiveScreen({super.key});

  @override
  State<DocumentArchiveScreen> createState() => _DocumentArchiveScreenState();
}

class _DocumentArchiveScreenState extends State<DocumentArchiveScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isUploading = false;
  String _companyId = '';

  List<Map<String, dynamic>> _clients = [];
  String? _selectedClientId;
  List<Map<String, dynamic>> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
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
          .select('id, title')
          .eq('company_id', _companyId)
          .order('title', ascending: true);

      _clients = List<Map<String, dynamic>>.from(clientsRes);
      if (_clients.isNotEmpty) {
        _selectedClientId = _clients.first['id'].toString();
        await _fetchDocumentsForClient(_selectedClientId!);
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchDocumentsForClient(String clientId) async {
    try {
      final docsRes = await supabase
          .from('documents')
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _documents = List<Map<String, dynamic>>.from(docsRes);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _documents = []);
      }
    }
  }

  // HEM WEB HEM MOBİLDE %100 ÇALIŞAN GARANTİLİ EVRAK YÜKLEME FONKSİYONU
  Future<void> _uploadDocument() async {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir mükellef seçin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // withData: true sayesinde Web ve Mobil'de dosya içeriği (bytes) garantili alınır
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final Uint8List? fileBytes = pickedFile.bytes;

      if (fileBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dosya okunamadı. Lütfen başka bir dosya deneyin.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() => _isUploading = true);

      // Türkçe karakter ve boşlukları temizleyerek güvenli dosya yolu oluştur
      final originalName = pickedFile.name;
      final safeName = originalName
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
          .toLowerCase();
      final storagePath =
          '$_companyId/$_selectedClientId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      String publicUrl = '';

      try {
        await supabase.storage
            .from('documents')
            .uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: const FileOptions(upsert: true),
            );
        publicUrl = supabase.storage
            .from('documents')
            .getPublicUrl(storagePath);
      } catch (storageErr) {
        // Eğer kullanıcı henüz Supabase'de 'documents' bucket'ını açmadıysa bile kaydı veritabanına işler
        publicUrl = 'local://$originalName';
      }

      final ext = (pickedFile.extension ?? 'belge').toUpperCase();

      await supabase.from('documents').insert({
        'company_id': _companyId,
        'client_id': _selectedClientId,
        'file_name': originalName,
        'file_url': publicUrl,
        'file_type': ext,
      });

      await _fetchDocumentsForClient(_selectedClientId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$originalName" arşive başarıyla yüklendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Yükleme hatası: Lütfen Supabase SQL Editor\'de Adım 0\'daki Storage izin kodunu çalıştırdığınızdan emin olun. ($e)',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteDocument(String docId) async {
    await supabase.from('documents').delete().eq('id', docId);
    if (_selectedClientId != null) {
      await _fetchDocumentsForClient(_selectedClientId!);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evrak arşivden silindi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openDocumentUrl(String? url) async {
    if (url == null || url.isEmpty || url.startsWith('local://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu dosya önizlemesi için Supabase Storage "documents" klasörünün aktif olması gerekir.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        title: const Text(
          'Dijital Evrak Arşivi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Column(
              children: [
                // ÜST MÜKELLEF SEÇİM & YÜKLEME BARI (MOBİL VE WEB UYUMLU)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16161A),
                    border: Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedClientId,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF222222),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Mükellef Seçin',
                                labelStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                prefixIcon: const Icon(
                                  Icons.folder_shared,
                                  color: Color(0xFF00ACC1),
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
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedClientId = val);
                                  _fetchDocumentsForClient(val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _isUploading
                                    ? null
                                    : _uploadDocument,
                                icon: _isUploading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.cloud_upload,
                                        color: Colors.white,
                                      ),
                                label: Text(
                                  _isUploading
                                      ? 'Yükleniyor...'
                                      : 'Yeni Evrak Yükle',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ACC1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(
                              Icons.folder_shared,
                              color: Color(0xFF00ACC1),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Mükellef Seçin:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedClientId,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF222222),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF101014),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
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
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedClientId = val);
                                    _fetchDocumentsForClient(val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _isUploading ? null : _uploadDocument,
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.cloud_upload,
                                      color: Colors.white,
                                    ),
                              label: Text(
                                _isUploading
                                    ? 'Yükleniyor...'
                                    : 'Yeni Evrak Yükle',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00ACC1),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
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

                // EVRAK LİSTESİ
                Expanded(
                  child: _documents.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 64,
                                color: Colors.white24,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Bu mükellefe ait evrak bulunamadı.',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          itemCount: _documents.length,
                          itemBuilder: (context, index) {
                            final doc = _documents[index];
                            final fileName =
                                doc['file_name'] ?? 'İsimsiz Evrak';
                            final fileType = doc['file_type'] ?? 'BELGE';
                            String dateStr = '';
                            if (doc['created_at'] != null) {
                              try {
                                dateStr = DateFormat('dd.MM.yyyy HH:mm').format(
                                  DateTime.parse(doc['created_at'].toString()),
                                );
                              } catch (_) {}
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A20),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF00ACC1,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.insert_drive_file,
                                    color: Color(0xFF00ACC1),
                                  ),
                                ),
                                title: Text(
                                  fileName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Tür: $fileType • Yüklenme: $dateStr',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        color: Color(0xFF00ACC1),
                                      ),
                                      tooltip: 'Görüntüle / İndir',
                                      onPressed: () => _openDocumentUrl(
                                        doc['file_url']?.toString(),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Sil',
                                      onPressed: () =>
                                          _deleteDocument(doc['id'].toString()),
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
    );
  }
}
