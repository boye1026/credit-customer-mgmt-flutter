import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer.dart';
import '../models/user.dart';
import '../services/business_service.dart';

class CustomerListScreen extends StatefulWidget {
  final User user;
  const CustomerListScreen({super.key, required this.user});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final List<String> filters = ['营销中', '陌拜', '电话', '转介绍', '存量', 'all'];
  String currentFilter = '营销中';
  List<Customer> customers = [];
  Map<String, dynamic>? stats;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await BusinessService.listCustomers(
        currentUser: widget.user.phone,
        filter: currentFilter,
      );
      Map<String, dynamic>? s;
      if (!widget.user.isLeader) {
        s = await BusinessService.myStats(widget.user.phone);
      }
      setState(() {
        customers = data;
        stats = s;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      _showMsg(e.toString());
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _call(String phone) {
    launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _visit(Customer c) async {
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('回访记录 ${c.name}'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(hintText: '输入回访备注（可选）'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await BusinessService.visitCustomer(
        currentUser: widget.user.phone,
        phone: c.phone,
        note: noteController.text,
      );
      _showMsg(msg);
      _load();
    } catch (e) {
      _showMsg(e.toString());
    }
  }

  Future<void> _loan(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('放款落地 ${c.name}'),
        content: const Text('确认该客户已放款？将迁移为存量。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await BusinessService.loanCustomer(
        currentUser: widget.user.phone,
        phone: c.phone,
      );
      _showMsg(msg);
      _load();
    } catch (e) {
      _showMsg(e.toString());
    }
  }

  Future<void> _batchImport() async {
    final inputController = TextEditingController();
    bool hasPasted = false;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setInnerState) => AlertDialog(
          title: const Text('批量导入客户'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('请粘贴数据（每行一条，格式：姓名,电话,来源,备注）', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                const Text('示例：\n张三,13800001001,陌拜,个体经营\n李四,13800001002,电话,装修公司', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  controller: inputController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: '在此粘贴或输入数据...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          inputController.text = data!.text!;
                          setInnerState(() => hasPasted = true);
                        }
                      },
                      child: const Text('从剪贴板粘贴'),
                    ),
                    TextButton(
                      onPressed: () {
                        inputController.text = '张三,13800001001,存量,已放款客户\n李四,13800001002,存量,已放款客户\n王五,13800001003,存量,已放款客户';
                      },
                      child: const Text('填入示例'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('开始导入')),
          ],
        ),
      ),
    );
    
    if (ok != true) return;
    
    final lines = inputController.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      _showMsg('没有数据需要导入');
      return;
    }
    
    setState(() => loading = true);
    int success = 0;
    int failed = 0;
    final failedMsgs = <String>[];
    
    for (final line in lines) {
      final parts = line.split(',');
      if (parts.length < 2) {
        failed++;
        failedMsgs.add('格式错误: $line');
        continue;
      }
      final name = parts[0].trim();
      final phone = parts[1].trim();
      final source = parts.length > 2 ? parts[2].trim() : '存量';
      final basicInfo = parts.length > 3 ? parts.sublist(3).join(',').trim() : '';
      
      try {
        await BusinessService.addCustomer(
          currentUser: widget.user.phone,
          name: name,
          phone: phone,
          source: source,
          basicInfo: basicInfo,
        );
        success++;
      } catch (e) {
        failed++;
        failedMsgs.add('$name($phone): $e');
      }
    }
    
    setState(() => loading = false);
    _showMsg('导入完成：成功 $success 条，失败 $failed 条');
    if (failedMsgs.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('失败详情'),
          content: SingleChildScrollView(
            child: Text(failedMsgs.join('\n'), style: const TextStyle(fontSize: 13, color: Colors.red)),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
        ),
      );
    }
    _load();
  }

  Widget _buildStats() {
    if (stats == null) return const SizedBox.shrink();
    final s = stats!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          _statCard('${s['today_new']}/${s['target']}', '今日新增', s['today_new'] >= s['target'] ? Colors.green : Colors.orange),
          _statCard('${s['marketing']}', '营销中', Colors.blue),
          _statCard('${s['overdue']}', '逾期', s['overdue'] > 0 ? Colors.orange : Colors.green),
          _statCard('${s['stock']}', '已放款', Colors.purple),
        ],
      ),
    );
  }

  Widget _statCard(String num, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.85), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(num, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source) {
      case '陌拜': return const Color(0xFF409eff);
      case '电话': return const Color(0xFF67c23a);
      case '转介绍': return const Color(0xFFe6a23c);
      case '存量': return const Color(0xFF909399);
      default: return const Color(0xFF909399);
    }
  }

  Color _statusColor(Customer c) {
    if (c.isStock) return const Color(0xFF67c23a);
    if (c.isOverdue) return const Color(0xFFf56c6c);
    return const Color(0xFFe6a23c);
  }

  String _statusText(Customer c) {
    if (c.isStock) return '已放款';
    if (c.isOverdue) return '逾期';
    return '跟进中';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                _buildStats(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _batchImport,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('批量导入'),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF409eff)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    itemBuilder: (ctx, i) {
                      final f = filters[i];
                      final label = f == 'all' ? '全部' : f;
                      final active = currentFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: active,
                          selectedColor: const Color(0xFF409eff),
                          labelStyle: TextStyle(color: active ? Colors.white : const Color(0xFF606266)),
                          onSelected: (_) {
                            setState(() => currentFilter = f);
                            _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              if (loading) const Center(child: CircularProgressIndicator())
              else if (customers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('暂无客户数据', style: TextStyle(color: Colors.grey))),
                )
              else
                ...customers.map((c) => _buildCard(c)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Customer c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: c.isOverdue ? const Color(0xFFFFF5F5) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _tag(c.source, _sourceColor(c.source)),
                const SizedBox(width: 6),
                _tag(_statusText(c), _statusColor(c)),
              ],
            ),
            const SizedBox(height: 10),
            _row('电话', c.phone),
            _row('归属', c.owner),
            _row('最近联系', c.contactTime),
            _row('下次应联系', c.nextDueDate, highlight: c.isOverdue),
            if (c.gpsLocation.isNotEmpty) _row('定位', c.gpsLocation),
            if (c.introducer.isNotEmpty) _row('介绍人', c.introducer),
            if (c.basicInfo.isNotEmpty) _row('备注', c.basicInfo),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _call(c.phone),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('拨打电话'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF67c23a), foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _visit(c),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFecf5ff), foregroundColor: const Color(0xFF409eff)),
                    child: const Text('回访记录'),
                  ),
                ),
                if (!c.isStock) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _loan(c),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFF5F5), foregroundColor: const Color(0xFFf56c6c)),
                      child: const Text('放款'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF909399)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: highlight ? const Color(0xFFf56c6c) : const Color(0xFF303133), fontWeight: highlight ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}
