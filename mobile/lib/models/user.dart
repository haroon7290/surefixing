double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

/// Full account/profile model (the signed-in user, admin user lists and
/// technician profiles all share it; private fields are just empty when
/// the server omits them).
class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String status;
  final String kycStatus;
  final String avatar;
  final String bio;
  final String city;
  final String headline;
  final List<String> skills;
  final double hourlyRate;
  final int experienceYears;
  final bool isAvailable;
  final double rating;
  final int ratingCount;
  final int jobsCompleted;
  final int jobsAssigned;
  final double avgResponseMinutes;
  final bool online;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.status = 'active',
    this.kycStatus = 'none',
    this.avatar = '',
    this.bio = '',
    this.city = '',
    this.headline = '',
    this.skills = const [],
    this.hourlyRate = 0,
    this.experienceYears = 0,
    this.isAvailable = true,
    this.rating = 0,
    this.ratingCount = 0,
    this.jobsCompleted = 0,
    this.jobsAssigned = 0,
    this.avgResponseMinutes = 60,
    this.online = false,
    this.lastSeenAt,
    this.createdAt,
  });

  bool get isVerified => kycStatus == 'approved';
  bool get isSuspended => status == 'suspended';
  bool get isTechnician => role == 'technician';
  bool get isClient => role == 'client';
  bool get isSupplier => role == 'supplier';
  bool get isAdmin => role == 'admin';
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  double get completionRate {
    if (jobsAssigned <= 0) return jobsCompleted > 0 ? 1 : 0;
    return (jobsCompleted / jobsAssigned).clamp(0, 1).toDouble();
  }

  /// Profile fields still empty, in the order worth fixing first.
  List<String> get missingProfileItems => [
        if (avatar.isEmpty) 'a photo',
        if (isTechnician && skills.isEmpty) 'your skills',
        if (headline.isEmpty) 'a headline',
        if (isTechnician && hourlyRate <= 0) 'your hourly rate',
        if (bio.isEmpty) 'a short bio',
        if (city.isEmpty) 'your city',
        if ((phone ?? '').isEmpty) 'a phone number',
      ];

  /// 0–1 share of the professional profile that's filled in.
  double get profileCompleteness {
    final checks = [
      avatar.isNotEmpty,
      headline.isNotEmpty,
      bio.isNotEmpty,
      city.isNotEmpty,
      (phone ?? '').isNotEmpty,
      if (isTechnician) skills.isNotEmpty,
      if (isTechnician) hourlyRate > 0,
    ];
    return checks.where((c) => c).length / checks.length;
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        phone: json['phone']?.toString(),
        role: (json['role'] ?? 'client').toString(),
        status: (json['status'] ?? 'active').toString(),
        kycStatus: (json['kycStatus'] ?? 'none').toString(),
        avatar: (json['avatar'] ?? '').toString(),
        bio: (json['bio'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        headline: (json['headline'] ?? '').toString(),
        skills: (json['skills'] as List? ?? const []).map((e) => e.toString()).toList(),
        hourlyRate: _d(json['hourlyRate']),
        experienceYears: _i(json['experienceYears']),
        isAvailable: json['isAvailable'] != false,
        rating: _d(json['rating']),
        ratingCount: _i(json['ratingCount']),
        jobsCompleted: _i(json['jobsCompleted']),
        jobsAssigned: _i(json['jobsAssigned']),
        avgResponseMinutes: _d(json['avgResponseMinutes'], 60),
        online: json['online'] == true,
        lastSeenAt: _date(json['lastSeenAt']),
        createdAt: _date(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
        'kycStatus': kycStatus,
        'avatar': avatar,
        'bio': bio,
        'city': city,
        'headline': headline,
        'skills': skills,
        'hourlyRate': hourlyRate,
        'experienceYears': experienceYears,
        'isAvailable': isAvailable,
        'rating': rating,
        'ratingCount': ratingCount,
        'jobsCompleted': jobsCompleted,
        'jobsAssigned': jobsAssigned,
        'avgResponseMinutes': avgResponseMinutes,
        'createdAt': createdAt?.toIso8601String(),
      };
}

/// Compact user reference as embedded in jobs, bids, rentals, chats.
/// Accepts either a populated object or a bare id string.
class UserLite {
  final String id;
  final String name;
  final String avatar;
  final double rating;
  final int ratingCount;
  final String city;
  final String kycStatus;
  final String? phone;
  final String? email;
  final String role;
  final bool online;

  const UserLite({
    required this.id,
    this.name = '',
    this.avatar = '',
    this.rating = 0,
    this.ratingCount = 0,
    this.city = '',
    this.kycStatus = 'none',
    this.phone,
    this.email,
    this.role = '',
    this.online = false,
  });

  bool get isVerified => kycStatus == 'approved';

  static UserLite? fromAny(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      return UserLite(
        id: (m['_id'] ?? m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        avatar: (m['avatar'] ?? '').toString(),
        rating: _d(m['rating']),
        ratingCount: _i(m['ratingCount']),
        city: (m['city'] ?? '').toString(),
        kycStatus: (m['kycStatus'] ?? 'none').toString(),
        phone: m['phone']?.toString(),
        email: m['email']?.toString(),
        role: (m['role'] ?? '').toString(),
        online: m['online'] == true,
      );
    }
    final id = v.toString();
    return id.isEmpty ? null : UserLite(id: id);
  }
}
