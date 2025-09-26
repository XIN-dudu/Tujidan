import 'package:flutter/material.dart';
import 'package:test_flutter/auth_service.dart';
import 'package:test_flutter/login_page.dart';
import 'package:test_flutter/pages/log_list_page.dart';
import 'package:test_flutter/pages/log_view_page.dart';

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
        primarySwatch: Colors.blue,
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
    const Center(child: Text('AI地图页面')),
    const Center(child: Text('我的页面')),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '导图',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_module),
            label: '视图',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: '日志',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'AI地图',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
      appBar: AppBar(
        title: const Text('潘多拉'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            tooltip: '退出登录',
          ),
        ],
      ),
    );
  }
}

class QuadrantPage extends StatelessWidget {
  const QuadrantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // 第一象限
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.star, size: 50, color: Colors.red),
                    ),
                  ),
                ),
                // 第二象限
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.favorite, size: 50, color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // 第三象限
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.shopping_cart, size: 50, color: Colors.green),
                    ),
                  ),
                ),
                // 第四象限
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.settings, size: 50, color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  @override
  void initState() {
    super.initState();
    _check();
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