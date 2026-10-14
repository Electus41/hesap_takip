import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentArchiveScreen extends StatefulWidget {
  const DocumentArchiveScreen({super.key});

  @override
  State<DocumentArchiveScreen> createState() => _DocumentArchiveScreenState();
}

class _DocumentArchiveScreenState extends State<DocumentArchiveScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _companyId = '';

  List<Map<String, dynamic>> _clients = [];
  String? _selectedClientId;
  List<FileObject> _documents = [];

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id'];

      final res = await supabase
          .from('clients')
          .select('id, title')
          .eq('company_id', _companyId)
          .order('title', ascending: true);

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(res);
          if (_clients.isNotEmpty) {
            _selectedClientId = _clients.first['id'];
            _fetchDocuments(_selectedClientId!);
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDocuments(String clientId) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final String path = '$_companyId/$clientId';
      final List<FileObject> res = await supabase.storage
          .from('documents')
          .list(path: path);

      final filteredDocs = res
          .where((doc) => doc.name != '.emptyFolderPlaceholder')
          .toList();

      if (mounted) {
        setState(() {
          _documents = filteredDocs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _documents = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedClientId == null) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final file = result.files.single;
        final fileBytes = file.bytes!;

        final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
        final String path = '$_companyId/$_selectedClientId/$safeName';

        await supabase.storage
            .from('documents')
            .uploadBinary(
              path,
              fileBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Evrak başarıyla arşive eklendi!'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchDocuments(_selectedClientId!);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yükleme başarısız oldu. Lütfen tekrar deneyin.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _downloadDocument(String fileName) async {
    try {
      final String path = '$_companyId/$_selectedClientId/$fileName';
      final String publicUrl = supabase.storage
          .from('documents')
          .getPublicUrl(path);

      final url = Uri.parse(publicUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dosya açılamadı.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(String fileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Evrak Silme Onayı',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '$fileName adlı evrak kalıcı olarak silinecek. Onaylıyor musunuz?',
          style: const TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Evet, Sil',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        final String path = '$_companyId/$_selectedClientId/$fileName';
        await supabase.storage.from('documents').remove([path]);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Evrak arşivlendi.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchDocuments(_selectedClientId!);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silme işlemi başarısız.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        title: const Text(
          'Dijital Evrak Arşivi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Color(0xFF16161A),
              border: Border(
                bottom: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_shared,
                  color: Color(0xFF00ACC1),
                  size: 32,
                ),
                const SizedBox(width: 16),
                const Text(
                  'Mükellef Seçin:',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF222222),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF00ACC1),
                        ),
                        value: _selectedClientId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _clients
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['id'],
                                child: Text(c['title']),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null && value != _selectedClientId) {
                            setState(() {
                              _selectedClientId = value;
                            });
                            _fetchDocuments(value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: _selectedClientId == null ? null : _uploadDocument,
                  icon: const Icon(Icons.cloud_upload, color: Colors.white),
                  label: const Text(
                    'Yeni Evrak Yükle',
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
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
                  )
                : _documents.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 80,
                          color: Colors.white24,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Bu mükellefe ait evrak bulunamadı.',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(32),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      final ext = doc.name.split('.').last.toLowerCase();
                      IconData docIcon = Icons.insert_drive_file;
                      Color iconColor = Colors.blueAccent;

                      if (ext == 'pdf') {
                        docIcon = Icons.picture_as_pdf;
                        iconColor = Colors.redAccent;
                      } else if (ext == 'jpg' ||
                          ext == 'jpeg' ||
                          ext == 'png') {
                        docIcon = Icons.image;
                        iconColor = Colors.greenAccent;
                      } else if (ext == 'doc' || ext == 'docx') {
                        docIcon = Icons.description;
                        iconColor = Colors.blueAccent;
                      }

                      final sizeInKb = doc.metadata?['size'] != null
                          ? (doc.metadata!['size'] / 1024).round()
                          : 0;
                      final sizeText = sizeInKb > 1024
                          ? '${(sizeInKb / 1024).toStringAsFixed(1)} MB'
                          : '$sizeInKb KB';

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            Icon(docIcon, size: 64, color: iconColor),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                doc.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              sizeText,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.white12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_red_eye,
                                      color: Color(0xFF00ACC1),
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _downloadDocument(doc.name),
                                    tooltip: 'Görüntüle / İndir',
                                  ),
                                  Container(
                                    width: 1,
                                    height: 24,
                                    color: Colors.white12,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () => _deleteDocument(doc.name),
                                    tooltip: 'Evrak Sil',
                                  ),
                                ],
                              ),
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
