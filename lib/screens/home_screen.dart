import 'package:flutter/material.dart';
import '../services/business_service.dart';
import 'customer_list_screen.dart';
import 'add_customer_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String currentUser;
  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isLeader = BusinessService.users[widget.currentUser] == 'leader';
    final pages = [
      CustomerListScreen(currentUser: widget.currentUser),
      AddCustomerScreen(currentUser: widget.currentUser),
      if (isLeader) DashboardScreen(currentUser: widget.currentUser),
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
                '${widget.currentUser} · ${isLeader ? '负责人' : '客户经理'}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'switch') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'switch', child: Text('切换身份')),
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
