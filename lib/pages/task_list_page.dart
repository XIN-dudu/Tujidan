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
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _load();
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
      _tasks = res.data ?? [];
    });
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
      appBar: AppBar(title: const Text('任务列表'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
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


