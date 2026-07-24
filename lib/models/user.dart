class User {
  final int? id;
  final String phone;
  final String password;
  final String department;
  final String role;
  final String name;
  final String createdAt;

  User({
    this.id,
    required this.phone,
    required this.password,
    required this.department,
    required this.role,
    required this.name,
    required this.createdAt,
  });

  bool get isLeader => role == 'leader';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone': phone,
      'password': password,
      'department': department,
      'role': role,
      'name': name,
      'created_at': createdAt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      phone: map['phone'] as String,
      password: map['password'] as String,
      department: map['department'] as String? ?? '',
      role: map['role'] as String? ?? 'member',
      name: map['name'] as String? ?? '',
      createdAt: map['created_at'] as String,
    );
  }
}
