import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  
  // MBTI相关状态
  Map<String, dynamic>? _mbtiAnalysis;
  bool _isLoadingMBTI = false;
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMBTIAnalysis();
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
      final analysis = await MBTIService.getMBTIAnalysis(force: force);
      if (mounted) {
        setState(() {
          _mbtiAnalysis = analysis;
          _isLoadingMBTI = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMBTI = false);
        // 静默失败，不显示错误提示（因为可能没有关键词数据）
      }
    }
  }

  Future<void> _showDevelopmentSuggestions() async {
    if (_mbtiAnalysis == null || _mbtiAnalysis!['mbti'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先获取MBTI分析')),
      );
      return;
    }

    final mbti = _mbtiAnalysis!['mbti'] as String;
    
    if (!mounted) return;
    setState(() => _isLoadingSuggestions = true);

    try {
      final suggestions = await MBTIService.getDevelopmentSuggestions(mbti: mbti);
      
      if (!mounted) return;
      setState(() => _isLoadingSuggestions = false);

      if (suggestions == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取发展建议失败')),
        );
        return;
      }

      // 显示发展建议对话框
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _buildSuggestionsDialog(suggestions),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSuggestions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取发展建议失败: $e')),
        );
      }
    }
  }

  Widget _buildSuggestionsDialog(Map<String, dynamic> suggestions) {
    final suggestionsList = suggestions['suggestions'] as List<dynamic>? ?? [];
    final summary = suggestions['summary'] as String? ?? '';

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
                  'AI发展建议',
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
                    if (summary.isNotEmpty) ...[
                      Text(
                        summary,
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
          avatarImage = NetworkImage('http://localhost:3001$avatarUrl');
        }
      } catch (e) {
        print('解析头像失败: $e');
        avatarImage = null;
      }
    }

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
            _buildInfoRow('用户名', _userInfo!['username'] ?? ''),
            const SizedBox(height: 8),
            _buildInfoRow('用户ID', _userInfo!['id']?.toString() ?? ''),
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
                    Icon(Icons.psychology, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '性格分析',
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
                    tooltip: '刷新分析',
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
                        '暂无分析数据',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _loadMBTIAnalysis(force: true),
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // MBTI类型
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Text(
                      _mbtiAnalysis!['mbti'] ?? '未知',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '可信度: ${_mbtiAnalysis!['confidence'] ?? '中'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 性格特征
              if (_mbtiAnalysis!['traits'] != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (_mbtiAnalysis!['traits'] as List<dynamic>)
                      .map((trait) => Chip(
                            label: Text(trait.toString()),
                            backgroundColor: Colors.blue[50],
                            side: BorderSide(color: Colors.blue[200]!),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 16),
              // 分析说明
              if (_mbtiAnalysis!['analysis'] != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _mbtiAnalysis!['analysis'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // 查看发展建议按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingSuggestions ? null : _showDevelopmentSuggestions,
                  icon: _isLoadingSuggestions
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lightbulb_outline),
                  label: Text(_isLoadingSuggestions ? '生成中...' : '查看发展建议'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[50],
                    foregroundColor: Colors.orange[700],
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

}
