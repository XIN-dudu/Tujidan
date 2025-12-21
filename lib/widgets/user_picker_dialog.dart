import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class UserPickerDialog extends StatefulWidget {
  const UserPickerDialog({super.key});

  @override
  State<UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<UserPickerDialog> {
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
      final url = keyword.isEmpty
          ? '/users'
          : '/users/search?keyword=${Uri.encodeComponent(keyword)}';
      final res = await ApiClient.get<Map<String, dynamic>>(
        url,
        fromJson: (data) => data as Map<String, dynamic>,
      );
      if (!mounted) return;
      
      List<Map<String, dynamic>> users = [];
      if (res.success && res.data != null) {
        // 尝试从 data 中获取 users 字段
        final usersData = res.data!['users'];
        if (usersData is List) {
          users = usersData.map((u) {
            // 确保 id 是字符串类型，统一数据格式
            final userMap = Map<String, dynamic>.from(u as Map);
            if (userMap['id'] != null) {
              userMap['id'] = userMap['id'].toString();
            }
            return userMap;
          }).toList();
        }
      } else {
        // 如果请求失败，显示错误信息
        final errorMessage = res.message ?? '获取用户列表失败';
        debugPrint('获取用户列表失败: $errorMessage');
        if (mounted && errorMessage.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
      if (!mounted) return;
      setState(() {
        _loading = false;
        _list = users;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _list = [];
      });
      // 打印错误信息以便调试
      debugPrint('获取用户列表异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取用户列表失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
              hintText: '搜索用户名/姓名',
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
                      final name = (u['real_name'] ?? u['username'] ?? '未知')
                          .toString();
                      final departmentText = (() {
                        final dept = u['department_id'];
                        if (dept == null) return '所属部门: 未设置';
                        final deptStr = dept.toString();
                        return deptStr.isEmpty ? '所属部门: 未设置' : '所属部门: $deptStr';
                      })();
                      return ListTile(
                        title: Text(name),
                        subtitle: Text(
                          'ID: ${u['id']}  用户名: ${u['username'] ?? ''}\n$departmentText',
                        ),
                        onTap: () => Navigator.of(
                          context,
                        ).pop({'id': u['id'].toString(), 'name': name}),
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
