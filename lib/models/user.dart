
/// User คือโมเดลแทนผู้ใช้งานระบบหลัก (บัญชีผู้ใช้งาน)
/// เก็บข้อมูลโปรไฟล์ขั้นพื้นฐาน เช่น ชื่อล็อกอิน อีเมล ชื่อนามสกุล บทบาทหน้าที่ (Role) และวันลงทะเบียน
class User {
  final int id;
  final String username;
  final String? password;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? phone;
  final bool isActive;
  final String? birthDate;
  final String role;
  final DateTime? createdAt;
  final String? avatarUrl;

  User({
    required this.id,
    required this.username,
    this.password,
    this.email,
    this.firstName,
    this.lastName,
    this.fullName,
    this.phone,
    this.isActive = true,
    this.birthDate,
    this.role = 'user',
    this.createdAt,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      username: json['username'] ?? '',
      password: json['password'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      fullName: json['full_name'],
      phone: json['phone'],
      isActive: json['is_active'] ?? true,
      birthDate: json['birth_date']?.toString(),
      role: json['role'] ?? 'user',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'phone': phone,
      'is_active': isActive,
      'birth_date': birthDate,
      'role': role,
      'avatar_url': avatarUrl,
    };
  }

  static Future<bool> login(String username, String password) async {

    throw UnimplementedError('Use SupabaseService.login() instead');
  }

  static Future<void> register() async {
    throw UnimplementedError('Use SupabaseService.register() instead');
  }

  Future<void> getProfile() async {
    throw UnimplementedError('Use SupabaseService.getProfile() instead');
  }

  Future<void> updateProfile() async {
    throw UnimplementedError('Use SupabaseService.updateProfile() instead');
  }

  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    if (firstName != null || lastName != null) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return username;
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    String? email,
    String? firstName,
    String? lastName,
    String? fullName,
    String? phone,
    bool? isActive,
    String? birthDate,
    String? role,
    DateTime? createdAt,
    String? avatarUrl,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      birthDate: birthDate ?? this.birthDate,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
