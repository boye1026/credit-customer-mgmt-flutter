import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/business_service.dart';
import 'customer_list_screen.dart';
import 'add_customer_screen.dart';
import 'dashboard_screen.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok == true) {
      await BusinessService.logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeader = widget.user.isLeader;
    final pages = [
      CustomerListScreen(user: widget.user),
      AddCustomerScreen(user: widget.user),
      if (isLeader) DashboardScreen(user: widget.user),
    ];
    final items = [
      const BottomNavigationBarItem(icon: Icon(Icons.people), label: '我的客户'),
      const BottomNavigationBarItem(icon: Icon(Icons.person_add), label: '新增'),
      if (isLeader) const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '看板'),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a2a6c),
        foregroundColor: Colors.white,
        title: const Text('信贷客户管理'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '${widget.user.name} · ${isLeader ? '团队长' : '客户经理'}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout();
              if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Text('安全设置')),
              const PopupMenuItem(value: 'logout', child: Text('退出登录')),
            ],
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        selectedItemColor: const Color(0xFF409eff),
        unselectedItemColor: const Color(0xFF909399),
        type: BottomNavigationBarType.fixed,
        items: items,
      ),
    );
  }
}
