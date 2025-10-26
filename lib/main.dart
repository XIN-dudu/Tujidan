import 'package:flutter/material.dart';
import 'package:test_flutter/auth_service.dart';
import 'package:test_flutter/login_page.dart';
import 'package:test_flutter/pages/log_list_page.dart';
import 'package:test_flutter/pages/log_view_page.dart';
import 'package:test_flutter/pages/user_profile_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '潘多拉',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF6F6FA),
      ),
      home: const _RootDecider(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    const QuadrantPage(),
    const LogViewPage(),
    const LogListPage(),
    const Center(child: Text('任务')),
    const UserProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '导图'),
          NavigationDestination(icon: Icon(Icons.view_module_outlined), selectedIcon: Icon(Icons.view_module), label: '视图'),
          NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: '日志'),
          NavigationDestination(icon: Icon(Icons.task_outlined), selectedIcon: Icon(Icons.task), label: '任务'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

class QuadrantPage extends StatelessWidget {
  const QuadrantPage({super.key});

  Future<void> _logout(BuildContext context) async {
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
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final authService = AuthService();
      await authService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _DashboardTile(icon: Icons.star, title: '收藏', start: Colors.pinkAccent, end: Colors.orangeAccent),
      _DashboardTile(icon: Icons.favorite, title: '关注', start: Colors.lightBlueAccent, end: Colors.indigoAccent),
      _DashboardTile(icon: Icons.shopping_cart, title: '待办', start: Colors.greenAccent, end: Colors.teal),
      _DashboardTile(icon: Icons.settings, title: '设置', start: Colors.amberAccent, end: Colors.deepOrangeAccent),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('潘多拉'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: '退出登录',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // 限制最大宽度和高度，保持四宫格比例
            constraints: const BoxConstraints(
              maxWidth: 600,  // 最大宽度
              maxHeight: 650, // 最大高度（稍大一点以适应间距）
            ),
            child: AspectRatio(
              // 保持接近正方形的比例
              aspectRatio: 1.0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(), // 禁止滚动
                  shrinkWrap: true, // 收缩包裹内容
                  itemCount: tiles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) => tiles[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color start;
  final Color end;

  const _DashboardTile({required this.icon, required this.title, required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {},
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [start.withOpacity(.8), end.withOpacity(.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(color: end.withOpacity(.25), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: end, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RootDecider extends StatefulWidget {
  const _RootDecider();

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  bool _loggedIn = false;

  /// 调试开关：true 表示直接跳过登录
  final bool skipLogin = false;

  @override
  void initState() {
    super.initState();
    if (!skipLogin) {
      _check();
    } else {
      _loading = false;
      _loggedIn = true;
    }
  }

  Future<void> _check() async {
    final bool ok = await _authService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _loggedIn = ok;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _loggedIn ? const HomePage() : const LoginPage();
  }
}
