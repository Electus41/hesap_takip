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

  List<Map<String, dynamic>> _todoTasks = [];
  List<Map<String, dynamic>> _inProgressTasks = [];
  List<Map<String, dynamic>> _doneTasks = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _staff = [];

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

      // Mükellefleri Çek
      final clientsRes = await supabase
          .from('clients')
          .select('id, title')
          .eq('company_id', _companyId)
          .eq('is_active', true)
          .order('title');
      _clients = List<Map<String, dynamic>>.from(clientsRes);

      // Personelleri Çek
      final staffRes = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('company_id', _companyId);
      _staff = List<Map<String, dynamic>>.from(staffRes);

      _fetchTasks();
    } catch (e) {
      debugPrint('Veri çekme hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTasks() async {
    try {
      final tasksRes = await supabase
          .from('tasks')
          .select(
            '*, clients(title), profiles!tasks_assigned_to_fkey(full_name)',
          )
          .eq('company_id', _companyId)
          .order('due_date', ascending: true);

      final List<Map<String, dynamic>> allTasks =
          List<Map<String, dynamic>>.from(tasksRes);

      if (mounted) {
        setState(() {
          _todoTasks = allTasks.where((t) => t['status'] == 'todo').toList();
          _inProgressTasks = allTasks
              .where((t) => t['status'] == 'in_progress')
              .toList();
          _doneTasks = allTasks.where((t) => t['status'] == 'done').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Görev çekme hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      await supabase
          .from('tasks')
          .update({'status': newStatus})
          .eq('id', taskId);
      _fetchTasks();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Durum güncellenemedi.')));
    }
  }

  void _showNewTaskDialog() {
    String? selectedClientId;
    String? selectedStaffId;
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Görev Adı (Örn: Ekim KDV Beyannamesi)',
                            labelStyle: const TextStyle(color: Colors.white54),
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
                            labelText: 'İlgili Mükellef',
                            labelStyle: const TextStyle(color: Colors.white54),
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

                        DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF222222),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Atanan Personel (Opsiyonel)',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF101014),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _staff
                              .map(
                                (s) => DropdownMenuItem<String>(
                                  value: s['id'].toString(),
                                  child: Text(s['full_name'].toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedStaffId = value),
                        ),
                        const SizedBox(height: 16),

                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null)
                              setDialogState(() => selectedDate = picked);
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Son Tarih: ${DateFormat('dd.MM.yyyy').format(selectedDate)}',
                                  style: const TextStyle(color: Colors.white70),
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
                            'client_id': selectedClientId,
                            'title': titleController.text.trim(),
                            'status': 'todo',
                            'assigned_to': selectedStaffId,
                            'due_date': selectedDate.toIso8601String().split(
                              'T',
                            )[0],
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchTasks();
                          }
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
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
                        'Görevi Oluştur',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
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
          'Görev & İş Takibi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKanbanColumn(
                      'Yapılacaklar',
                      'todo',
                      _todoTasks,
                      Colors.orangeAccent,
                    ),
                    const SizedBox(width: 24),
                    _buildKanbanColumn(
                      'İşlemde (Devam Eden)',
                      'in_progress',
                      _inProgressTasks,
                      Colors.blueAccent,
                    ),
                    const SizedBox(width: 24),
                    _buildKanbanColumn(
                      'Tamamlanan İşler',
                      'done',
                      _doneTasks,
                      Colors.greenAccent,
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewTaskDialog,
        backgroundColor: const Color(0xFF00ACC1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Yeni Görev',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(
    String title,
    String status,
    List<Map<String, dynamic>> tasks,
    Color accentColor,
  ) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A20),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: accentColor, width: 3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      color: accentColor,
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
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final t = tasks[index];
                final clientInfo = t['clients'] as Map<String, dynamic>?;
                final staffInfo = t['profiles'] as Map<String, dynamic>?;

                String dateText = '-';
                if (t['due_date'] != null) {
                  try {
                    dateText = DateFormat(
                      'dd MMM',
                    ).format(DateTime.parse(t['due_date']));
                  } catch (_) {}
                }

                return Card(
                  color: const Color(0xFF1A1A20),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['title'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (clientInfo != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.business,
                                color: Colors.white54,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  clientInfo['title'],
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white54,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  dateText,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (staffInfo != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  staffInfo['full_name'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (status != 'todo')
                              TextButton(
                                onPressed: () => _updateTaskStatus(
                                  t['id'],
                                  status == 'done' ? 'in_progress' : 'todo',
                                ),
                                child: const Text(
                                  '← Geri',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (status != 'done')
                              TextButton(
                                onPressed: () => _updateTaskStatus(
                                  t['id'],
                                  status == 'todo' ? 'in_progress' : 'done',
                                ),
                                child: const Text(
                                  'İleri →',
                                  style: TextStyle(
                                    color: Color(0xFF00ACC1),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (status == 'done')
                              IconButton(
                                onPressed: () async {
                                  await supabase
                                      .from('tasks')
                                      .delete()
                                      .eq('id', t['id']);
                                  _fetchTasks();
                                },
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                              ),
                          ],
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
