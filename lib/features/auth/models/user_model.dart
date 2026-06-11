// lib/features/auth/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? photoUrl;
  final String? apiKey;
  final bool isVerified;
  final bool biometricEnabled;
  final DateTime createdAt;
  final DateTime? lastSeen;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.photoUrl,
    this.apiKey,
    this.isVerified = false,
    this.biometricEnabled = false,
    required this.createdAt,
    this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? json['displayName'] ?? '',
      phone: json['phone'] ?? json['phoneNumber'],
      photoUrl: json['photoUrl'] ?? json['photo_url'] ?? json['photoURL'],
      apiKey: json['api_key'],
      isVerified: json['is_verified'] ?? json['emailVerified'] ?? false,
      biometricEnabled: json['biometric_enabled'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'phone': phone,
    'photo_url': photoUrl,
    'api_key': apiKey,
    'is_verified': isVerified,
    'biometric_enabled': biometricEnabled,
    'created_at': createdAt.toIso8601String(),
    'last_seen': lastSeen?.toIso8601String(),
  };

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? photoUrl,
    String? apiKey,
    bool? isVerified,
    bool? biometricEnabled,
    DateTime? createdAt,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      apiKey: apiKey ?? this.apiKey,
      isVerified: isVerified ?? this.isVerified,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) => other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserModel(id: $id, email: $email, name: $name)';
}