import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/page_transitions.dart';
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
  bool _canEditProgress = false; // 只能编辑进度的权限
  bool _canDelete = false;
  bool _canPublish = false;
  bool _canAccept = false;
  bool _canCancelAccept = false;
  String? _currentUserId;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // 获取当前用户ID和角色
    final userInfo = await _userService.getCurrentUser();
    final roles = await _userService.getUserRoles();
    
    final currentUserId = userInfo?['id']?.toString() ?? '';
    final isFounderOrAdmin = roles.contains('admin') || roles.contains('founder');
    final isDeptHead = roles.contains('dept_head');
    final isStaff = roles.contains('staff');
    
    // 判断当前用户是否是任务创建者
    final isCreator = _task.creator == currentUserId;
    // 判断当前用户是否是任务负责人
    final isAssignee = _task.assignee == currentUserId && _task.assignee.isNotEmpty;
    // 判断任务是否已分配（不是pending_assignment）
    final isAssigned = _task.status != TaskStatus.pending_assignment;
    // 判断任务是否已接收（in_progress或completed）
    final isAccepted = _task.status == TaskStatus.in_progress || _task.status == TaskStatus.completed;
    // 判断任务是否待接收（not_started且已分配）
    final isPendingAccept = _task.status == TaskStatus.not_started && isAssignee;
    
    setState(() {
      _currentUserId = currentUserId;
      
      // 编辑权限：founder/admin可以编辑任何任务，dept_head只能编辑自己创建的
      _canEdit = isFounderOrAdmin || (isDeptHead && isCreator);
      
      // 编辑进度权限：被分配方（非创建者）可以编辑任务进度
      _canEditProgress = isAssignee && !isCreator;
      
      // 删除权限：founder/admin可以删除任何任务，dept_head只能删除自己创建的，staff不能删除
      _canDelete = isFounderOrAdmin || (isDeptHead && isCreator);
      
      // 分配权限：founder/admin可以分配任何任务，dept_head只能分配自己创建的，staff不能分配
      _canPublish = isFounderOrAdmin || (isDeptHead && isCreator);
      
      // 接收权限：只有被分配人（且必须是已分配状态）可以接收
      _canAccept = isAssignee && isPendingAccept;
      
      // 取消接收权限：只有已接收任务的负责人可以取消
      _canCancelAccept = isAssignee && isAccepted;
    });
  }

  Future<void> _reloadTask() async {
    final response = await TaskService.getTaskById(_task.id);
    if (response.success && response.data != null) {
      setState(() => _task = response.data!);
      // 重新检查权限（因为任务状态可能已改变）
      await _checkPermissions();
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      SlidePageRoute(
        page: TaskEditPage(
          task: _task,
          canEditAll: _canEdit, // 传递是否可以编辑所有字段
          canEditProgressOnly: _canEditProgress, // 传递是否只能编辑进度
        ),
      ),
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
      await _checkPermissions(); // 重新检查权限
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
      await _checkPermissions(); // 重新检查权限
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
      await _checkPermissions(); // 重新检查权限
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消接收')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _delete() async {
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
    if (confirmed != true) return;

    setState(() => _working = true);
    try {
      final response = await TaskService.deleteTask(_task.id);
      if (!mounted) return;
      setState(() => _working = false);
      
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
          // 返回上一页并刷新列表
          Navigator.of(context).pop(true);
        }
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
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    // 判断任务是否已分配：状态为not_started且assignee_id不为空
    final bool isPublished = _task.status == TaskStatus.not_started && _task.assignee.isNotEmpty;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // 返回前刷新任务数据
          await _reloadTask();
          // 返回true以触发列表页刷新
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('任务详情', style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              // 返回前刷新任务数据
              await _reloadTask();
              // 返回true以触发列表页刷新
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
          actions: [
            // 删除按钮（只有有删除权限的用户可见）
            if (_canDelete)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _working ? null : _delete,
                tooltip: '删除任务',
              ),
          ],
        ),
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
                // 编辑按钮（创建者/管理员/领导可见，或被分配方可见）
                if (_canEdit || _canEditProgress)
                  ElevatedButton.icon(
                    onPressed: _working ? null : _edit,
                    icon: const Icon(Icons.edit),
                    label: Text(_canEdit ? '编辑任务' : '更新进度'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                if (_canEdit || _canEditProgress) const SizedBox(height: 12),
                // 根据权限和状态显示不同按钮
                if (_canCancelAccept)
                  // 已接收任务，显示取消接收按钮（只有有权限的用户可见）
                  ElevatedButton.icon(
                    onPressed: _working ? null : _cancelAccept,
                    icon: const Icon(Icons.cancel),
                    label: const Text('取消接收'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  )
                else if (_canPublish || _canAccept)
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
                        if (_canAccept) const SizedBox(width: 12),
                      ],
                      // 接收任务按钮（只有被分配人且有权限的用户可见）
                      if (_canAccept) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _working ? null : _accept,
                            icon: const Icon(Icons.how_to_reg),
                            label: const Text('接收任务'),
                            style: ElevatedButton.styleFrom(
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
      ),
    );
  }
}


