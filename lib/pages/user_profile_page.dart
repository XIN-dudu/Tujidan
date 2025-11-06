import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/user_service.dart';
import '../auth_service.dart';
import '../login_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final UserService _userService = UserService();
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, dynamic>? _userInfo;
  List<dynamic> _roles = [];
  List<dynamic> _permissions = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

      final userInfo = results[0] as Map<String, dynamic>?;
      final permissionsData = results[1] as Map<String, dynamic>?;

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
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的信息'),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserInfoCard(),
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
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == '未设置' ? Colors.grey : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
