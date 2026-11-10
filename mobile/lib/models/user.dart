import 'json.dart';

/// An account: the signed-in user, a technician profile, a supplier, or the
/// small "who" attached to jobs, quotes and rentals. Fields the server did
/// not send (private ones, or a bare id reference) are simply empty.
class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final String kycStatus;
  final String avatar;
  final String bio;
  final String city;
  final String address;
  final String headline;
  final List<String> skills;
  final double hourlyRate;
  final int experienceYears;
  final bool isAvailable;
  final List<String> portfolio;
  final double rating;
  final int ratingCount;
  final int jobsCompleted;
  final int jobsAssigned;
  final double avgResponseMinutes;
  final double walletBalance;
  final List<String> favoriteTechnicians;
  final List<String> favoriteTools;
  final bool online;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  const User({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.role = 'client',
    this.status = 'active',
    this.kycStatus = 'none',
    this.avatar = '',
    this.bio = '',
    this.city = '',
    this.address = '',
    this.headline = '',
    this.skills = const [],
    this.hourlyRate = 0,
    this.experienceYears = 0,
    this.isAvailable = true,
    this.portfolio = const [],
    this.rating = 0,
    this.ratingCount = 0,
    this.jobsCompleted = 0,
    this.jobsAssigned = 0,
    this.avgResponseMinutes = 60,
    this.walletBalance = 0,
    this.favoriteTechnicians = const [],
    this.favoriteTools = const [],
    this.online = false,
    this.lastSeenAt,
    this.createdAt,
  });

  bool get isClient => role == 'client';
  bool get isTechnician => role == 'technician';
  bool get isSupplier => role == 'supplier';
  bool get isAdmin => role == 'admin';
  bool get verified => kycStatus == 'approved';
  bool get suspended => status == 'suspended';
  bool get exists => id.isNotEmpty;
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  /// Share of hired jobs that were finished (0–1); null until there is history.
  double? get completionRate => jobsAssigned <= 0 ? null : (jobsCompleted / jobsAssigned).clamp(0, 1).toDouble();

  /// Accepts a populated object or a bare id.
  factory User.ref(dynamic v) => v is Map ? User.fromJson(asJson(v)) : User(id: idOf(v));

  factory User.fromJson(Json j) => User(
        id: idOf(j),
        name: str(j['name']),
        email: str(j['email']),
        phone: str(j['phone']),
        role: str(j['role'], 'client'),
        status: str(j['status'], 'active'),
        kycStatus: str(j['kycStatus'], 'none'),
        avatar: str(j['avatar']),
        bio: str(j['bio']),
        city: str(j['city']),
        address: str(j['address']),
        headline: str(j['headline']),
        skills: strings(j['skills']),
        hourlyRate: dbl(j['hourlyRate']),
        experienceYears: integer(j['experienceYears']),
        isAvailable: j['isAvailable'] != false,
        portfolio: strings(j['portfolio']),
        rating: dbl(j['rating']),
        ratingCount: integer(j['ratingCount']),
        jobsCompleted: integer(j['jobsCompleted']),
        jobsAssigned: integer(j['jobsAssigned']),
        avgResponseMinutes: dbl(j['avgResponseMinutes'], 60),
        walletBalance: dbl(j['walletBalance']),
        favoriteTechnicians: strings(j['favoriteTechnicians']),
        favoriteTools: strings(j['favoriteTools']),
        online: j['online'] == true,
        lastSeenAt: date(j['lastSeenAt']),
        createdAt: date(j['createdAt']),
      );

  Json toJson() => {
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
        'address': address,
        'headline': headline,
        'skills': skills,
        'hourlyRate': hourlyRate,
        'experienceYears': experienceYears,
        'isAvailable': isAvailable,
        'portfolio': portfolio,
        'rating': rating,
        'ratingCount': ratingCount,
        'jobsCompleted': jobsCompleted,
        'jobsAssigned': jobsAssigned,
        'avgResponseMinutes': avgResponseMinutes,
        'walletBalance': walletBalance,
        'favoriteTechnicians': favoriteTechnicians,
        'favoriteTools': favoriteTools,
        'createdAt': createdAt?.toIso8601String(),
      };
}

/// A review left for a technician (from a job) or a tool (from a rental).
class Review {
  final int rating;
  final String text;
  final String author;
  final String authorAvatar;
  final String subject; // job title, when there is one
  final String category;
  final DateTime? at;

  const Review({required this.rating, this.text = '', this.author = '', this.authorAvatar = '', this.subject = '', this.category = '', this.at});

