import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/business_service.dart';

class AddCustomerScreen extends StatefulWidget {
  final User user;
  const AddCustomerScreen({super.key, required this.user});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _form = {
    'name': '',
    'phone': '',
    'source': '陌拜',
    'basic_info': '',
    'gps_location': '',
    'introducer': '',
  };
  final List<String> sourceOptions = ['陌拜', '电话', '转介绍', '存量'];
  bool submitting = false;

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _getLocation() async {
    final loc = await BusinessService.getCurrentLocation();
    if (loc == null) {
      _showMsg('定位失败，请检查定位权限');
      return;
    }
    setState(() => _form['gps_location'] = loc);
    _showMsg('定位成功');
  }

  Future<void> _submit() async {
    setState(() => submitting = true);
    try {
      final msg = await BusinessService.addCustomer(
        currentUser: widget.user.phone,
        name: _form['name']!,
        phone: _form['phone']!,
        source: _form['source']!,
        basicInfo: _form['basic_info']!,
        gpsLocation: _form['gps_location']!,
        introducer: _form['introducer']!,
      );
      _showMsg(msg);
      _clearForm();
    } catch (e) {
      _showMsg(e.toString());
    } finally {
      setState(() => submitting = false);
    }
  }

  void _clearForm() {
    setState(() {
      _form['name'] = '';
      _form['phone'] = '';
      _form['source'] = '陌拜';
      _form['basic_info'] = '';
      _form['gps_location'] = '';
      _form['introducer'] = '';
    });
  }

  Widget _field(String label, String key, {String? hint, TextInputType type = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF606266))),
          const SizedBox(height: 8),
          TextField(
            keyboardType: type,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            controller: TextEditingController(text: _form[key]),
            onChanged: (v) => _form[key] = v,
          ),
        ],
      ),
    );
  }

  Widget _picker<T>(String label, String key, List<T> options, String Function(T) labelFn) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF606266))),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final selected = await showModalBottomSheet<T>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: options.map((o) => ListTile(
                      title: Text(labelFn(o)),
                      trailing: _form[key] == o.toString() ? const Icon(Icons.check, color: Color(0xFF409eff)) : null,
                      onTap: () => Navigator.pop(ctx, o),
                    )).toList(),
                  ),
                ),
              );
              if (selected != null) {
                setState(() => _form[key] = selected.toString());
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(labelFn(options.firstWhere((o) => o.toString() == _form[key])), style: const TextStyle(fontSize: 16)),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('录入新客户', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _field('客户姓名 *', 'name', hint: '如：张三'),
          _field('手机号 *', 'phone', hint: '11位手机号', type: TextInputType.phone),
          _picker('来源 *', 'source', sourceOptions, (s) => s as String),
          if (_form['source'] == '陌拜')
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GPS定位 *', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF606266))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '点击右侧定位或手动输入',
                            filled: true,
                            fillColor: const Color(0xFFF5F7FA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          controller: TextEditingController(text: _form['gps_location']),
                          onChanged: (v) => _form['gps_location'] = v,
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: _getLocation,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: const Color(0xFFecf5ff), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.location_on, color: Color(0xFF409eff)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_form['source'] == '转介绍')
            _field('介绍人 *', 'introducer', hint: '介绍人姓名'),
          _field('基本信息', 'basic_info', hint: '行业、资产、资金用途等', maxLines: 3),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
            child: const Text(
              '系统将自动设置：放款状态=未放款、首次联系日=今天、下次应联系日=+7天',
              style: TextStyle(fontSize: 13, color: Color(0xFF909399)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF67c23a),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(submitting ? '提交中...' : '提交录入', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearForm,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('清空', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
