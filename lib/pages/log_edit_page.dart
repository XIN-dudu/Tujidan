import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/log_entry.dart';
import '../models/task.dart';
import '../models/api_response.dart';
import '../services/log_service.dart';
import '../services/task_service.dart';
import '../services/location_service.dart';
import '../widgets/task_selector.dart';
import '../widgets/priority_selector.dart';

class LogEditPage extends StatefulWidget {
  final LogEntry? logEntry; // 如果为null则是新建，否则是编辑
  final String? initialTaskId; // 初始任务ID
  final TaskPriority? initialPriority; // 初始优先级

  const LogEditPage({
    super.key,
    this.logEntry,
    this.initialTaskId,
    this.initialPriority,
  });

  @override
  State<LogEditPage> createState() => _LogEditPageState();
}

class _LogEditPageState extends State<LogEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Task? _selectedTask;
  TaskPriority _selectedPriority = TaskPriority.low;
  DateTime _selectedTime = DateTime.now();
  DateTime? _startTime = DateTime.now();
  DateTime? _endTime;
  bool _isLoading = false;
  bool _isSaving = false;
  String _logStatus = 'in_progress'; // 日志状态：in_progress, completed
  String? _selectedType; // work/study/life/other
  final List<String> _types = const ['work', 'study', 'life', 'other'];
  List<String> _imageDataUris = [];
  Map<String, dynamic>? _selectedLocation; // 存储选择的地理位置
  final LocationService _locationService = LocationService();
  bool _isLoadingLocation = false;
  bool _endTimeManuallySet = false; // 标记结束时间是否被手动设置过

  @override
  void initState() {
    super.initState();
    if (widget.logEntry != null) {
      _initializeFromExistingLog();
    } else {
      // 如果是新建日志，使用初始值
      if (widget.initialTaskId != null) {
        _loadTaskDetails(widget.initialTaskId!);
      }
      if (widget.initialPriority != null) {
        _selectedPriority = widget.initialPriority!;
      }
      // 新建日志时，设置默认结束时间为开始时间的后三天
      if (_startTime != null) {
        _endTime = _startTime!.add(const Duration(days: 3));
        _endTimeManuallySet = false; // 新建时默认值，未手动设置
      }
    }
  }

  void _initializeFromExistingLog() {
    final log = widget.logEntry!;
    _titleController.text = log.title;
    _contentController.text = log.content;
    _selectedType = log.type;
    _selectedPriority = log.priority;
    _selectedTime = log.time;
    _startTime = log.startTime ?? log.time;
    _endTime = log.endTime;
    // 如果编辑已有日志且结束时间存在，标记为手动设置
    _endTimeManuallySet = log.endTime != null;
    // 兼容旧数据：将 pending 或 cancelled 映射为 in_progress
    _logStatus = (log.logStatus == 'pending' || log.logStatus == 'cancelled') 
        ? 'in_progress' 
        : log.logStatus;
    _imageDataUris = List<String>.from(log.images);
    
    // 加载地理位置信息
    if (log.location != null) {
      _selectedLocation = {
        'latitude': log.location!.latitude,
        'longitude': log.location!.longitude,
        'address': log.location!.address,
      };
    }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载任务信息失败: $e')));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 获取当前地理位置
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final location = await _locationService.getCurrentLocation();
      
      if (location != null) {
        setState(() {
          _selectedLocation = location;
          _isLoadingLocation = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已获取位置: ${location['address']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isLoadingLocation = false);
        
        if (mounted) {
          // 显示权限提示对话框
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('无法获取位置'),
              content: const Text('请检查是否已授予位置权限，并确保已开启位置服务。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('打开设置'),
                ),
              ],
            ),
          );
          
          if (shouldOpenSettings == true) {
            await _locationService.openAppSettings();
          }
        }
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取位置失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final logEntry = LogEntry(
        id:
            widget.logEntry?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        type: _selectedType,
        taskId: _selectedTask?.id,
        priority: _selectedPriority,
        time: _selectedTime,
        createdAt: widget.logEntry?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        startTime: _startTime,
        endTime: _endTime,
        logStatus: _logStatus,
        images: List<String>.from(_imageDataUris),
        location: _selectedLocation != null
            ? LogLocation(
                latitude: _selectedLocation!['latitude'],
                longitude: _selectedLocation!['longitude'],
                address: _selectedLocation!['address'],
              )
            : null,
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
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
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
            SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickImages() async {
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

  Future<String?> _xFileToDataUri(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final mimeType = _detectMimeType(file.path);
      final encoded = base64Encode(bytes);
      return 'data:$mimeType;base64,$encoded';
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
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: 'log_image_${DateTime.now().millisecondsSinceEpoch}',
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
        text: '分享日志图片',
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

  Widget _buildImageAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('图片附件', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _isSaving ? null : _pickImages,
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
            child: const Text('暂无图片，点击“添加图片”上传。'),
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
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.logEntry == null ? '写日志' : '编辑日志',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 创建人信息（仅在编辑模式下显示）
                      if (widget.logEntry != null && (widget.logEntry!.authorRealName != null || widget.logEntry!.authorUsername != null))
                        Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text(
                                  '创建人：',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                                Text(
                                  widget.logEntry!.authorRealName?.isNotEmpty == true
                                      ? widget.logEntry!.authorRealName!
                                      : widget.logEntry!.authorUsername ?? '未知',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (widget.logEntry != null && (widget.logEntry!.authorRealName != null || widget.logEntry!.authorUsername != null))
                        const SizedBox(height: 16),
                      // 日志标题
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '日志标题',
                          hintText: '请输入标题',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 1,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '标题不能为空';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

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
                      _buildImageAttachments(),
                      const SizedBox(height: 16),

                      // 日志类型
                      Row(
                        children: [
                          const Text('日志类型：'),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _selectedType,
                            hint: const Text('选择类型'),
                            items: _types
                                .map(
                                  (t) => DropdownMenuItem<String>(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedType = v),
                          ),
                        ],
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

                      // 开始时间
                      ListTile(
                        title: const Text('开始时间'),
                        subtitle: Text(
                          _startTime == null
                              ? '未选择'
                              : '${_startTime!.year}-${_startTime!.month.toString().padLeft(2, '0')}-${_startTime!.day.toString().padLeft(2, '0')} ${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: const Icon(Icons.schedule),
                        onTap: () async {
                          final navigator = context;
                          final date = await showDatePicker(
                            context: navigator,
                            initialDate: _startTime ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) {
                            if (!mounted) return;
                            final time = await showTimePicker(
                              context: navigator,
                              initialTime: TimeOfDay.fromDateTime(
                                _startTime ?? DateTime.now(),
                              ),
                            );
                            if (time != null) {
                              setState(() {
                                final newStartTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                                _startTime = newStartTime;
                                
                                // 如果结束时间未手动设置，或者结束时间早于新的开始时间，自动更新为开始时间的后三天
                                if (!_endTimeManuallySet || 
                                    (_endTime != null && _endTime!.isBefore(newStartTime))) {
                                  _endTime = newStartTime.add(const Duration(days: 3));
                                  _endTimeManuallySet = false; // 自动更新的，不算手动设置
                                }
                              });
                            }
                          }
                        },
                      ),
                      // 结束时间
                      ListTile(
                        title: const Text('结束时间'),
                        subtitle: Text(
                          _endTime == null
                              ? '未选择'
                              : '${_endTime!.year}-${_endTime!.month.toString().padLeft(2, '0')}-${_endTime!.day.toString().padLeft(2, '0')} ${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: const Icon(Icons.event),
                        onTap: () async {
                          final navigator = context;
                          final date = await showDatePicker(
                            context: navigator,
                            initialDate:
                                _endTime ?? (_startTime ?? DateTime.now()),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) {
                            if (!mounted) return;
                            final time = await showTimePicker(
                              context: navigator,
                              initialTime: TimeOfDay.fromDateTime(
                                _endTime ?? (_startTime ?? DateTime.now()),
                              ),
                            );
                            if (time != null) {
                              setState(() {
                                _endTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                                _endTimeManuallySet = true; // 标记为手动设置
                                if (_startTime != null &&
                                    _endTime!.isBefore(_startTime!)) {
                                  _startTime = _endTime;
                                }
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 地理位置选择
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '位置',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_isLoadingLocation)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    TextButton.icon(
                                      icon: const Icon(Icons.my_location, size: 18),
                                      label: const Text('获取当前位置'),
                                      onPressed: _getCurrentLocation,
                                    ),
                                ],
                              ),
                              if (_selectedLocation != null) ...[
                                const Divider(),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedLocation!['address'] ?? '未知地址',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${(_selectedLocation!['latitude'] as double).toStringAsFixed(6)}, '
                                              '${(_selectedLocation!['longitude'] as double).toStringAsFixed(6)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          setState(() => _selectedLocation = null);
                                        },
                                        tooltip: '清除位置',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 日志状态选择
                      Row(
                        children: [
                          const Text('日志状态：'),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _logStatus,
                            items: const [
                              DropdownMenuItem<String>(
                                value: 'in_progress',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.radio_button_unchecked,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text('进行中'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'completed',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text('已完成'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _logStatus = value;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 保存按钮
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveLog,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(widget.logEntry == null ? '创建日志' : '更新日志'),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 24,
                      ),
                    ],
                  ),
                ),
              ),
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
