import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/business_service.dart';

class CustomerListScreen extends StatefulWidget {
  final String currentUser;
  const CustomerListScreen({super.key, required this.currentUser});

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
        currentUser: widget.currentUser,
        filter: currentFilter,
      );
      Map<String, dynamic>? s;
      if (BusinessService.users[widget.currentUser] != 'leader') {
        s = await BusinessService.myStats(widget.currentUser);
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

  Future<void> _visit(Customer c) async {
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('回访 ${c.name}'),
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
        currentUser: widget.currentUser,
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
        currentUser: widget.currentUser,
        phone: c.phone,
      );
      _showMsg(msg);
      _load();
    } catch (e) {
      _showMsg(e.toString());
    }
  }

  Future<void> _loadDemo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('生成演示数据'),
        content: const Text('将生成 10 条演示数据，继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('继续')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await BusinessService.initDemoData(widget.currentUser);
      _showMsg(msg);
      _load();
    } catch (e) {
      _showMsg(e.toString());
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空数据'),
        content: const Text('⚠️ 确认清空所有客户数据？此操作不可恢复！'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认清空')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await BusinessService.resetData();
      _showMsg(msg);
      _load();
    } catch (e) {
      _showMsg(e.toString());
    }
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
                  Expanded(child: OutlinedButton(onPressed: _loadDemo, child: const Text('生成演示数据'))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton(onPressed: _reset, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('清空数据'))),
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
                _tag(c.intention == '是' ? '有意向' : '无意向', c.intention == '是' ? const Color(0xFF67c23a) : const Color(0xFFf56c6c)),
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
            if (!c.isStock) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _visit(c),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFecf5ff), foregroundColor: const Color(0xFF409eff)),
                      child: const Text('回访'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _loan(c),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFF5F5), foregroundColor: const Color(0xFFf56c6c)),
                      child: const Text('放款'),
                    ),
                  ),
                ],
              ),
            ],
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
