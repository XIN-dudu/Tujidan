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
    // founder和admin对任务的权限完全相同
    final isAdminOrLeader = roles.contains('admin') || 
                          roles.contains('founder') ||
                          roles.contains('leader') || 
                          roles.contains('管理员') || 
                          roles.contains('领导');
    setState(() => _canCreate = isAdminOrLeader);
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: _priorityColor(t.priority), child: const Icon(Icons.task, color: Colors.white)),
                        title: Text(t.name),
                        subtitle: Text('状态: ${t.status.displayName}  进度: ${t.progress}%'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(t),
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


