import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../models/task.dart';
import '../models/api_response.dart';
import '../services/log_service.dart';
import '../services/task_service.dart';
import '../widgets/task_selector.dart';
import '../widgets/priority_selector.dart';

class LogEditPage extends StatefulWidget {
  final LogEntry? logEntry; // 如果为null则是新建，否则是编辑

  const LogEditPage({super.key, this.logEntry});

  @override
  State<LogEditPage> createState() => _LogEditPageState();
}

class _LogEditPageState extends State<LogEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _contentController = TextEditingController();
  
  Task? _selectedTask;
  TaskPriority _selectedPriority = TaskPriority.low;
  DateTime _selectedTime = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.logEntry != null) {
      _initializeFromExistingLog();
    }
  }

  void _initializeFromExistingLog() {
    final log = widget.logEntry!;
    _contentController.text = log.content;
    _selectedPriority = log.priority;
    _selectedTime = log.time;
    
    // 如果有关联任务，需要获取任务详情
    if (log.taskId != null) {
      _loadTaskDetails(log.taskId!);
    }
  }

  Future<void> _loadTaskDetails(String taskId) async {
    setState(() => _isLoading = true);
    try {
      final response = await TaskService.getTaskById(taskId);
      if (response.success && response.data != null) {
        setState(() {
          _selectedTask = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载任务信息失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final logEntry = LogEntry(
        id: widget.logEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        content: _contentController.text.trim(),
        taskId: _selectedTask?.id,
        priority: _selectedPriority,
        time: _selectedTime,
        createdAt: widget.logEntry?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      ApiResponse<LogEntry> response;
      if (widget.logEntry == null) {
        response = await LogService.createLog(logEntry);
      } else {
        response = await LogService.updateLog(logEntry);
      }

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.logEntry == null ? '日志创建成功' : '日志更新成功'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // 返回true表示保存成功
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteLog() async {
    if (widget.logEntry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条日志吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        final response = await LogService.deleteLog(widget.logEntry!.id);
        if (response.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('日志删除成功'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.logEntry == null ? '写日志' : '编辑日志'),
        actions: [
          if (widget.logEntry != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isSaving ? null : _deleteLog,
              tooltip: '删除日志',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 日志内容
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: '日志内容',
                        hintText: '请输入日志内容',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '日志内容不能为空';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 关联任务选择
                    TaskSelector(
                      selectedTask: _selectedTask,
                      onTaskSelected: (task) {
                        setState(() => _selectedTask = task);
                      },
                    ),
                    const SizedBox(height: 16),

                    // 优先级选择
                    PrioritySelector(
                      selectedPriority: _selectedPriority,
                      onPrioritySelected: (priority) {
                        setState(() => _selectedPriority = priority);
                      },
                    ),
                    const SizedBox(height: 16),

                    // 时间选择
                    ListTile(
                      title: const Text('时间'),
                      subtitle: Text(
                        '${_selectedTime.year}-${_selectedTime.month.toString().padLeft(2, '0')}-${_selectedTime.day.toString().padLeft(2, '0')} ${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedTime,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedTime),
                          );
                          if (time != null) {
                            setState(() {
                              _selectedTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // 保存按钮
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveLog,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.logEntry == null ? '创建日志' : '更新日志'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
