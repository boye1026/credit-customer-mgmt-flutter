import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/business_service.dart';

class DashboardScreen extends StatefulWidget {
  final User user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> data = [];
  int target = 3;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await BusinessService.dashboard(widget.user.phone);
      setState(() {
        data = (res['data'] as List).cast<Map<String, dynamic>>();
        target = res['target'] as int;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  int get totalNew => data.fold<int>(0, (s, x) => s + (x['today_new'] as int));
  int get totalOverdue => data.fold<int>(0, (s, x) => s + (x['overdue_count'] as int));
  double get avgCompliance => data.isEmpty ? 0 : data.fold<double>(0, (s, x) => s + (x['compliance'] as double)) / data.length;

  Widget _summaryCard(String num, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.85), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(num, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.white), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _progress(String label, double value, Color color) {
    final pct = value.clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF909399)))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 10,
                backgroundColor: const Color(0xFFebeef5),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: Text('${value.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, color: Color(0xFF606266)), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _summaryCard('$totalNew', '团队今日新增', Colors.blue),
                _summaryCard('$totalOverdue', '逾期待联系', totalOverdue > 0 ? Colors.orange : Colors.green),
                _summaryCard('${avgCompliance.toStringAsFixed(1)}%', '平均达标率', Colors.green),
                _summaryCard('$target', '每人日目标', Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            const Text('各经理业绩', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (loading) const Center(child: CircularProgressIndicator())
            else if (data.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey))))
            else
              ...data.map((m) => _memberCard(m)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> m) {
    final todayNew = m['today_new'] as int;
    final target = m['target'] as int;
    final compliance = m['compliance'] as double;
    final achieved = m['achieved'] as bool;
    final ratio = target == 0 ? 0.0 : todayNew / target;
    Color progressColor;
    if (todayNew >= target) progressColor = const Color(0xFF67c23a);
    else if (ratio > 0.5) progressColor = const Color(0xFFe6a23c);
    else progressColor = const Color(0xFFf56c6c);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(m['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: achieved ? const Color(0xFFf0f9eb) : const Color(0xFFfef0f0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(achieved ? '已达标' : '未达标', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: achieved ? const Color(0xFF67c23a) : const Color(0xFFf56c6c))),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _progress('今日新增', ratio * 100, progressColor),
            _progress('联系达标率', compliance, const Color(0xFF409eff)),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 90),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat('${m['total_marketing']}', '营销中'),
                      _miniStat('${m['overdue_count']}', '逾期数', isOverdue: (m['overdue_count'] as int) > 0),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String num, String label, {bool isOverdue = false}) {
    return Column(
      children: [
        Text(num, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isOverdue ? const Color(0xFFf56c6c) : const Color(0xFF303133))),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF909399))),
      ],
    );
  }
}
