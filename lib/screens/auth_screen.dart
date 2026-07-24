import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/business_service.dart';
import '../models/user.dart';
import 'home_screen.dart';

enum AuthMode { login, register, forgotPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.login;
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  String _department = '永年微贷二部';
  String _role = 'member';
  bool _submitting = false;
  int _codeCountdown = 0;
  String? _code;

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _showMsg('请输入正确的11位手机号');
      return;
    }
    try {
      _code = await BusinessService.sendVerificationCode(phone);
      _showMsg('验证码已发送：$_code');
      setState(() => _codeCountdown = 60);
      _startCountdown();
    } catch (e) {
      _showMsg(e.toString());
    }
  }

  void _startCountdown() {
    if (_codeCountdown > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        setState(() => _codeCountdown--);
        _startCountdown();
      });
    }
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _showMsg('请输入正确的11位手机号');
      return;
    }
    if (password.isEmpty) {
      _showMsg('密码不能为空');
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = await BusinessService.login(phone, password);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (e) {
      _showMsg(e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _register() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final name = _nameController.text.trim();

    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _showMsg('请输入正确的11位手机号');
      return;
    }
    if (password.length < 6) {
      _showMsg('密码至少需要6位');
      return;
    }
    if (password != confirm) {
      _showMsg('两次密码输入不一致');
      return;
    }
    if (name.isEmpty) {
      _showMsg('姓名不能为空');
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = await BusinessService.register(
        phone: phone,
        password: password,
        name: name,
        department: _department,
        role: _role,
      );
      await BusinessService.setCurrentUser(user);
      _showMsg('注册成功');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (e) {
      _showMsg(e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _passwordController.text;

    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _showMsg('请输入正确的11位手机号');
      return;
    }
    if (code.isEmpty) {
      _showMsg('请输入验证码');
      return;
    }
    if (!BusinessService.verifyCode(phone, code)) {
      _showMsg('验证码错误');
      return;
    }
    if (newPassword.length < 6) {
      _showMsg('密码至少需要6位');
      return;
    }

    setState(() => _submitting = true);
    try {
      await BusinessService.resetPassword(phone, newPassword);
      _showMsg('密码重置成功，请登录');
      setState(() {
        _mode = AuthMode.login;
        _passwordController.clear();
        _codeController.clear();
      });
    } catch (e) {
      _showMsg(e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _phoneController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _nameController.clear();
      _codeController.clear();
      _codeCountdown = 0;
    });
  }

  Widget _buildForm() {
    switch (_mode) {
      case AuthMode.login:
        return _loginForm();
      case AuthMode.register:
        return _registerForm();
      case AuthMode.forgotPassword:
        return _forgotPasswordForm();
    }
  }

  Widget _loginForm() {
    return Column(
      children: [
        _field('手机号', _phoneController, hint: '请输入手机号', keyboardType: TextInputType.phone),
        _field('密码', _passwordController, hint: '请输入密码', obscure: true),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => _switchMode(AuthMode.forgotPassword),
              child: const Text('忘记密码？'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _submitButton('登录', _login),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('还没有账号？'),
            TextButton(onPressed: () => _switchMode(AuthMode.register), child: const Text('立即注册')),
          ],
        ),
      ],
    );
  }

  Widget _registerForm() {
    return Column(
      children: [
        _field('手机号', _phoneController, hint: '请输入手机号', keyboardType: TextInputType.phone),
        _field('密码', _passwordController, hint: '请输入密码（至少6位）', obscure: true),
        _field('确认密码', _confirmPasswordController, hint: '请再次输入密码', obscure: true),
        _field('姓名', _nameController, hint: '请输入姓名'),
        const SizedBox(height: 16),
        _picker('部门', _department, ['永年微贷二部'], (s) => s),
        const SizedBox(height: 16),
        _picker('身份', _role, ['member', 'leader'], (s) => s == 'leader' ? '团队长' : '客户经理'),
        const SizedBox(height: 20),
        _submitButton('注册', _register),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('已有账号？'),
            TextButton(onPressed: () => _switchMode(AuthMode.login), child: const Text('立即登录')),
          ],
        ),
      ],
    );
  }

  Widget _forgotPasswordForm() {
    return Column(
      children: [
        _field('手机号', _phoneController, hint: '请输入手机号', keyboardType: TextInputType.phone),
        Row(
          children: [
            Expanded(child: _field('验证码', _codeController, hint: '请输入验证码')),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              height: 50,
              child: ElevatedButton(
                onPressed: _codeCountdown > 0 ? null : _sendCode,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFecf5ff), foregroundColor: const Color(0xFF409eff)),
                child: Text(_codeCountdown > 0 ? '$_codeCountdowns' : '获取验证码'),
              ),
            ),
          ],
        ),
        _field('新密码', _passwordController, hint: '请输入新密码（至少6位）', obscure: true),
        const SizedBox(height: 20),
        _submitButton('重置密码', _resetPassword),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('记住密码了？'),
            TextButton(onPressed: () => _switchMode(AuthMode.login), child: const Text('立即登录')),
          ],
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, {String? hint, TextInputType keyboardType = TextInputType.text, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _picker(String label, String value, List<String> options, String Function(String) labelFn) {
    return InkWell(
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((o) => ListTile(
                title: Text(labelFn(o)),
                trailing: value == o ? const Icon(Icons.check, color: Color(0xFF409eff)) : null,
                onTap: () => Navigator.pop(ctx, o),
              )).toList(),
            ),
          ),
        );
        if (selected != null) setState(() => value = selected);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(labelFn(value)),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _submitButton(String text, Future<void> Function() onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _submitting ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a2a6c)),
        child: _submitting ? const CircularProgressIndicator(color: Colors.white) : Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a2a6c),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.account_balance, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text('信贷客户管理', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_mode == AuthMode.login ? '请登录您的账号' : (_mode == AuthMode.register ? '注册新账号' : '找回密码'), style: const TextStyle(fontSize: 16, color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(24),
                child: _buildForm(),
              ),
              const SizedBox(height: 24),
              Center(
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:400-000-0000')),
                  child: const Text('客服热线：400-000-0000', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
