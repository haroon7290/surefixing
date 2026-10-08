class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String kycStatus;
  final double rating;
  final int ratingCount;
  final int jobsCompleted;
  final int jobsAssigned;
  final double avgResponseMinutes;
  final List<String> skills;
  final String bio;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.kycStatus = 'none',
    this.rating = 0,
    this.ratingCount = 0,
    this.jobsCompleted = 0,
    this.jobsAssigned = 0,
    this.avgResponseMinutes = 60,
    this.skills = const [],
    this.bio = '',
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        role: json['role'] ?? 'client',
        kycStatus: json['kycStatus'] ?? 'none',
        rating: (json['rating'] ?? 0).toDouble(),
        ratingCount: json['ratingCount'] ?? 0,
        jobsCompleted: json['jobsCompleted'] ?? 0,
        jobsAssigned: json['jobsAssigned'] ?? 0,
        avgResponseMinutes: (json['avgResponseMinutes'] ?? 60).toDouble(),
        skills: List<String>.from(json['skills'] ?? const []),
        bio: json['bio'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'kycStatus': kycStatus,
        'rating': rating,
        'ratingCount': ratingCount,
        'jobsCompleted': jobsCompleted,
        'jobsAssigned': jobsAssigned,
        'avgResponseMinutes': avgResponseMinutes,
        'skills': skills,
        'bio': bio,
      };
}
