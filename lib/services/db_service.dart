import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/customer.dart';
import '../models/user.dart';

class DbService {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'credit_customers.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL UNIQUE,
            source TEXT NOT NULL,
            basic_info TEXT,
            gps_location TEXT,
            intention TEXT,
            no_intention_reason TEXT,
            introducer TEXT,
            loan_status TEXT,
            first_contact_date TEXT,
            last_contact_date TEXT,
            next_due_date TEXT,
            created_at TEXT,
            contact_time TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            department TEXT NOT NULL,
            role TEXT NOT NULL,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 1) {
          await db.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              phone TEXT NOT NULL UNIQUE,
              password TEXT NOT NULL,
              department TEXT NOT NULL,
              role TEXT NOT NULL,
              name TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  static Future<int> insertCustomer(Customer c) async {
    final db = await database;
    return db.insert('customers', c.toMap());
  }

  static Future<List<Customer>> queryCustomers({
    String? owner,
    String? filter,
    bool excludeStock = false,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    final List<String> conditions = [];
    final List<dynamic> args = [];

    if (owner != null) {
      conditions.add('owner = ?');
      args.add(owner);
    }

    if (filter != null && filter != 'all') {
      if (filter == '营销中') {
        conditions.add("source != '存量'");
      } else {
        conditions.add('source = ?');
        args.add(filter);
      }
    }

    if (excludeStock) {
      conditions.add("loan_status != '已放款'");
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      whereArgs = args;
    }

    final rows = await db.query(
      'customers',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'next_due_date ASC, created_at DESC',
      limit: 500,
    );
    return rows.map(Customer.fromMap).toList();
  }

  static Future<Customer?> getCustomerByPhone(String phone) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  static Future<int> countByPhone(String phone) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as c FROM customers WHERE phone = ?',
      [phone],
    );
    return (res.first['c'] as int?) ?? 0;
  }

  static Future<int> updateCustomer(Customer c) async {
    final db = await database;
    return db.update(
      'customers',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  static Future<int> deleteAll() async {
    final db = await database;
    return db.delete('customers');
  }

  static Future<int> count({String? owner, String? sourceFilter, bool stockOnly = false}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (owner != null) {
      conditions.add('owner = ?');
      args.add(owner);
    }
    if (sourceFilter != null) {
      if (sourceFilter == '营销中') {
        conditions.add("source != '存量'");
      } else {
        conditions.add('source = ?');
        args.add(sourceFilter);
      }
    }
    if (stockOnly) {
      conditions.add("loan_status = '已放款'");
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM customers $where', args);
    return (res.first['c'] as int?) ?? 0;
  }

  static Future<List<Customer>> allCustomers() async {
    final db = await database;
    final rows = await db.query('customers');
    return rows.map(Customer.fromMap).toList();
  }

  static Future<int> insertUser(User u) async {
    final db = await database;
    return db.insert('users', u.toMap());
  }

  static Future<User?> getUserByPhone(String phone) async {
    final db = await database;
    final rows = await db.query('users', where: 'phone = ?', whereArgs: [phone], limit: 1);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  static Future<int> updateUserPassword(String phone, String newPassword) async {
    final db = await database;
    return db.update('users', {'password': newPassword}, where: 'phone = ?', whereArgs: [phone]);
  }

  static Future<List<User>> getAllUsers() async {
    final db = await database;
    final rows = await db.query('users');
    return rows.map(User.fromMap).toList();
  }
}
