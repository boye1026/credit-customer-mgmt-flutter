import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/business_service.dart';
import '../services/biometric_service.dart';
import '../services/pattern_service.dart';
import '../models/user.dart';
import 'home_screen.dart';
import '../widgets/pattern_lock.dart';

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
  bool _biometricAvailable = false;
  bool _patternSet = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAndPattern();
  }

  Future<void> _checkBiometricAndPattern() async {
    final bioAvail = await BiometricService.isAvailable();
    final bioEnabled = await BiometricService.isEnabled();
    final patSet = await PatternService.isSet();
    setState(() {
      _biometricAvailable = bioAvail && bioEnabled;
      _patternSet = patSet;
    });
  }

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
      await BusinessService.sendVerificationCode(phone);
      _showMsg('验证码已通过短信发送，请查收');
      setState(() => _codeCountdown = 60);
      _startCountdown();
    } catch (e) {
      _showMsg(e.toString());
    }
  }

  void _startCountdown() {
    if (_codeCountdown > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _codeCountdown--);
          _startCountdown();
        }
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
      _navigateHome(user);
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
      _navigateHome(user);
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

  Future<void> _biometricLogin() async {
    final phone = await BusinessService.getSavedPhone();
    if (phone == null) {
      _showMsg('请先使用密码登录一次');
      return;
    }
    final success = await BiometricService.authenticate(reason: '请验证指纹以登录');
    if (success) {
      try {
        final user = await BusinessService.loginByPhone(phone);
        _navigateHome(user);
      } catch (e) {
        _showMsg(e.toString());
      }
    } else {
      _showMsg('指纹验证失败');
    }
  }

  void _patternLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatternLock(
          title: '图案登录',
          subtitle: '请绘制您的解锁图案',
          isVerifyMode: true,
          onPatternComplete: (pattern) async {
            final ok = await PatternService.verifyPattern(pattern);
            if (ok) {
              final phone = await BusinessService.getSavedPhone();
              if (phone != null) {
                final user = await BusinessService.loginByPhone(phone);
                if (mounted) {
                  Navigator.of(context).pop();
                  _navigateHome(user);
                }
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('图案错误')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _navigateHome(User user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
    );
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
        const SizedBox(height: 12),
        _submitButton('登录', _login),
        if (_biometricAvailable || _patternSet) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              if (_biometricAvailable)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _biometricLogin,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('指纹登录'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ),
              if (_biometricAvailable && _patternSet) const SizedBox(width: 12),
              if (_patternSet)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _patternLogin,
                    icon: const Icon(Icons.pattern),
                    label: const Text('图案登录'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('还没有账号？', style: TextStyle(color: Colors.white70)),
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
        _buildRoleSelector(),
        const SizedBox(height: 20),
        _submitButton('注册', _register),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('已有账号？', style: TextStyle(color: Colors.white70)),
            TextButton(onPressed: () => _switchMode(AuthMode.login), child: const Text('立即登录')),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('身份选择（注册后不可更改）', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _role = 'member'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _role == 'member' ? const Color(0xFF409eff) : Colors.transparent,
                    border: Border.all(color: _role == 'member' ? const Color(0xFF409eff) : Colors.white30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('客户经理', style: TextStyle(color: _role == 'member' ? Colors.white : Colors.white70, fontSize: 16)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _role = 'leader'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _role == 'leader' ? const Color(0xFFe6a23c) : Colors.transparent,
                    border: Border.all(color: _role == 'leader' ? const Color(0xFFe6a23c) : Colors.white30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('团队长', style: TextStyle(color: _role == 'leader' ? Colors.white : Colors.white70, fontSize: 16)),
                  ),
                ),
              ),
            ),
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
                child: Text(_codeCountdown > 0 ? '${_codeCountdown}s' : '获取验证码'),
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
            const Text('记住密码了？', style: TextStyle(color: Colors.white70)),
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
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white30)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white30)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF409eff))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF409eff)),
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
              const SizedBox(height: 50),
              const Icon(Icons.account_balance, size: 72, color: Colors.white),
              const SizedBox(height: 20),
              const Text('信贷客户管理', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _mode == AuthMode.login ? '请登录您的账号' : (_mode == AuthMode.register ? '注册新账号' : '找回密码'),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildForm(),
            ],
          ),
        ),
      ),
    );
  }
}
