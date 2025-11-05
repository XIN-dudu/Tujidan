import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/api_response.dart';
import '../services/task_service.dart';
import '../services/user_service.dart';
import 'task_edit_page.dart';

class TaskViewPage extends StatefulWidget {
  final Task task;
  const TaskViewPage({super.key, required this.task});

  @override
  State<TaskViewPage> createState() => _TaskViewPageState();
}

class _TaskViewPageState extends State<TaskViewPage> {
  late Task _task;
  bool _working = false;
  bool _canEdit = false;
  bool _canPublish = false;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final roles = await _userService.getUserRoles();
    // founder和admin对任务的权限完全相同
    final isAdminOrLeader = roles.contains('admin') || 
                          roles.contains('founder') ||
                          roles.contains('leader') || 
                          roles.contains('管理员') || 
                          roles.contains('领导');
    setState(() {
      _canEdit = isAdminOrLeader;
      _canPublish = isAdminOrLeader;
    });
  }

  Future<void> _reloadTask() async {
    final response = await TaskService.getTaskById(_task.id);
    if (response.success && response.data != null) {
      setState(() => _task = response.data!);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskEditPage(task: _task)),
    );
    if (changed == true) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _publish() async {
    setState(() => _working = true);
    final ApiResponse<Task> res = await TaskService.publishTask(_task.id, ownerUserId: _task.assignee);
    if (!mounted) return;
    setState(() => _working = false);
    if (res.success && res.data != null) {
      setState(() => _task = res.data!);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分配成功')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _accept() async {
    setState(() => _working = true);
    final ApiResponse<Task> res = await TaskService.acceptTask(_task.id);
    if (!mounted) return;
    setState(() => _working = false);
    if (res.success && res.data != null) {
      setState(() => _task = res.data!);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已接收任务')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _cancelAccept() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认取消接收'),
        content: const Text('确定要取消接收此任务吗？任务状态将变更为待开始。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _working = true);
    final ApiResponse<Task> res = await TaskService.cancelAcceptTask(_task.id);
    if (!mounted) return;
    setState(() => _working = false);
    if (res.success && res.data != null) {
      setState(() => _task = res.data!);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消接收')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 判断当前用户是否是任务接收者
    final bool isAssignee = _task.assignee.isNotEmpty && 
                            (_task.status == TaskStatus.in_progress || _task.status == TaskStatus.completed);
    
    // 判断任务是否已分配：状态为not_started且assignee_id不为空
    final bool isPublished = _task.status == TaskStatus.not_started && _task.assignee.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(title: const Text('任务详情')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_task.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('优先级：${_task.priority.displayName}'),
              const SizedBox(height: 8),
              Text('状态：${_task.status.displayName}'),
              const SizedBox(height: 8),
              Text('负责人：${_task.assignee.isEmpty ? '未指定' : _task.assignee}'),
              const SizedBox(height: 8),
              Text('计划截至：${_task.deadline.year}-${_task.deadline.month.toString().padLeft(2, '0')}-${_task.deadline.day.toString().padLeft(2, '0')}'),
              if (_task.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('任务描述：', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_task.description),
              ],
              const SizedBox(height: 24),
              // 编辑按钮（只有管理员/领导可见）
              if (_canEdit) ...[
                ElevatedButton.icon(
                  onPressed: _working ? null : _edit,
                  icon: const Icon(Icons.edit),
                  label: const Text('编辑任务'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // 根据状态显示不同按钮
              if (isAssignee)
                // 已接收任务，显示取消接收按钮
                OutlinedButton.icon(
                  onPressed: _working ? null : _cancelAccept,
                  icon: const Icon(Icons.cancel),
                  label: const Text('取消接收'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                )
              else
                // 未接收任务，显示接收和分配/撤回分配按钮
                Row(
                  children: [
                    if (_canPublish) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _working ? null : _publish,
                          icon: Icon(isPublished ? Icons.undo : Icons.campaign),
                          label: Text(isPublished ? '撤回分配' : '分配任务'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // 只有已分配的任务，负责人才能看到"接收任务"按钮
                    if (isPublished) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : _accept,
                          icon: const Icon(Icons.how_to_reg),
                          label: const Text('接收任务'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}