  factory Review.fromJson(Json j) => Review(
        rating: integer(j['rating']),
        text: str(j['review']),
        author: str(j['clientName'] ?? j['renterName'], 'Customer'),
        authorAvatar: str(j['clientAvatar'] ?? j['renterAvatar']),
        subject: str(j['jobTitle']),
        category: str(j['category']),
        at: date(j['date']),
      );
}

/// Star breakdown shown at the top of a technician's reviews.
class RatingSummary {
  final int count;
  final double average;
  final Map<int, int> distribution;
  const RatingSummary({this.count = 0, this.average = 0, this.distribution = const {}});

  factory RatingSummary.fromJson(Json j) => RatingSummary(
        count: integer(j['count']),
        average: dbl(j['average']),
        distribution: {for (var s = 1; s <= 5; s++) s: integer(asJson(j['distribution'])['$s'])},
      );
}

/// A landing-page testimonial.
class Testimonial {
  final int rating;
  final String review;
  final String category;
  final String jobTitle;
  final String clientName;
  final String clientCity;
  final String technicianId;
  final String technicianName;
  final String technicianAvatar;
  const Testimonial({
    required this.rating,
    required this.review,
    this.category = '',
    this.jobTitle = '',
    this.clientName = '',
    this.clientCity = '',
    this.technicianId = '',
    this.technicianName = '',
    this.technicianAvatar = '',
  });

  factory Testimonial.fromJson(Json j) => Testimonial(
        rating: integer(j['rating']),
        review: str(j['review']),
        category: str(j['category']),
        jobTitle: str(j['jobTitle']),
        clientName: str(j['clientName']),
        clientCity: str(j['clientCity']),
        technicianId: idOf(j['technicianId']),
        technicianName: str(j['technicianName']),
        technicianAvatar: str(j['technicianAvatar']),
      );
}

/// Identity verification record.
class Kyc {
  final String id;
  final User user;
  final String fullName;
  final String idType;
  final String idNumber;
  final String idFrontImage;
  final String idBackImage;
  final String selfieImage;
  final String status;
  final String rejectionReason;
  final DateTime? createdAt;
  const Kyc({
    required this.id,
    required this.user,
    this.fullName = '',
    this.idType = 'cnic',
    this.idNumber = '',
    this.idFrontImage = '',
    this.idBackImage = '',
    this.selfieImage = '',
    this.status = 'pending',
    this.rejectionReason = '',
    this.createdAt,
  });

  factory Kyc.fromJson(Json j) => Kyc(
        id: idOf(j),
        user: User.ref(j['user']),
        fullName: str(j['fullName']),
        idType: str(j['idType'], 'cnic'),
        idNumber: str(j['idNumber']),
        idFrontImage: str(j['idFrontImage']),
        idBackImage: str(j['idBackImage']),
        selfieImage: str(j['selfieImage']),
        status: str(j['status'], 'pending'),
        rejectionReason: str(j['rejectionReason']),
        createdAt: date(j['createdAt']),
      );
}

/// A report in the admin trust & safety queue.
class Report {
  final String id;
  final User reporter;
  final String targetType;
  final String targetId;
  final String targetLabel;
  final String reason;
  final String details;
  final String status;
  final String resolutionNote;
  final DateTime? createdAt;
  const Report({
    required this.id,
    required this.reporter,
    this.targetType = 'user',
    this.targetId = '',
    this.targetLabel = '',
    this.reason = 'other',
    this.details = '',
    this.status = 'open',
    this.resolutionNote = '',
    this.createdAt,
  });

  bool get open => status == 'open';

  factory Report.fromJson(Json j) => Report(
        id: idOf(j),
        reporter: User.ref(j['reporter']),
        targetType: str(j['targetType'], 'user'),
        targetId: idOf(j['targetId']),
        targetLabel: str(j['targetLabel']),
        reason: str(j['reason'], 'other'),
        details: str(j['details']),
        status: str(j['status'], 'open'),
        resolutionNote: str(j['resolutionNote']),
        createdAt: date(j['createdAt']),
      );
}

/// An in-app notification.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Json data;
  final bool read;
  final DateTime? createdAt;
  const AppNotification({required this.id, this.type = '', this.title = '', this.body = '', this.data = const {}, this.read = false, this.createdAt});

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: idOf(j),
        type: str(j['type']),
        title: str(j['title']),
        body: str(j['body']),
        data: asJson(j['data']),
        read: j['readAt'] != null,
        createdAt: date(j['createdAt']),
      );
}
