import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';
import '../models/api_response.dart';
import '../services/task_service.dart';
import '../services/api_client.dart';

import '../widgets/user_picker_dialog.dart';

class TaskEditPage extends StatefulWidget {
  final Task? task;
  final bool canEditAll; // 是否可以编辑所有字段
  final bool canEditProgressOnly; // 是否只能编辑进度
  const TaskEditPage({
    super.key,
    this.task,
    this.canEditAll = true,
    this.canEditProgressOnly = false,
  });

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _assignee = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String? _assigneeId; // 存储用户ID
  String? _assigneeName; // 存储负责人名称
  DateTime? _due;
  DateTime? _planStart;
  TaskPriority _priority = TaskPriority.low;
  TaskStatus _status = TaskStatus.not_started;
  double _progress = 0;
  bool _saving = false;
  List<String> _imageDataUris = [];
  bool _dueManuallyAdjusted = false;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _name.text = widget.task!.name;
      _desc.text = widget.task!.description;
      _assigneeId = widget.task!.assigneeId.isNotEmpty ? widget.task!.assigneeId : null;
      if (widget.task!.assignee.isNotEmpty && widget.task!.assignee != widget.task!.assigneeId) {
        _assigneeName = widget.task!.assignee;
      } else {
        _assigneeName = null;
      }
      _assignee.text = _formatAssigneeDisplay(id: _assigneeId, name: _assigneeName);
      _due = widget.task!.deadline;
      _planStart = widget.task!.plannedStart;
      _priority = widget.task!.priority;
      _status = widget.task!.status;
      _progress = widget.task!.progress.toDouble();
      _imageDataUris = List<String>.from(widget.task!.images);
      _dueManuallyAdjusted = true;
    } else {
      final now = DateTime.now();
      _planStart = now;
      _due = now.add(const Duration(days: 2));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _assignee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.task == null && (_assigneeId == null || _assigneeId!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择负责人后再分配任务')),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final selectedAssigneeId = (_assigneeId ?? '').trim();
    final task = Task(
      id: widget.task?.id ?? '',
      name: _name.text.trim(),
      description: _desc.text.trim(),
      assignee: _assigneeName ?? '',
      assigneeId: selectedAssigneeId,
      creator: widget.task?.creator ?? '', // 创建时后端会自动设置，编辑时保持原值
      deadline: _due ?? now,
      plannedStart: _planStart,
      priority: _priority,
      status: _status,
      progress: _progress.round(),
      createdAt: widget.task?.createdAt ?? now,
      updatedAt: now,
      images: List<String>.from(_imageDataUris),
    );

    ApiResponse<Task> res;
    if (widget.task == null) {
      res = await TaskService.createTask(
        task,
        ownerUserId: selectedAssigneeId.isNotEmpty ? selectedAssigneeId : null,
      );
    } else {
      res = await TaskService.updateTask(task);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(widget.task == null ? '任务创建成功并已分配' : '任务保存成功'),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _due = d;
        _dueManuallyAdjusted = true;
      });
    }
  }

  // 显示图片来源选择对话框
  Future<void> _showImageSourceDialog() async {
    if (_saving) return;
    
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图片来源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    
    if (source == null) return;
    
    if (source == ImageSource.camera) {
      await _takePhoto();
    } else {
      await _pickImagesFromGallery();
    }
  }

  // 从相册选择图片
  Future<void> _pickImagesFromGallery() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    final List<String> newImages = [];
    for (final file in files) {
      final dataUri = await _xFileToDataUri(file);
      if (dataUri != null) {
        newImages.add(dataUri);
      }
    }
    if (newImages.isEmpty) return;
    setState(() {
      _imageDataUris.addAll(newImages);
    });
  }

  // 拍照上传（根据平台使用不同的方式）
  Future<void> _takePhoto() async {
    try {
      XFile? photo;
      
      if (Platform.isWindows) {
        // Windows 平台：先尝试使用 image_picker 的相机功能，如果失败再尝试 camera 包
        try {
          // 首先尝试使用 image_picker 的相机（在某些 Windows 配置下可能可用）
          photo = await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
          );
          
          if (photo != null) {
            // image_picker 成功，直接使用
          } else {
            // 用户取消了
            return;
          }
        } catch (imagePickerError) {
          // image_picker 失败，尝试使用 camera 包
          try {
            // 获取可用摄像头列表
            final cameras = await availableCameras();
            if (cameras.isEmpty) {
              throw Exception('未找到可用的摄像头');
            }
            
            // 优先使用前置摄像头（通常是第一个），如果没有前置则使用第一个
            CameraDescription? selectedCamera;
            for (final camera in cameras) {
              if (camera.lensDirection == CameraLensDirection.front) {
                selectedCamera = camera;
                break;
              }
            }
            selectedCamera ??= cameras.first;
            
            // 打开相机预览页面
            final capturedFile = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (context) => CameraPreviewPage(
                  camera: selectedCamera!,
                ),
              ),
            );
            
            if (capturedFile != null && capturedFile.isNotEmpty) {
              photo = XFile(capturedFile);
            } else {
              // 用户取消了拍照
              return;
            }
          } catch (cameraError) {
            // 两种方式都失败，回退到文件选择器
            if (mounted) {
              final useFilePicker = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('摄像头不可用'),
                  content: const Text('无法直接访问摄像头。是否从文件中选择图片？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('选择文件'),
                    ),
                  ],
                ),
              );
              
              if (useFilePicker == true) {
                // 使用文件选择器
                photo = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
              } else {
                return;
              }
            } else {
              return;
            }
          }
        }
      } else {
        // Android、iOS 等平台直接使用 image_picker 的相机
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
      }
      
      if (photo == null) return;
      
      final dataUri = await _xFileToDataUri(photo);
      if (dataUri != null) {
        setState(() {
          _imageDataUris.add(dataUri);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍照失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _xFileToDataUri(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final mimeType = _detectMimeType(file.path);
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }

  String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Uint8List _decodeImageData(String dataUri) {
    final parts = dataUri.split(',');
    final base64Part = parts.length > 1 ? parts[1] : parts[0];
    return base64Decode(base64Part);
  }

  void _removeImage(int index) {
    setState(() {
      _imageDataUris.removeAt(index);
    });
  }

  // 预览图片
  void _previewImage(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImagePreviewPage(
          images: _imageDataUris,
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

      final imageBytes = _decodeImageData(_imageDataUris[index]);
      final result = await ImageGallerySaverPlus.saveImage(
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
      final imageBytes = _decodeImageData(_imageDataUris[index]);
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

  String _formatAssigneeDisplay({String? id, String? name}) {
    final trimmedName = name?.trim() ?? '';
    // 只显示用户名，不显示ID
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    // 如果没有用户名，显示"未指定"
    return '未指定';
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

  Widget _buildImageAttachments() {
    final canEdit = widget.canEditAll && !widget.canEditProgressOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('任务图片', style: TextStyle(fontWeight: FontWeight.bold)),
            if (canEdit)
              TextButton.icon(
                onPressed: _saving ? null : _showImageSourceDialog,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('添加图片'),
              ),
          ],
        ),
        if (_imageDataUris.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(canEdit ? '暂无图片，点击“添加图片”上传。' : '暂无图片'),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (int i = 0; i < _imageDataUris.length; i++)
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _previewImage(i),
                      onLongPress: () => _showImageMenu(context, i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _decodeImageData(_imageDataUris[i]),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (canEdit)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (canEdit)
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Icon(Icons.add, size: 32, color: Colors.grey),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickPlanStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _planStart ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _planStart = d;
        if (!_dueManuallyAdjusted || _due == null || _due!.isBefore(d)) {
          _due = d.add(const Duration(days: 2));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.task == null ? '新建任务' : '编辑任务',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 如果只能编辑进度，隐藏其他字段
                if (!widget.canEditProgressOnly) ...[
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: '任务名称',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入任务名称' : null,
                    enabled: widget.canEditAll,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _desc,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '任务描述',
                      border: OutlineInputBorder(),
                      hintText: '可填写任务背景、目标等',
                    ),
                    enabled: widget.canEditAll,
                  ),
                  const SizedBox(height: 12),
                  _buildImageAttachments(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('优先级：'),
                      const SizedBox(width: 8),
                      DropdownButton<TaskPriority>(
                        value: _priority,
                        items: TaskPriority.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: widget.canEditAll
                            ? (v) => setState(
                                () => _priority = v ?? TaskPriority.low,
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('任务状态：'),
                      const SizedBox(width: 8),
                      DropdownButton<TaskStatus>(
                        value: _status,
                        items: TaskStatus.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: widget.canEditAll
                            ? (v) => setState(
                                () => _status = v ?? TaskStatus.not_started,
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _assignee,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: '负责人（搜索用户名/姓名）',
                      border: OutlineInputBorder(),
                    ),
                    onTap: widget.canEditAll
                        ? () async {
                            final Map<String, String>? picked =
                                await showDialog<Map<String, String>>(
                                  context: context,
                                  builder: (context) =>
                                      const UserPickerDialog(),
                                );
                            if (picked != null) {
                              setState(() {
                                _assigneeId = picked['id'];
                                _assigneeName = picked['name'];
                                _assignee.text = _formatAssigneeDisplay(
                                  id: _assigneeId,
                                  name: _assigneeName,
                                );
                              });
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('计划开始时间'),
                    subtitle: Text(
                      _planStart == null
                          ? '未选择'
                          : '${_planStart!.year}-${_planStart!.month.toString().padLeft(2, '0')}-${_planStart!.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.event),
                    onTap: widget.canEditAll ? _pickPlanStart : null,
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('计划截止时间'),
                    subtitle: Text(
                      _due == null
                          ? '未选择'
                          : '${_due!.year}-${_due!.month.toString().padLeft(2, '0')}-${_due!.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.event),
                    onTap: widget.canEditAll ? _pickDue : null,
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.task != null) ...[
                  const Text(
                    '任务进度',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _progress,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${_progress.round()}%',
                    onChanged: (value) {
                      setState(() {
                        _progress = value;
                        // 当进度为100%时，自动设置状态为"已完成"
                        if (_progress.round() == 100) {
                          _status = TaskStatus.completed;
                        }
                      });
                    },
                  ),
                  Text('当前进度: ${_progress.round()}%'),
                  const SizedBox(height: 12),
                ],
                if (widget.task == null) ...[
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.campaign),
                    label: Text(_saving ? '创建中...' : '创建并分配任务'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ] else ...[
                  // 编辑任务时，根据权限显示不同按钮
                  if (widget.canEditProgressOnly) ...[
                    // 只能编辑进度时，显示保存按钮（统一使用保存方法）
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ] else ...[
                    // 可以编辑所有字段时，只显示保存按钮（包含进度更新）
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存修改'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Windows 相机预览页面
class CameraPreviewPage extends StatefulWidget {
  final CameraDescription camera;

  const CameraPreviewPage({
    super.key,
    required this.camera,
  });

  @override
  State<CameraPreviewPage> createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends State<CameraPreviewPage> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(
        widget.camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化摄像头失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _takePicture() async {
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile image = await _controller!.takePicture();
      
      if (mounted) {
        // 返回拍摄的照片路径
        Navigator.of(context).pop(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍照失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: _isInitialized && _controller != null && _controller!.value.isInitialized
          ? Stack(
              children: [
                // 相机预览
                Positioned.fill(
                  child: CameraPreview(_controller!),
                ),
                // 拍照按钮
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isCapturing ? null : _takePicture,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.grey, width: 4),
                        ),
                        child: _isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(strokeWidth: 3),
                              )
                            : const Icon(Icons.camera_alt, size: 35, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
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
