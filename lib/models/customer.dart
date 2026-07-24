class Customer {
  final int? id;
  final String owner;
  final String name;
  final String phone;
  final String source;
  final String basicInfo;
  final String gpsLocation;
  final String intention;
  final String noIntentionReason;
  final String introducer;
  final String loanStatus;
  final String firstContactDate;
  String lastContactDate;
  String nextDueDate;
  final String createdAt;
  String contactTime;

  Customer({
    this.id,
    required this.owner,
    required this.name,
    required this.phone,
    required this.source,
    this.basicInfo = '',
    this.gpsLocation = '',
    this.intention = '是',
    this.noIntentionReason = '',
    this.introducer = '',
    this.loanStatus = '未放款',
    required this.firstContactDate,
    required this.lastContactDate,
    required this.nextDueDate,
    required this.createdAt,
    required this.contactTime,
  });

  bool get isStock => loanStatus == '已放款';
  bool get isOverdue {
    if (isStock) return false;
    final today = DateTime.now();
    final due = DateTime.parse(nextDueDate);
    return DateTime(today.year, today.month, today.day)
            .isAfter(DateTime(due.year, due.month, due.day));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner': owner,
      'name': name,
      'phone': phone,
      'source': source,
      'basic_info': basicInfo,
      'gps_location': gpsLocation,
      'intention': intention,
      'no_intention_reason': noIntentionReason,
      'introducer': introducer,
      'loan_status': loanStatus,
      'first_contact_date': firstContactDate,
      'last_contact_date': lastContactDate,
      'next_due_date': nextDueDate,
      'created_at': createdAt,
      'contact_time': contactTime,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      owner: map['owner'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      source: map['source'] as String,
      basicInfo: map['basic_info'] as String? ?? '',
      gpsLocation: map['gps_location'] as String? ?? '',
      intention: map['intention'] as String? ?? '是',
      noIntentionReason: map['no_intention_reason'] as String? ?? '',
      introducer: map['introducer'] as String? ?? '',
      loanStatus: map['loan_status'] as String? ?? '未放款',
      firstContactDate: map['first_contact_date'] as String,
      lastContactDate: map['last_contact_date'] as String,
      nextDueDate: map['next_due_date'] as String,
      createdAt: map['created_at'] as String,
      contactTime: map['contact_time'] as String,
    );
  }

  Customer copyWith({
    int? id,
    String? owner,
    String? name,
    String? phone,
    String? source,
    String? basicInfo,
    String? gpsLocation,
    String? intention,
    String? noIntentionReason,
    String? introducer,
    String? loanStatus,
    String? firstContactDate,
    String? lastContactDate,
    String? nextDueDate,
    String? createdAt,
    String? contactTime,
  }) {
    return Customer(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      source: source ?? this.source,
      basicInfo: basicInfo ?? this.basicInfo,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      intention: intention ?? this.intention,
      noIntentionReason: noIntentionReason ?? this.noIntentionReason,
      introducer: introducer ?? this.introducer,
      loanStatus: loanStatus ?? this.loanStatus,
      firstContactDate: firstContactDate ?? this.firstContactDate,
      lastContactDate: lastContactDate ?? this.lastContactDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      createdAt: createdAt ?? this.createdAt,
      contactTime: contactTime ?? this.contactTime,
    );
  }
}
