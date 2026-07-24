import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import 'db_service.dart';

class BusinessService {
  static const Map<String, String> users = {
    '张伟': 'leader',
    '李娜': 'member',
    '王强': 'member',
    '赵敏': 'member',
    '刘洋': 'member',
    '陈静': 'member',
    '杨帆': 'member',
  };
  static const int dailyTarget = 3;

  static String get todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());
  static String get nowStr => DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  static String calcNextDue(String firstContactDateStr, {DateTime? baseDate}) {
    final fcd = DateTime.tryParse(firstContactDateStr);
    if (fcd == null) return todayStr;
    final base = baseDate ?? DateTime.now();
    final diff = DateTime(base.year, base.month, base.day)
        .difference(DateTime(fcd.year, fcd.month, fcd.day))
        .inDays;
    int delta;
    if (diff <= 30) delta = 7;
    else if (diff <= 60) delta = 14;
    else if (diff <= 90) delta = 30;
    else delta = 90;
    final result = base.add(Duration(days: delta));
    return DateFormat('yyyy-MM-dd').format(result);
  }

  static Future<String?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    return '${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
  }

  static Future<String> addCustomer({
    required String currentUser,
    required String name,
    required String phone,
    required String source,
    String basicInfo = '',
    String gpsLocation = '',
    String intention = '是',
    String noIntentionReason = '',
    String introducer = '',
  }) async {
    if (name.trim().isEmpty) throw '客户姓名不能为空';
    if (phone.trim().isEmpty) throw '电话不能为空';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) throw '请输入正确的11位手机号';
    if (!['陌拜', '电话', '转介绍'].contains(source)) throw '来源必须为 陌拜/电话/转介绍';
    if (source == '陌拜' && gpsLocation.isEmpty) throw '陌拜来源必须记录 GPS 定位';
    if (source == '转介绍' && introducer.isEmpty) throw '转介绍来源必须填写介绍人';

    final exist = await DbService.countByPhone(phone);
    if (exist > 0) throw '电话 $phone 已存在，拒绝重复新增';

    final today = todayStr;
    final now = nowStr;
    final nextDue = calcNextDue(today);

    await DbService.insertCustomer(Customer(
      owner: currentUser,
      name: name.trim(),
      phone: phone.trim(),
      source: source,
      basicInfo: basicInfo,
      gpsLocation: gpsLocation,
      intention: intention,
      noIntentionReason: noIntentionReason,
      introducer: introducer,
      firstContactDate: today,
      lastContactDate: today,
      nextDueDate: nextDue,
      createdAt: now,
      contactTime: now,
    ));
    return '新增成功：$name（$phone），来源=$source';
  }

  static Future<String> visitCustomer({
    required String currentUser,
    required String phone,
    String note = '',
  }) async {
    final row = await DbService.getCustomerByPhone(phone);
    if (row == null) throw '未找到电话 $phone 对应的客户';
    if (!_canOperate(currentUser, row.owner)) throw '无权操作：该客户属于 ${row.owner}';
    if (row.isStock) throw '该客户已放款（存量），无需回访';

    final today = todayStr;
    final now = nowStr;
    final newNextDue = calcNextDue(row.firstContactDate, baseDate: DateTime.now());
    String newBasic = row.basicInfo;
    if (note.isNotEmpty) {
      newBasic = newBasic.isEmpty ? '[$today] $note' : '$newBasic\n[$today] $note';
    }

    final updated = row.copyWith(
      lastContactDate: today,
      nextDueDate: newNextDue,
      contactTime: now,
      basicInfo: newBasic,
    );

    await DbService.updateCustomer(updated);
    return '回访成功：${row.name}（$phone）\n联系时间：$now\n下次应联系：$newNextDue';
  }

  static Future<String> loanCustomer({
    required String currentUser,
    required String phone,
  }) async {
    final row = await DbService.getCustomerByPhone(phone);
    if (row == null) throw '未找到电话 $phone 对应的客户';
    if (!_canOperate(currentUser, row.owner)) throw '无权操作：该客户属于 ${row.owner}';
    if (row.isStock) throw '该客户已放款，无需重复操作';

    final updated = row.copyWith(loanStatus: '已放款', source: '存量');
    await DbService.updateCustomer(updated);
    return '放款落地：${row.name}（$phone），已迁移为存量';
  }

  static Future<List<Customer>> listCustomers({
    required String currentUser,
    String filter = '营销中',
  }) async {
    final isLeader = users[currentUser] == 'leader';
    return DbService.queryCustomers(
      owner: isLeader ? null : currentUser,
      filter: filter,
    );
  }

  static Future<Map<String, dynamic>> myStats(String currentUser) async {
    final today = todayStr;
    final rows = await DbService.queryCustomers(owner: currentUser);
    final total = rows.length;
    final marketing = rows.where((r) => r.source != '存量').length;
    final overdue = rows.where((r) => r.source != '存量' && r.isOverdue).length;
    final stock = rows.where((r) => r.source == '存量').length;
    final todayNewCount = rows.where((r) =>
        r.firstContactDate == today &&
        ['陌拜', '电话', '转介绍'].contains(r.source)).length;

    return {
      'today_new': todayNewCount,
      'target': dailyTarget,
      'total': total,
      'marketing': marketing,
      'overdue': overdue,
      'stock': stock,
    };
  }

  static Future<Map<String, dynamic>> dashboard(String currentUser) async {
    if (users[currentUser] != 'leader') throw '看板仅团队负责人可查看';
    final today = todayStr;
    final result = <Map<String, dynamic>>[];

    for (final entry in users.entries.where((e) => e.value == 'member')) {
      final uname = entry.key;
      final rows = await DbService.queryCustomers(owner: uname);
      final todayNew = rows.where((r) =>
          r.firstContactDate == today &&
          ['陌拜', '电话', '转介绍'].contains(r.source)).length;
      final marketing = rows.where((r) => r.source != '存量').toList();
      final totalMarketing = marketing.length;
      final overdueCount = marketing.where((c) => c.isOverdue).length;
      final compliance = totalMarketing > 0
          ? ((totalMarketing - overdueCount) / totalMarketing * 1000).round() / 10
          : 0.0;

      result.add({
        'name': uname,
        'today_new': todayNew,
        'target': dailyTarget,
        'achieved': todayNew >= dailyTarget,
        'overdue_count': overdueCount,
        'total_marketing': totalMarketing,
        'compliance': compliance,
      });
    }
    return {'data': result, 'target': dailyTarget};
  }

  static Future<String> initDemoData(String currentUser) async {
    final all = await DbService.allCustomers();
    if (all.isNotEmpty) throw '已有数据，如需重置请先清空';

    final demos = [
      {'owner': '李娜', 'name': '王芳', 'phone': '13800001001', 'source': '陌拜', 'basic_info': '个体经营，需资金周转', 'gps': '深圳市南山区科技园', 'intention': '是', 'daysAgo': 3},
      {'owner': '李娜', 'name': '陈强', 'phone': '13800001002', 'source': '电话', 'basic_info': '装修公司老板', 'gps': '', 'intention': '是', 'daysAgo': 1},
      {'owner': '李娜', 'name': '刘梅', 'phone': '13800001003', 'source': '转介绍', 'basic_info': '由王芳介绍', 'gps': '', 'intention': '是', 'introducer': '王芳', 'daysAgo': 0},
      {'owner': '王强', 'name': '赵刚', 'phone': '13800002001', 'source': '陌拜', 'basic_info': '餐饮店扩张', 'gps': '深圳市福田区华强北', 'intention': '是', 'daysAgo': 8},
      {'owner': '王强', 'name': '孙丽', 'phone': '13800002002', 'source': '电话', 'basic_info': '电商卖家', 'gps': '', 'intention': '否', 'noReason': '暂无需求', 'daysAgo': 15},
      {'owner': '赵敏', 'name': '周杰', 'phone': '13800003001', 'source': '陌拜', 'basic_info': '物流公司', 'gps': '深圳市罗湖区东门', 'intention': '是', 'daysAgo': 95},
      {'owner': '赵敏', 'name': '吴秀', 'phone': '13800003002', 'source': '转介绍', 'basic_info': '朋友推荐', 'gps': '', 'intention': '是', 'introducer': '周杰', 'daysAgo': 50},
      {'owner': '刘洋', 'name': '郑伟', 'phone': '13800004001', 'source': '电话', 'basic_info': '制造业', 'gps': '', 'intention': '是', 'daysAgo': 2},
      {'owner': '陈静', 'name': '冯霞', 'phone': '13800005001', 'source': '陌拜', 'basic_info': '美容院', 'gps': '深圳市宝安区', 'intention': '是', 'daysAgo': 35},
      {'owner': '杨帆', 'name': '许峰', 'phone': '13800006001', 'source': '电话', 'basic_info': '外贸公司', 'gps': '', 'intention': '是', 'daysAgo': 0},
    ];

    final now = nowStr;
    for (final d in demos) {
      final fcdDate = DateTime.now().subtract(Duration(days: d['daysAgo'] as int));
      final fcd = DateFormat('yyyy-MM-dd').format(fcdDate);
      final dueDate = fcdDate.add(const Duration(days: 7));
      final nextDue = DateFormat('yyyy-MM-dd').format(dueDate);
      await DbService.insertCustomer(Customer(
        owner: d['owner'] as String,
        name: d['name'] as String,
        phone: d['phone'] as String,
        source: d['source'] as String,
        basicInfo: d['basic_info'] as String,
        gpsLocation: d['gps'] as String? ?? '',
        intention: d['intention'] as String,
        noIntentionReason: d['noReason'] as String? ?? '',
        introducer: d['introducer'] as String? ?? '',
        firstContactDate: fcd,
        lastContactDate: fcd,
        nextDueDate: nextDue,
        createdAt: now,
        contactTime: now,
      ));
    }
    return '已生成 ${demos.length} 条演示数据';
  }

  static Future<String> resetData() async {
    await DbService.deleteAll();
    return '已清空所有客户数据';
  }

  static bool _canOperate(String currentUser, String owner) {
    return users[currentUser] == 'leader' || currentUser == owner;
  }
}
