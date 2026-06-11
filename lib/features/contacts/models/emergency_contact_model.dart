// lib/features/contacts/models/emergency_contact_model.dart

class EmergencyContact {
  final String id;
  final String uid;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;
  final bool isActive;
  final String? photoUrl;
  final String? fcmToken;
  final String? appUid;         // Firebase UID if contact is also a SafeHer user
  final bool isAppUser;         // true = registered on SafeHer
  final bool locationShared;    // they agreed to share location with us
  final DateTime createdAt;
  final DateTime? lastAlertSent;

  const EmergencyContact({
    required this.id, required this.uid, required this.name,
    required this.phone, required this.relation,
    this.isPrimary = false, this.isActive = true,
    this.photoUrl, this.fcmToken, this.appUid,
    this.isAppUser = false, this.locationShared = false,
    required this.createdAt, this.lastAlertSent,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    id: json['id'] ?? '',
    uid: json['uid'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    relation: json['relation'] ?? '',
    isPrimary: json['isPrimary'] ?? false,
    isActive: json['isActive'] ?? true,
    photoUrl: json['photoUrl'],
    fcmToken: json['fcmToken'],
    appUid: json['appUid'],
    isAppUser: json['isAppUser'] ?? false,
    locationShared: json['locationShared'] ?? false,
    createdAt: json['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
        : DateTime.now(),
    lastAlertSent: json['lastAlertSent'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['lastAlertSent'] as int)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'uid': uid, 'name': name, 'phone': phone,
    'relation': relation, 'isPrimary': isPrimary, 'isActive': isActive,
    'photoUrl': photoUrl, 'fcmToken': fcmToken, 'appUid': appUid,
    'isAppUser': isAppUser, 'locationShared': locationShared,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'lastAlertSent': lastAlertSent?.millisecondsSinceEpoch,
  };

  EmergencyContact copyWith({
    String? name, String? phone, String? relation,
    bool? isPrimary, bool? isActive, String? fcmToken,
    String? appUid, bool? isAppUser, bool? locationShared,
    DateTime? lastAlertSent,
  }) => EmergencyContact(
    id: id, uid: uid,
    name: name ?? this.name, phone: phone ?? this.phone,
    relation: relation ?? this.relation, isPrimary: isPrimary ?? this.isPrimary,
    isActive: isActive ?? this.isActive, photoUrl: photoUrl,
    fcmToken: fcmToken ?? this.fcmToken, appUid: appUid ?? this.appUid,
    isAppUser: isAppUser ?? this.isAppUser,
    locationShared: locationShared ?? this.locationShared,
    createdAt: createdAt, lastAlertSent: lastAlertSent ?? this.lastAlertSent,
  );
}