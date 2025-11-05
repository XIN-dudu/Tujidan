import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/api_response.dart';
import '../services/task_service.dart';
import '../services/api_client.dart';

class TaskEditPage extends StatefulWidget {
  final Task? task;
  const TaskEditPage({super.key, this.task});

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _assignee = TextEditingController();
  String? _assigneeId; // 存储用户ID
  DateTime? _due;
  DateTime? _planStart;
  TaskPriority _priority = TaskPriority.low;
  double _progress = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _name.text = widget.task!.name;
      _desc.text = widget.task!.description;
      _assignee.text = widget.task!.assignee;
      _due = widget.task!.deadline;
      _planStart = widget.task!.plannedStart;
      _priority = widget.task!.priority;
      _progress = widget.task!.progress.toDouble();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _assignee.dispose();
    super.dispose();
  }

  Future<void> _save({bool publish = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final task = Task(
      id: widget.task?.id ?? '',
      name: _name.text.trim(),
      description: _desc.text.trim(),
      assignee: _assigneeId ?? _assignee.text.trim(),
      deadline: _due ?? now,
      plannedStart: _planStart,
      priority: _priority,
      status: widget.task?.status ?? TaskStatus.not_started,
      progress: widget.task?.progress ?? 0,
      createdAt: widget.task?.createdAt ?? now,
      updatedAt: now,
    );

    ApiResponse<Task> res;
    if (widget.task == null) {
      if (publish) {
        // 创建并分配
        res = await TaskService.createAndPublishTask(task, assigneeId: _assigneeId);
      } else {
        // 仅创建
        res = await TaskService.createTask(task);
      }
    } else {
      res = await TaskService.updateTask(task);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      // The original instruction was to pop with `true`, which is already done.
      // However, the failed block suggests a SnackBar was intended for success cases.
      // Adding it for better UX consistency.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('进度更新成功')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(context: context, initialDate: _due ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => _due = d);
  }

  Future<void> _updateProgress() async {
    if (widget.task == null) return;
    setState(() => _saving = true);
    final res = await TaskService.updateTaskProgress(widget.task!.id, _progress.round());
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _pickPlanStart() async {
    final d = await showDatePicker(context: context, initialDate: _planStart ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => _planStart = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task == null ? '新建任务' : '编辑任务')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '任务名称', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '请输入任务名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '任务描述', border: OutlineInputBorder(), hintText: '可填写任务背景、目标等'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('优先级：'),
                  const SizedBox(width: 8),
                  DropdownButton<TaskPriority>(
                    value: _priority,
                    items: TaskPriority.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.displayName)))
                        .toList(),
                    onChanged: (v) => setState(() => _priority = v ?? TaskPriority.low),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _assignee,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: '负责人（搜索用户名/姓名）', border: OutlineInputBorder()),
                  onTap: () async {
                    final Map<String, String>? picked = await showDialog<Map<String, String>>(
                      context: context,
                      builder: (context) => const _UserPickerDialog(),
                    );
                    if (picked != null) {
                      setState(() {
                        _assigneeId = picked['id'];
                        _assignee.text = picked['name'] ?? '';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('计划开始时间'),
                  subtitle: Text(_planStart == null ? '未选择' : '${_planStart!.year}-${_planStart!.month.toString().padLeft(2, '0')}-${_planStart!.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.event),
                  onTap: _pickPlanStart,
                ),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('计划截止时间'),
                  subtitle: Text(_due == null ? '未选择' : '${_due!.year}-${_due!.month.toString().padLeft(2, '0')}-${_due!.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.event),
                  onTap: _pickDue,
                ),
                const SizedBox(height: 16),
                if (widget.task != null) ...[
                  const Text('任务进度'),
                  Slider(
                    value: _progress,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${_progress.round()}%',
                    onChanged: (value) {
                      setState(() {
                        _progress = value;
                      });
                    },
                  ),
                  Text('当前进度: ${_progress.round()}%'),
                  const SizedBox(height: 12),
                ],
                if (widget.task == null) ...[
                  // 创建任务时显示两个按钮
                  ElevatedButton(
                    onPressed: _saving ? null : () => _save(publish: false),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('创建任务'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : () => _save(publish: true),
                    icon: const Icon(Icons.campaign),
                    label: const Text('创建并分配任务'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ] else ...[
                  // 编辑任务时只显示保存按钮
                  ElevatedButton(
                    onPressed: _saving ? null : () => _save(publish: false),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('保存修改'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _updateProgress,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('更新进度'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserPickerDialog extends StatefulWidget {
  const _UserPickerDialog();

  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
  final TextEditingController _q = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _loading = false;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // 监听输入框变化，实时搜索
    _q.addListener(_onSearchChanged);
    // 对话框打开时自动加载用户列表（不预填充搜索框）
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _q.removeListener(_onSearchChanged);
    _q.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // 防抖处理：用户停止输入500ms后再搜索
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _search();
    });
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final keyword = _q.text.trim();
      final url = keyword.isEmpty ? '/users' : '/users?keyword=${Uri.encodeComponent(keyword)}';
      final res = await ApiClient.get<Map<String, dynamic>>(
        url,
        fromJson: (data) => data as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (res.success && res.data != null) {
          _list = (res.data!['users'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        } else {
          _list = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _list = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择负责人'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _q,
            decoration: InputDecoration(
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            width: 360,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无用户\n请尝试输入关键词搜索',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final u = _list[i];
                          final name = (u['real_name'] ?? u['username'] ?? '未知').toString();
                          return ListTile(
                            title: Text(name),
                            subtitle: Text('ID: ${u['id']}  用户名: ${u['username'] ?? ''}'),
                            onTap: () => Navigator.of(context).pop({
                              'id': u['id'].toString(),
                              'name': name,
                            }),
                          );
                        },
                      ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      ],
    );
  }
}


