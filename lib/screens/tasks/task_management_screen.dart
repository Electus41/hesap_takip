import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _companyId = '';

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _personnel = [];

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

      final tasksRes = await supabase
          .from('tasks')
          .select()
          .eq('company_id', _companyId)
          .order('created_at', ascending: false);
      final clientsRes = await supabase
          .from('clients')
          .select('id, title')
          .eq('company_id', _companyId)
          .order('title', ascending: true);
      final personnelRes = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('company_id', _companyId)
          .order('full_name', ascending: true);

      if (mounted) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(tasksRes);
          _clients = List<Map<String, dynamic>>.from(clientsRes);
          _personnel = List<Map<String, dynamic>>.from(personnelRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUserFriendlyError(dynamic error) {
    if (!mounted) return;
    String errorMessage =
        'İşleminiz şu anda gerçekleştirilemiyor. Lütfen internet bağlantınızı kontrol edin.';

    if (error is PostgrestException) {
      if (error.code == '42501') {
        errorMessage =
            'Sistemsel Güvenlik Engeli (RLS): Veritabanı güvenlik kuralları bu işlemi yapmanıza izin vermiyor.';
      } else {
        errorMessage = 'Veritabanı ile iletişimde bir sorun oluştu.';
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[800],
      ),
    );
  }

  // --- SÜRÜKLE BIRAK SONRASI HIZLI GÜNCELLEME ---
  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    // 1. Ekranı anında güncelle (Kullanıcı beklemesin, kart anında geçsin)
    setState(() {
      final taskIndex = _tasks.indexWhere((t) => t['id'] == taskId);
      if (taskIndex != -1) {
        _tasks[taskIndex]['status'] = newStatus;
      }
    });

    // 2. Arka planda veritabanına kaydet
    try {
      await supabase
          .from('tasks')
          .update({'status': newStatus})
          .eq('id', taskId);
    } catch (e) {
      _showUserFriendlyError(e);
      _fetchData(); // Hata olursa tabloyu eski orijinal haline geri döndür
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await supabase.from('tasks').delete().eq('id', taskId);
      _fetchData();
    } catch (e) {
      _showUserFriendlyError(e);
    }
  }

  void _showTaskDialog() {
    final titleController = TextEditingController();
    String? selectedClientId;
    String? selectedPersonnelId;
    DateTime? selectedDate;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Yeni Görev / İş Emri',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: isProcessing
                ? const SizedBox(
                    height: 150,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00ACC1),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: SizedBox(
                      width: 400,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: titleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Görev Adı',
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
                          DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF222222),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'İlgili Mükellef (Opsiyonel)',
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
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Seçiniz'),
                              ),
                              ..._clients.map(
                                (c) => DropdownMenuItem<String>(
                                  value: c['id'],
                                  child: Text(c['title']),
                                ),
                              ),
                            ],
                            value: selectedClientId,
                            onChanged: (value) =>
                                setDialogState(() => selectedClientId = value),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF222222),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Atanan Personel (Opsiyonel)',
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
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Kendime Ata'),
                              ),
                              ..._personnel.map(
                                (p) => DropdownMenuItem<String>(
                                  value: p['id'],
                                  child: Text(p['full_name']),
                                ),
                              ),
                            ],
                            value: selectedPersonnelId,
                            onChanged: (value) => setDialogState(
                              () => selectedPersonnelId = value,
                            ),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                                builder: (context, child) => Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFF00ACC1),
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (date != null)
                                setDialogState(() => selectedDate = date);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF101014),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    selectedDate != null
                                        ? 'Son Tarih: ${DateFormat('dd.MM.yyyy').format(selectedDate!)}'
                                        : 'Son Teslim Tarihi Seç',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_month,
                                    color: Color(0xFF00ACC1),
                                  ),
                                ],
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
                        if (titleController.text.trim().isEmpty) return;
                        setDialogState(() => isProcessing = true);
                        try {
                          await supabase.from('tasks').insert({
                            'company_id': _companyId,
                            'title': titleController.text.trim(),
                            'client_id': selectedClientId,
                            'assigned_to': selectedPersonnelId,
                            'due_date': selectedDate?.toIso8601String(),
                            'status': 'todo',
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            _fetchData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Görev oluşturuldu!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          _showUserFriendlyError(e);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                      ),
                      child: const Text(
                        'Görevi Oluştur',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  // --- KARTIN KENDİSİNİ ÇİZEN WİDGET (Sürükleme sırasındaki görünüm için ayırdık) ---
  Widget _buildTaskCard(Map<String, dynamic> t, String statusKey) {
    final clientTitle = _clients.firstWhere(
      (c) => c['id'] == t['client_id'],
      orElse: () => {'title': 'Genel Görev'},
    )['title'];
    final personnelName = _personnel.firstWhere(
      (p) => p['id'] == t['assigned_to'],
      orElse: () => {'full_name': 'Atanmadı'},
    )['full_name'];

    String dateText = '';
    bool isLate = false;
    if (t['due_date'] != null) {
      final d = DateTime.parse(t['due_date'].toString());
      dateText = DateFormat('dd.MM.yyyy').format(d);
      isLate = d.isBefore(DateTime.now()) && statusKey != 'completed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white54,
                  size: 20,
                ),
                color: const Color(0xFF222222),
                onSelected: (value) {
                  if (value == 'delete')
                    _deleteTask(t['id']);
                  else
                    _updateTaskStatus(t['id'], value);
                },
                itemBuilder: (context) => [
                  if (statusKey != 'todo')
                    const PopupMenuItem(
                      value: 'todo',
                      child: Text(
                        'Yapılacaklara Al',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  if (statusKey != 'in_progress')
                    const PopupMenuItem(
                      value: 'in_progress',
                      child: Text(
                        'İşlemde',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  if (statusKey != 'completed')
                    const PopupMenuItem(
                      value: 'completed',
                      child: Text(
                        'Tamamlandı',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Sil',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.business, color: Colors.white30, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  clientTitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white30, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  personnelName,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
          if (dateText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLate
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : Colors.white12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: isLate ? Colors.redAccent : Colors.white54,
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateText,
                      style: TextStyle(
                        color: isLate ? Colors.redAccent : Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- SÜRÜKLE BIRAK (DRAG & DROP) ÖZELLİKLİ KOLON ---
  Widget _buildKanbanColumn(String title, String statusKey, Color color) {
    final columnTasks = _tasks
        .where((t) => (t['status'] ?? 'todo') == statusKey)
        .toList();

    return Expanded(
      child: DragTarget<String>(
        onWillAccept: (data) => true, // Her türlü ID'yi kabul et
        onAccept: (taskId) {
          // Eğer aynı kolona bırakılmadıysa durumu güncelle
          final task = _tasks.firstWhere((t) => t['id'] == taskId);
          if (task['status'] != statusKey) {
            _updateTaskStatus(taskId, statusKey);
          }
        },
        builder: (context, candidateData, rejectedData) {
          // Üzerine bir kart sürüklendiğinde kolonun rengini hafifçe parlatıyoruz
          final isHovering = candidateData.isNotEmpty;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isHovering
                  ? const Color(0xFF1E1E26)
                  : const Color(0xFF16161A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHovering
                    ? color.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.05),
                width: isHovering ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: color, width: 2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${columnTasks.length}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: columnTasks.length,
                    itemBuilder: (context, index) {
                      final t = columnTasks[index];
                      final cardWidget = _buildTaskCard(t, statusKey);

                      // DRAGGABLE: Kartı Sürüklenebilir Hale Getiriyoruz
                      return Draggable<String>(
                        data: t['id'], // Taşınan veri (Görev ID'si)
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width:
                                300, // Sürüklenirken kartın havada durma boyutu
                            child: Opacity(opacity: 0.9, child: cardWidget),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: cardWidget,
                        ), // Geride kalan asıl kartın soluk hali
                        child: cardWidget, // Normal duruşu
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        title: const Text(
          'Görev & İş Takibi (Kanban)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKanbanColumn('Yapılacaklar', 'todo', Colors.orange),
                  _buildKanbanColumn(
                    'İşlemde (Devam Eden)',
                    'in_progress',
                    Colors.blueAccent,
                  ),
                  _buildKanbanColumn(
                    'Tamamlanan İşler',
                    'completed',
                    Colors.greenAccent,
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTaskDialog,
        backgroundColor: const Color(0xFF00ACC1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Yeni Görev',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
