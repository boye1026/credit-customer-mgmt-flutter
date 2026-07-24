import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/user.dart';
import 'db_service.dart';

class BusinessService {
  static const String defaultDepartment = '永年微贷二部';
  static const int dailyTarget = 3;

  static String get todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());
  static String get nowStr => DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  static User? _currentUser;

  static User? get currentUser => _currentUser;

  static Future<void> setCurrentUser(User? user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    if (user != null) {
      await prefs.setString('current_user', json.encode(user.toMap()));
    } else {
      await prefs.remove('current_user');
    }
  }

  static Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('current_user');
    if (jsonStr == null) return null;
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return User.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  static final Map<String, String> _smsCodes = {};
  static final Map<String, int> _codeTimestamps = {};

  static String _generateCode() {
    return Random().nextInt(900000) + 100000;
  }

  static Future<String> sendVerificationCode(String phone) async {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) throw '请输入正确的11位手机号';
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_codeTimestamps.containsKey(phone) && now - _codeTimestamps[phone]! < 60000) {
      throw '验证码发送过于频繁，请稍后再试';
    }

    final code = _generateCode().toString();
    _smsCodes[phone] = code;
    _codeTimestamps[phone] = now;
    
    return code;
  }

  static bool verifyCode(String phone, String code) {
    return _smsCodes[phone] == code;
  }

  static Future<User> register({
    required String phone,
    required String password,
    required String name,
    required String department,
    required String role,
  }) async {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) throw '请输入正确的11位手机号';
    if (password.length < 6) throw '密码至少需要6位';
    if (name.trim().isEmpty) throw '姓名不能为空';
    if (!['leader', 'member'].contains(role)) throw '身份选择错误';

    final exist = await DbService.getUserByPhone(phone);
    if (exist != null) throw '该手机号已注册';

    final user = User(
      phone: phone,
      password: password,
      department: department,
      role: role,
      name: name.trim(),
      createdAt: nowStr,
    );

    await DbService.insertUser(user);
    return user;
  }

  static Future<User> login(String phone, String password) async {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) throw '请输入正确的11位手机号';
    if (password.isEmpty) throw '密码不能为空';

    final user = await DbService.getUserByPhone(phone);
    if (user == null) throw '该手机号未注册';
    if (user.password != password) throw '密码错误';

    await setCurrentUser(user);
    return user;
  }

  static Future<void> resetPassword(String phone, String newPassword) async {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) throw '请输入正确的11位手机号';
    if (newPassword.length < 6) throw '密码至少需要6位';

    final user = await DbService.getUserByPhone(phone);
    if (user == null) throw '该手机号未注册';

    await DbService.updateUserPassword(phone, newPassword);
  }

  static Future<void> logout() async {
    await setCurrentUser(null);
    _currentUser = null;
  }

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
    String introducer = '',
  }) async {
    if (name.trim().isEmpty) throw '客户姓名不能为空';
    if (phone.trim().isEmpty) throw '电话不能为空';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) throw '请输入正确的11位手机号';
    if (!['陌拜', '电话', '转介绍', '存量'].contains(source)) throw '来源必须为 陌拜/电话/转介绍/存量';
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
    final user = await DbService.getUserByPhone(currentUser);
    final isLeader = user?.isLeader ?? false;
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
    final user = await DbService.getUserByPhone(currentUser);
    if (user == null || !user.isLeader) throw '看板仅团队负责人可查看';
    
    final today = todayStr;
    final allUsers = await DbService.getAllUsers();
    final members = allUsers.where((u) => u.role == 'member').toList();
    final result = <Map<String, dynamic>>[];

    for (final member in members) {
      final rows = await DbService.queryCustomers(owner: member.phone);
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
        'name': member.name,
        'phone': member.phone,
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

  static bool _canOperate(String currentUser, String owner) {
    return currentUser == owner;
  }

  static Future<bool> isLeader(String phone) async {
    final user = await DbService.getUserByPhone(phone);
    return user?.isLeader ?? false;
  }
}
