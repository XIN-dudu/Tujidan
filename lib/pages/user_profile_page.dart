import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../config/server_config.dart';
import '../services/user_service.dart';
import '../services/mbti_service.dart';
import '../auth_service.dart';
import '../login_page.dart';
import '../widgets/page_transitions.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final UserService _userService = UserService();
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, dynamic>? _userInfo;
  // ignore: unused_field
  List<dynamic> _roles = [];
  // ignore: unused_field
  List<dynamic> _permissions = [];
  bool _isLoading = true;
  bool _isUploading = false;
  
  // 职业规划相关状态
  Map<String, dynamic>? _mbtiAnalysis;
  bool _isLoadingMBTI = false;
  String _fileBaseUrl = 'http://127.0.0.1:3001';
  List<Map<String, dynamic>> _mbtiHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadServerAddress();
    _loadUserData();
    _loadMBTIAnalysis();
  }

  Future<void> _loadServerAddress() async {
    final baseUrl = await ServerConfig.getFileBaseUrl();
    if (!mounted) return;
    setState(() {
      _fileBaseUrl = baseUrl;
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // 并行获取用户信息和权限信息
      final results = await Future.wait([
        _userService.getCurrentUser(),
        _userService.getUserPermissions(),
      ]);

      final userInfo = results[0];
      final permissionsData = results[1];

      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _roles = permissionsData?['roles'] ?? [];
          _permissions = permissionsData?['permissions'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户信息失败: $e')),
        );
      }
    }
  }

  Future<void> _loadMBTIAnalysis({bool force = false}) async {
    if (!mounted) return;
    setState(() => _isLoadingMBTI = true);
    
    try {
      final suggestions = await MBTIService.getMBTIAnalysis(force: force);
      if (mounted) {
        setState(() {
          _mbtiAnalysis = suggestions;
          _isLoadingMBTI = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMBTI = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取职业规划失败: $e')),
        );
      }
    }
  }

  Future<void> _showDevelopmentSuggestions() async {
    if (_mbtiAnalysis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先获取职业规划')),
      );
      return;
    }

    // 显示发展建议对话框
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => _buildSuggestionsDialog(_mbtiAnalysis!),
      );
    }
  }

  Widget _buildSuggestionsDialog(Map<String, dynamic> suggestions) {
    final suggestionsList = suggestions['suggestions'] as List<dynamic>? ?? [];
    final summary = suggestions['summary'] as String? ?? '';
    final whySuitable = suggestions['whySuitable'] as String? ?? '';

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '职业发展规划',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (whySuitable.isNotEmpty) ...[
                      const Text(
                        '为什么这些建议适合你：',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        whySuitable,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (suggestionsList.isNotEmpty) ...[
                      const Text(
                        '具体建议：',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...suggestionsList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final suggestion = entry.value as String;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        '总结：',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authService = AuthService();
      await authService.logout();
      // 清除头像缓存
      UserService.clearAvatarCache();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          FadePageRoute(page: const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Stack(
          children: [
            // 背景模糊层
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
            ),
            // AppBar内容层
            AppBar(
                title: const Text('我的信息', style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadUserData,
                  tooltip: '刷新',
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _logout,
                  tooltip: '退出登录',
                ),
              ],
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              displacement: MediaQuery.of(context).padding.top + kToolbarHeight,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                  16,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserInfoCard(),
                    const SizedBox(height: 24),
                    _buildMBTICard(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout),
        label: const Text('退出登录'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[50],
          foregroundColor: Colors.red[700],
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;
      setState(() => _isUploading = true);

      final success = await _userService.uploadAvatar(File(image.path));
      
      if (!mounted) return;
      setState(() => _isUploading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像更新成功')),
        );
        await _loadUserData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像更新失败')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  Widget _buildUserInfoCard() {
    if (_userInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('无法获取用户信息'),
        ),
      );
    }

    final avatarUrl = _userInfo!['avatar_url'] as String?;
    
    // 优先使用缓存的头像图片
    ImageProvider? avatarImage = UserService.getCachedAvatarImage(avatarUrl);
    
    // 如果没有缓存，则解码（这种情况应该很少发生，因为 getCurrentUser 已经缓存了）
    if (avatarImage == null && avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        // 检查是否是 data URI（支持 data:image 和 data:application/octet-stream）
        if (avatarUrl.startsWith('data:')) {
          // data URI 格式：data:[<mediatype>][;base64],<data>
          final parts = avatarUrl.split(',');
          if (parts.length >= 2) {
            final base64String = parts[1];
            final imageBytes = base64Decode(base64String);
            avatarImage = MemoryImage(imageBytes);
            // 缓存解码后的图片（备用情况，正常情况下 getCurrentUser 已经缓存了）
            UserService.updateAvatarCache(avatarUrl, avatarImage);
          }
        } else if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
          // 网络图片
          avatarImage = NetworkImage(avatarUrl);
        } else if (avatarUrl.startsWith('/')) {
          // 相对路径，转换为完整 URL
          avatarImage = NetworkImage('$_fileBaseUrl$avatarUrl');
        }
      } catch (e) {
        print('解析头像失败: $e');
        avatarImage = null;
      }
    }

    final username = (_userInfo!['username'] ?? '').toString();
    final phone = (_userInfo!['phone'] ?? '').toString();
    final email = (_userInfo!['email'] ?? '').toString();
    final departmentIdRaw = _userInfo!['department_id']?.toString();
    final departmentText = (departmentIdRaw != null && departmentIdRaw.isNotEmpty)
        ? departmentIdRaw
        : '未设置';
    final mbti = (_userInfo!['mbti'] ?? '').toString();
    final mbtiText = mbti.isNotEmpty ? mbti : '未设置';
    final createdAtRaw = _userInfo!['created_at'];
    DateTime? createdAt;
    if (createdAtRaw != null) {
      try {
        createdAt = DateTime.parse(createdAtRaw.toString());
      } catch (_) {}
    }
    final createdAtText = createdAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
        : '未设置';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 头像显示
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: avatarImage,
                  // 只有当 backgroundImage 不为 null 时才设置 onBackgroundImageError
                  onBackgroundImageError: avatarImage != null
                      ? (exception, stackTrace) {
                          print('头像加载失败: $exception');
                        }
                      : null,
                  child: avatarImage == null
                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: _isUploading ? null : _pickAndUploadAvatar,
                      tooltip: '更新头像',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 用户名和ID
            _buildInfoRow('用户名', username.isNotEmpty ? username : '未设置'),
            const SizedBox(height: 8),
            _buildInfoRow('手机号', phone.isNotEmpty ? phone : '未设置'),
            const SizedBox(height: 8),
            _buildInfoRow('邮箱', email.isNotEmpty ? email : '未设置'),
            const SizedBox(height: 8),
            _buildInfoRow('所属部门', departmentText),
            const SizedBox(height: 8),
            _buildInfoRow('MBTI', mbtiText),
            const SizedBox(height: 8),
            _buildInfoRow('建号时间', createdAtText),
            const SizedBox(height: 24),
            // 修改信息按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showEditProfileDialog,
                icon: const Icon(Icons.edit),
                label: const Text('修改信息'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: value == '未设置' ? Colors.grey : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMBTICard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '职业规划',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_isLoadingMBTI)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _loadMBTIAnalysis(force: true),
                    tooltip: '刷新规划',
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingMBTI)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_mbtiAnalysis == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        '暂无规划数据',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _loadMBTIAnalysis(force: true),
                        child: const Text('生成职业规划'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // 显示发展建议摘要
              if (_mbtiAnalysis!['summary'] != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _mbtiAnalysis!['summary'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // 查看完整建议按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showDevelopmentSuggestions,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('查看完整规划建议'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[50],
                    foregroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 查看历史记录按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showHistoryDialog,
                  icon: const Icon(Icons.history),
                  label: const Text('查看历史记录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showHistoryDialog() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    
    try {
      final history = await MBTIService.getMBTIHistory(limit: 20);
      if (!mounted) return;
      setState(() {
        _mbtiHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载历史记录失败: $e')),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MBTI分析历史记录',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoadingHistory)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_mbtiHistory.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('暂无历史记录'),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _mbtiHistory.length,
                    itemBuilder: (context, index) {
                      final item = _mbtiHistory[index];
                      final createdAt = item['createdAt'] != null
                          ? DateTime.tryParse(item['createdAt'].toString())
                          : null;
                      final dateStr = createdAt != null
                          ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
                          : '未知时间';
                      final mbtiType = item['mbtiType']?.toString() ?? '未知';
                      final keywordsSummary = item['keywordsSummary']?.toString() ?? '';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(
                              mbtiType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            dateStr,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (keywordsSummary.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '关键词: $keywordsSummary',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 20),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showHistoryDetailDialog(item);
                                },
                                tooltip: '查看详情',
                              ),
                              if (index > 0)
                                IconButton(
                                  icon: const Icon(Icons.compare_arrows, size: 20),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showComparisonDialog(_mbtiHistory[index - 1], item);
                                  },
                                  tooltip: '与上一条对比',
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDetailDialog(Map<String, dynamic> historyItem) {
    final analysisData = historyItem['analysisData'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (context) => _buildSuggestionsDialog(analysisData),
    );
  }

  void _showComparisonDialog(Map<String, dynamic> item1, Map<String, dynamic> item2) {
    final analysis1 = item1['analysisData'] as Map<String, dynamic>? ?? {};
    final analysis2 = item2['analysisData'] as Map<String, dynamic>? ?? {};
    
    final date1 = item1['createdAt'] != null
        ? DateTime.tryParse(item1['createdAt'].toString())
        : null;
    final date2 = item2['createdAt'] != null
        ? DateTime.tryParse(item2['createdAt'].toString())
        : null;
    
    final dateStr1 = date1 != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(date1)
        : '未知时间';
    final dateStr2 = date2 != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(date2)
        : '未知时间';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '历史记录对比',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dateStr1,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildAnalysisContent(analysis1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dateStr2,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildAnalysisContent(analysis2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisContent(Map<String, dynamic> analysis) {
    final suggestionsList = analysis['suggestions'] as List<dynamic>? ?? [];
    final summary = analysis['summary'] as String? ?? '';
    final whySuitable = analysis['whySuitable'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (whySuitable.isNotEmpty) ...[
          const Text(
            '为什么适合：',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            whySuitable,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
        ],
        if (suggestionsList.isNotEmpty) ...[
          const Text(
            '具体建议：',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...suggestionsList.asMap().entries.map((entry) {
            final index = entry.key;
            final suggestion = entry.value as String;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            '总结：',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ],
      ],
    );
  }

  Future<void> _showEditProfileDialog() async {
    if (_userInfo == null) return;

    // 创建文本控制器，使用当前值初始化
    final usernameController = TextEditingController(
      text: (_userInfo!['username'] ?? '').toString(),
    );
    final phoneController = TextEditingController(
      text: (_userInfo!['phone'] ?? '').toString(),
    );
    final emailController = TextEditingController(
      text: (_userInfo!['email'] ?? '').toString(),
    );
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    // MBTI选项列表
    const List<String> mbtiOptions = [
      'INTJ', 'INTP', 'ENTJ', 'ENTP',
      'INFJ', 'INFP', 'ENFJ', 'ENFP',
      'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
      'ISTP', 'ISFP', 'ESTP', 'ESFP',
    ];
    
    // 初始化MBTI值
    final initialMbti = (_userInfo!['mbti'] ?? '').toString();
    final initialMbtiValue = initialMbti.isNotEmpty ? initialMbti : null;

    // 用于控制密码输入框的显示
    bool showPasswordFields = false;
    bool isSubmitting = false;
    String? errorMessage;
    String? selectedMbti = initialMbtiValue;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            // 验证用户名
            if (usernameController.text.trim().isEmpty) {
              setDialogState(() {
                errorMessage = '用户名不能为空';
              });
              return;
            }

            // 如果显示了密码字段，验证密码
            if (showPasswordFields) {
              if (passwordController.text.isEmpty) {
                setDialogState(() {
                  errorMessage = '请输入新密码';
                });
                return;
              }
              if (passwordController.text.length < 6) {
                setDialogState(() {
                  errorMessage = '密码至少6位';
                });
                return;
              }
              if (passwordController.text != confirmPasswordController.text) {
                setDialogState(() {
                  errorMessage = '两次输入的密码不一致';
                });
                return;
              }
            }

            setDialogState(() {
              isSubmitting = true;
              errorMessage = null;
            });

            // 调用更新接口
            final response = await _userService.updateUserProfile(
              username: usernameController.text.trim(),
              phone: phoneController.text.trim().isEmpty 
                  ? null 
                  : phoneController.text.trim(),
              email: emailController.text.trim().isEmpty 
                  ? null 
                  : emailController.text.trim(),
              password: showPasswordFields && passwordController.text.isNotEmpty
                  ? passwordController.text
                  : null,
              mbti: selectedMbti,
            );

            if (!mounted) return;

            if (response.success) {
              // 更新成功，关闭对话框并刷新数据
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(response.message)),
              );
              await _loadUserData();
            } else {
              // 更新失败，显示错误信息
              setDialogState(() {
                isSubmitting = false;
                errorMessage = response.message;
              });
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, color: Colors.blue),
                SizedBox(width: 8),
                Text('修改个人信息'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ID显示（不可编辑）
                    TextField(
                      controller: TextEditingController(
                        text: 'ID: ${_userInfo!['id']}',
                      ),
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: '用户ID',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.lock, size: 16),
                      ),
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 用户名
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名 *',
                        border: OutlineInputBorder(),
                        hintText: '请输入用户名',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    // 手机号
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: '手机号',
                        border: OutlineInputBorder(),
                        hintText: '请输入手机号（可选）',
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    // 邮箱
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        border: OutlineInputBorder(),
                        hintText: '请输入邮箱（可选）',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    // MBTI选择
                    DropdownButtonFormField<String>(
                      value: selectedMbti,
                      decoration: const InputDecoration(
                        labelText: 'MBTI',
                        border: OutlineInputBorder(),
                        hintText: '请选择MBTI类型（可选）',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('未设置'),
                        ),
                        ...mbtiOptions.map((mbti) => DropdownMenuItem<String>(
                          value: mbti,
                          child: Text(mbti),
                        )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedMbti = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // 修改密码开关
                    Row(
                      children: [
                        Checkbox(
                          value: showPasswordFields,
                          onChanged: (value) {
                            setDialogState(() {
                              showPasswordFields = value ?? false;
                              if (!showPasswordFields) {
                                passwordController.clear();
                                confirmPasswordController.clear();
                              }
                            });
                          },
                        ),
                        const Text('修改密码'),
                      ],
                    ),
                    // 密码输入框（条件显示）
                    if (showPasswordFields) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: '新密码 *',
                          border: OutlineInputBorder(),
                          hintText: '至少6位',
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: '确认新密码 *',
                          border: OutlineInputBorder(),
                          hintText: '请再次输入新密码',
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                      ),
                    ],
                    // 错误信息显示
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    // 清理控制器
    usernameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
  }

}
