import 'package:flutter/material.dart';
import '../services/business_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a2a6c),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.account_balance, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                '信贷团队客户管理',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '请选择你的身份进入系统',
                style: TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Expanded(
                child: ListView.builder(
                  itemCount: BusinessService.users.length,
                  itemBuilder: (context, index) {
                    final name = BusinessService.users.keys.elementAt(index);
                    final role = BusinessService.users[name]!;
                    final isLeader = role == 'leader';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isLeader ? const Color(0xFFFFD700) : const Color(0xFF409eff),
                          child: Icon(isLeader ? Icons.star : Icons.person, color: isLeader ? Colors.black87 : Colors.white),
                        ),
                        title: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        subtitle: Text(isLeader ? '团队负责人' : '客户经理'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => HomeScreen(currentUser: name)),
                          );
                        },
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
}
