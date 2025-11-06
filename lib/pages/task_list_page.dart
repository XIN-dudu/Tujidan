import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/api_response.dart';
import '../services/task_service.dart';
import '../services/user_service.dart';
import 'task_edit_page.dart';
import 'task_view_page.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  bool _loading = false;
  bool _canCreate = false;
  List<Task> _tasks = [];
  List<Task> _allTasks = []; // 存储所有任务，用于本地筛选
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  DateTime? _deadlineFilter; // 结束时间筛选
  DateTime? _startTimeFilter; // 开始时间筛选
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _load();
  }

  void _filterTasks() {
    final keyword = _searchController.text.trim().toLowerCase();
    setState(() {
      _tasks = _allTasks.where((task) {
        // 关键词筛选
        final matchesKeyword = keyword.isEmpty ||
            task.name.toLowerCase().contains(keyword) ||
            task.description.toLowerCase().contains(keyword);
        
        // 结束时间筛选
        final matchesDeadline = _deadlineFilter == null ||
            task.deadline.isBefore(_deadlineFilter!);

        // 开始时间筛选
        final matchesStartTime = _startTimeFilter == null ||
            (task.plannedStart?.isAfter(_startTimeFilter!) ?? false);

        return matchesKeyword && matchesDeadline && matchesStartTime;
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context, bool isDeadline) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDeadline ? (_deadlineFilter ?? DateTime.now()) : (_startTimeFilter ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isDeadline ? '选择结束时间筛选' : '选择开始时间筛选',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (picked != null) {
      setState(() {
        if (isDeadline) {
          _deadlineFilter = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            59,
          );
        } else {
          _startTimeFilter = DateTime(
            picked.year,
            picked.month,
            picked.day,
            0,
            0,
            0,
          );
        }
      });
      _filterTasks();
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final roles = await _userService.getUserRoles();
    // founder/admin和dept_head可以创建任务，staff不能创建
    final isFounderOrAdmin = roles.contains('admin') || roles.contains('founder');
    final isDeptHead = roles.contains('dept_head');
    final isStaff = roles.contains('staff');
    
    setState(() => _canCreate = isFounderOrAdmin || isDeptHead);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ApiResponse<List<Task>> res = await TaskService.getTasks();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _allTasks = res.data ?? [];
    });
    _filterTasks();
  }

  void _onSearch(String value) {
    _filterTasks();
  }

  Future<void> _create() async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaskEditPage()),
    );
    if (changed == true) _load();
  }

  Future<void> _open(Task task) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskViewPage(task: task)),
    );
    if (changed == true) _load();
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        actions: [
          // 开始时间按钮
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: '选择开始时间筛选',
            onPressed: () => _selectDate(context, false),
          ),
          if (_startTimeFilter != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '清除开始时间筛选',
              onPressed: () {
                setState(() {
                  _startTimeFilter = null;
                });
                _filterTasks();
              },
            ),
          // 结束时间按钮
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: '选择结束时间筛选',
            onPressed: () => _selectDate(context, true),
          ),
          if (_deadlineFilter != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '清除结束时间筛选',
              onPressed: () {
                setState(() {
                  _deadlineFilter = null;
                });
                _filterTasks();
              },
            ),
          // 刷新按钮
          IconButton(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索任务...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterTasks();
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) => _onSearch(value),
                ),
                if (_startTimeFilter != null || _deadlineFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_startTimeFilter != null)
                          Row(
                            children: [
                              const Icon(Icons.filter_list, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '开始时间在 ${_startTimeFilter!.year}年${_startTimeFilter!.month}月${_startTimeFilter!.day}日 之后',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        if (_deadlineFilter != null)
                          Padding(
                            padding: EdgeInsets.only(top: _startTimeFilter != null ? 4.0 : 0),
                            child: Row(
                              children: [
                                const Icon(Icons.filter_list, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '结束时间在 ${_deadlineFilter!.year}年${_deadlineFilter!.month}月${_deadlineFilter!.day}日 之前',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(
                  child: Text('没有找到任务'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final t = _tasks[index];
                    return Dismissible(
                      key: Key(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[400]!, Colors.red[600]!],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_forever,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(height: 6),
                            Text(
                              '删除',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        // 显示确认对话框
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, 
                                     color: Colors.orange[600], size: 24),
                                const SizedBox(width: 8),
                                const Text('删除任务'),
                              ],
                            ),
                            content: const Text(
                              '确定要删除这个任务吗？\n此操作无法撤销。',
                              style: TextStyle(fontSize: 16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[600],
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                ),
                                child: const Text('取消'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        return confirmed ?? false;
                      },
                      onDismissed: (direction) async {
                        // 执行删除操作
                        try {
                          final response = await TaskService.deleteTask(t.id);
                          if (response.success) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      const Text('任务删除成功'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green[600],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            // 重新加载列表
                            _load();
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.error, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('删除失败: ${response.message}')),
                                    ],
                                  ),
                                  backgroundColor: Colors.red[600],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                            // 如果删除失败，重新加载列表
                            _load();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.error, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('删除失败: $e')),
                                  ],
                                ),
                                backgroundColor: Colors.red[600],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                          // 如果删除失败，重新加载列表
                          _load();
                        }
                      },
                      child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: _priorityColor(t.priority), child: const Icon(Icons.task, color: Colors.white)),
                        title: Text(t.name),
                        subtitle: Text('状态: ${t.status.displayName}  进度: ${t.progress}%'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(t),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('新建任务'),
            )
          : null,
    );
  }
}


