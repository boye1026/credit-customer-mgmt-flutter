import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../services/pattern_service.dart';
import '../widgets/pattern_lock.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _patternSet = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final bioAvail = await BiometricService.isAvailable();
    final bioEnabled = await BiometricService.isEnabled();
    final patSet = await PatternService.isSet();
    setState(() {
      _biometricAvailable = bioAvail;
      _biometricEnabled = bioEnabled;
      _patternSet = patSet;
      _loading = false;
    });
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !_biometricAvailable) {
      _showMsg('设备不支持指纹/生物识别');
      return;
    }
    if (value) {
      final ok = await BiometricService.authenticate(reason: '请验证指纹以开启指纹登录');
      if (!ok) {
        _showMsg('指纹验证失败，无法开启');
        return;
      }
    }
    await BiometricService.setEnabled(value);
    setState(() => _biometricEnabled = value);
    _showMsg(value ? '已开启指纹登录' : '已关闭指纹登录');
  }

  void _setPattern() {
    String? firstPattern;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatternLock(
          title: '设置图案',
          subtitle: '请绘制新的解锁图案（至少4个点）',
          onPatternComplete: (pattern) async {
            if (firstPattern == null) {
              firstPattern = pattern;
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PatternLock(
                    title: '确认图案',
                    subtitle: '请再次绘制相同图案',
                    onPatternComplete: (pattern2) async {
                      if (pattern == pattern2) {
                        await PatternService.setPattern(pattern);
                        if (mounted) {
                          Navigator.of(context).pop();
                          _showMsg('图案锁设置成功');
                          _loadStatus();
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('两次图案不一致，请重新设置')),
                          );
                          Navigator.of(context).pop();
                        }
                      }
                    },
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _clearPattern() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除图案锁'),
        content: const Text('确定要清除已设置的图案锁吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok == true) {
      await PatternService.clearPattern();
      _loadStatus();
      _showMsg('图案锁已清除');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a2a6c),
        foregroundColor: Colors.white,
        title: const Text('安全设置'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const _SectionHeader('指纹登录'),
                SwitchListTile(
                  title: const Text('指纹/生物识别登录'),
                  subtitle: Text(
                    _biometricAvailable
                        ? (_biometricEnabled ? '已开启' : '已关闭')
                        : '设备不支持或未录入指纹',
                  ),
                  value: _biometricEnabled,
                  onChanged: _biometricAvailable ? _toggleBiometric : null,
                  activeColor: const Color(0xFF409eff),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '开启后，在登录界面可使用指纹快速登录（需先用密码登录一次）。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const Divider(),
                const _SectionHeader('图案锁'),
                ListTile(
                  leading: const Icon(Icons.pattern, color: Color(0xFF409eff)),
                  title: const Text('设置图案锁'),
                  subtitle: Text(_patternSet ? '已设置图案锁' : '未设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _setPattern,
                ),
                if (_patternSet)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('清除图案锁'),
                    onTap: _clearPattern,
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '设置图案锁后，在登录界面可使用图案快速登录（需先用密码登录一次）。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF909399),
        ),
      ),
    );
  }
}
