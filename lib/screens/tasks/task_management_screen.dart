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
        'İşleminiz şu anda gerçekleştirilemiyor. Lütfen bağlantınızı kontrol edin.';
    if (error is PostgrestException && error.code == '42501') {
      errorMessage =
          'Sistemsel Güvenlik Engeli (RLS): Veritabanı güvenlik kuralları bu işleme izin vermiyor.';
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

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    setState(() {
      final taskIndex = _tasks.indexWhere((t) => t['id'] == taskId);
      if (taskIndex != -1) {
        _tasks[taskIndex]['status'] = newStatus;
      }
    });

    try {
      await supabase
          .from('tasks')
          .update({'status': newStatus})
          .eq('id', taskId);
    } catch (e) {
      _showUserFriendlyError(e);
      _fetchData();
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
                      width: isMobile ? screenWidth : 420,
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
                            isExpanded: true,
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
                                  child: Text(
                                    c['title'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            value: selectedClientId,
                            onChanged: (value) =>
                                setDialogState(() => selectedClientId = value),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
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
                                  child: Text(
                                    p['full_name'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                                vertical: 18,
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
                  if (value == 'delete') {
                    _deleteTask(t['id']);
                  } else {
                    _updateTaskStatus(t['id'], value);
                  }
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
                        'İşlemdeye Al',
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                  if (statusKey != 'completed')
                    const PopupMenuItem(
                      value: 'completed',
                      child: Text(
                        'Tamamlandı İşaretle',
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
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
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
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
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
                  borderRadius: BorderRadius.circular(6),
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

  // MOBİL İÇİN LİSTE GÖRÜNÜMÜ (Tam genişlikte ferah kartlar)
  Widget _buildMobileTaskList(String statusKey, Color color) {
    final columnTasks = _tasks
        .where((t) => (t['status'] ?? 'todo') == statusKey)
        .toList();
    if (columnTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bu aşamada görev bulunmuyor.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: columnTasks.length,
      itemBuilder: (context, index) =>
          _buildTaskCard(columnTasks[index], statusKey),
    );
  }

  // WEB İÇİN YAN YANA KANBAN SÜTUNU (Drag & Drop destekli)
  Widget _buildDesktopKanbanColumn(
    String title,
    String statusKey,
    Color color,
  ) {
    final columnTasks = _tasks
        .where((t) => (t['status'] ?? 'todo') == statusKey)
        .toList();

    return Expanded(
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) {
          final taskId = details.data;
          final task = _tasks.firstWhere((t) => t['id'] == taskId);
          if (task['status'] != statusKey) {
            _updateTaskStatus(taskId, statusKey);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
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
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                      return Draggable<String>(
                        data: t['id'],
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 280,
                            child: Opacity(opacity: 0.9, child: cardWidget),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: cardWidget,
                        ),
                        child: cardWidget,
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
    final isMobile = MediaQuery.of(context).size.width < 800;

    final todoCount = _tasks
        .where((t) => (t['status'] ?? 'todo') == 'todo')
        .length;
    final inProgressCount = _tasks
        .where((t) => t['status'] == 'in_progress')
        .length;
    final completedCount = _tasks
        .where((t) => t['status'] == 'completed')
        .length;

    // MOBİL GÖRÜNÜM: SEKMELİ (TABBAR) YAPI
    if (isMobile) {
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: const Color(0xFF101014),
          appBar: AppBar(
            backgroundColor: const Color(0xFF16161A),
            title: const Text(
              'Görev & İş Takibi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            bottom: TabBar(
              indicatorColor: const Color(0xFF00ACC1),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              tabs: [
                Tab(text: 'Yapılacak ($todoCount)'),
                Tab(text: 'İşlemde ($inProgressCount)'),
                Tab(text: 'Biten ($completedCount)'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
                )
              : TabBarView(
                  children: [
                    _buildMobileTaskList('todo', Colors.orange),
                    _buildMobileTaskList('in_progress', Colors.blueAccent),
                    _buildMobileTaskList('completed', Colors.greenAccent),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showTaskDialog,
            backgroundColor: const Color(0xFF00ACC1),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Yeni Görev',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    // WEB / MASAÜSTÜ GÖRÜNÜM: YAN YANA 3 SÜTUN KANBAN
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
                  _buildDesktopKanbanColumn(
                    'Yapılacaklar',
                    'todo',
                    Colors.orange,
                  ),
                  _buildDesktopKanbanColumn(
                    'İşlemde (Devam Eden)',
                    'in_progress',
                    Colors.blueAccent,
                  ),
                  _buildDesktopKanbanColumn(
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
