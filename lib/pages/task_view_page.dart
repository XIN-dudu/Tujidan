import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/page_transitions.dart';
import '../models/task.dart';
import '../models/api_response.dart';
import '../services/task_service.dart';
import '../services/user_service.dart';
import '../widgets/user_picker_dialog.dart';
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
    
    // 判断当前用户是否是任务创建者
    final isCreator = _task.creator == currentUserId;
    // 判断当前用户是否是任务负责人
    final isAssignee = _task.assigneeId == currentUserId && _task.assigneeId.isNotEmpty;

    setState(() {
      // 编辑权限：founder/admin可以编辑任何任务，dept_head只能编辑自己创建的，负责人可编辑自己任务
      _canEdit = isFounderOrAdmin || (isDeptHead && isCreator) || isAssignee;
      
      // 编辑进度权限：当前仅用于兼容旧逻辑
      _canEditProgress = !_canEdit && isAssignee;
      
      // 删除权限：founder/admin可以删除任何任务，dept_head只能删除自己创建的，staff不能删除
      _canDelete = isFounderOrAdmin || (isDeptHead && isCreator);
      
      // 分配权限：founder/admin可以分配任何任务，dept_head只能分配自己创建的，staff不能分配
      _canPublish = isFounderOrAdmin || (isDeptHead && isCreator);
    });
  }

  String _formatAssigneeDisplay() {
    if (_task.assigneeId.isEmpty) {
      return '未指定';
    }
    if (_task.assignee.isEmpty || _task.assignee == _task.assigneeId) {
      return '用户ID: ${_task.assigneeId}';
    }
    return '${_task.assignee} (ID: ${_task.assigneeId})';
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
    final isAssigned = _task.status != TaskStatus.pending_assignment;
    String? targetUserId = _task.assigneeId;

    // 如果是分配任务（非撤回），则弹出选择负责人对话框
    if (!isAssigned) {
      final Map<String, String>? picked = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => const UserPickerDialog(),
      );
      if (picked == null) return; // 用户取消选择
      targetUserId = picked['id'];
    }

    setState(() => _working = true);
    final ApiResponse<Task> res = await TaskService.publishTask(_task.id, ownerUserId: targetUserId);
    if (!mounted) return;
    setState(() => _working = false);
    if (res.success && res.data != null) {
      setState(() => _task = res.data!);
      await _checkPermissions(); // 重新检查权限
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAssigned ? '撤回成功' : '分配成功')),
      );
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
    // 判断任务是否已分配（非待分配状态）
    final bool isAssigned = _task.status != TaskStatus.pending_assignment;
    
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
                Text(
                  '负责人：${_formatAssigneeDisplay()}',
                ),
                const SizedBox(height: 8),
                Text('计划截至：${_task.deadline.year}-${_task.deadline.month.toString().padLeft(2, '0')}-${_task.deadline.day.toString().padLeft(2, '0')}'),
                if (_task.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('任务描述：', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_task.description),
                ],
                // 显示任务图片
                if (_task.images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('任务图片', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildTaskImages(),
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
                if (_canPublish)
                  ElevatedButton.icon(
                    onPressed: _working ? null : _publish,
                    icon: Icon(isAssigned ? Icons.undo : Icons.campaign),
                    label: Text(isAssigned ? '撤回分配' : '分配任务'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Uint8List _decodeImageData(String dataUri) {
    final parts = dataUri.split(',');
    final base64Part = parts.length > 1 ? parts[1] : parts[0];
    return base64Decode(base64Part);
  }

  // 预览图片
  void _previewImage(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImagePreviewPage(
          images: _task.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // 保存图片到相册
  Future<void> _saveImageToGallery(int index) async {
    try {
      // 请求存储权限（Android 13+ 使用 photos，旧版本使用 storage）
      PermissionStatus status;
      if (await Permission.photos.isRestricted) {
        status = await Permission.storage.request();
      } else {
        status = await Permission.photos.request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      }
      
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要存储权限才能保存图片')),
          );
        }
        return;
      }

      final imageBytes = _decodeImageData(_task.images[index]);
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: 'task_image_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片已保存到相册')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  // 分享图片
  Future<void> _shareImage(int index) async {
    try {
      final imageBytes = _decodeImageData(_task.images[index]);
      // 创建临时文件路径
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/share_image_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '分享任务图片',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  // 显示长按菜单
  void _showImageMenu(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('保存到相册'),
              onTap: () {
                Navigator.pop(context);
                _saveImageToGallery(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                _shareImage(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 构建任务图片显示
  Widget _buildTaskImages() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (int i = 0; i < _task.images.length; i++)
          GestureDetector(
            onTap: () => _previewImage(i),
            onLongPress: () => _showImageMenu(context, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _decodeImageData(_task.images[i]),
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
    );
  }
}

// 图片预览页面
class _ImagePreviewPage extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const _ImagePreviewPage({
    required this.images,
    this.initialIndex = 0,
  });

  Uint8List _decodeImageData(String dataUri) {
    final parts = dataUri.split(',');
    final base64Part = parts.length > 1 ? parts[1] : parts[0];
    return base64Decode(base64Part);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${initialIndex + 1} / ${images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: MemoryImage(_decodeImageData(images[index])),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
        itemCount: images.length,
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
          ),
        ),
        pageController: PageController(initialPage: initialIndex),
      ),
    );
  }
}


