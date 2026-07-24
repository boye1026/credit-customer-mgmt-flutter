import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatternService {
  static String _hash(String pattern) {
    return sha256.convert(utf8.encode(pattern)).toString();
  }

  static Future<bool> isSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pattern_hash') != null;
  }

  static Future<void> setPattern(String pattern) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pattern_hash', _hash(pattern));
  }

  static Future<void> clearPattern() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pattern_hash');
  }

  static Future<bool> verifyPattern(String pattern) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('pattern_hash');
    if (stored == null) return false;
    return _hash(pattern) == stored;
  }
}
