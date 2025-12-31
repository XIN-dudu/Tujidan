import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';

class TaskSelector extends StatefulWidget {
  final Task? selectedTask;
  final Function(Task?) onTaskSelected;

  const TaskSelector({
    super.key,
    required this.selectedTask,
    required this.onTaskSelected,
  });

  @override
  State<TaskSelector> createState() => _TaskSelectorState();
}

class _TaskSelectorState extends State<TaskSelector> {
  List<Task> _tasks = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await TaskService.getTasks();
      if (mounted) {
        if (response.success && response.data != null) {
          setState(() {
            _tasks = response.data!;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载任务失败: ${response.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载任务失败: $e')),
        );
      }
    }
  }

  List<Task> get _filteredTasks {
    if (_searchQuery.isEmpty) return _tasks;
    return _tasks.where((task) =>
        task.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        task.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        task.assignee.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void _showTaskSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('选择关联任务'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                // 搜索框
                TextField(
                  decoration: const InputDecoration(
                    hintText: '搜索任务...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // 任务列表
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredTasks.isEmpty
                          ? const Center(child: Text('暂无任务'))
                          : ListView.builder(
                              itemCount: _filteredTasks.length + 1, // +1 for "不关联任务"选项
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return ListTile(
                                    leading: const Icon(Icons.clear),
                                    title: const Text('不关联任务'),
                                    onTap: () {
                                      widget.onTaskSelected(null);
                                      Navigator.of(context).pop();
                                    },
                                  );
                                }
                                
                                final task = _filteredTasks[index - 1];
                                final isSelected = widget.selectedTask?.id == task.id;
                                
                                return ListTile(
                                  leading: Icon(
                                    Icons.task_alt,
                                    color: isSelected ? Colors.blue : null,
                                  ),
                                  title: Text(
                                    task.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('负责人: ${task.assignee}'),
                                      Text('截止时间: ${_formatDateTime(task.deadline)}'),
                                      Text('优先级: ${task.priority.displayName}'),
                                      Text('进度: ${task.progress}%'),
                                      LinearProgressIndicator(
                                        value: task.progress / 100.0,
                                        backgroundColor: Colors.grey[300],
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          task.progress == 100 ? Colors.green : Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                                  onTap: () {
                                    widget.onTaskSelected(task);
                                    Navigator.of(context).pop();
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatAssigneeDisplay(Task task) {
    if (task.assigneeId.isEmpty) {
      return '未指定';
    }
    // 只显示用户名，不显示ID
    if (task.assignee.isNotEmpty && task.assignee != task.assigneeId) {
      return task.assignee;
    }
    // 如果没有用户名，显示"未指定"
    return '未指定';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.task_alt),
        title: const Text('关联任务'),
        subtitle: widget.selectedTask != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('任务: ${widget.selectedTask!.name}'),
                  Text('负责人: ${_formatAssigneeDisplay(widget.selectedTask!)}'),
                  Text('截止时间: ${_formatDateTime(widget.selectedTask!.deadline)}'),
                  Text('进度: ${widget.selectedTask!.progress}%'),
                  LinearProgressIndicator(
                    value: widget.selectedTask!.progress / 100.0,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.selectedTask!.progress == 100 ? Colors.green : Colors.blue,
                    ),
                  ),
                ],
              )
            : const Text('点击选择要关联的任务（可选）'),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: _showTaskSelectionDialog,
      ),
    );
  }
}
