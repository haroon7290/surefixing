import 'user.dart';

double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class Bid {
  final String id;
  final UserLite technician;
  final double amount;
  final String message;
  final int etaDays;
  final String status;
  final DateTime? createdAt;

  Bid({
    required this.id,
    required this.technician,
    required this.amount,
    required this.message,
    required this.etaDays,
    required this.status,
    this.createdAt,
  });

  String get technicianId => technician.id;
  String get technicianName => technician.name;

  factory Bid.fromJson(Map<String, dynamic> json) => Bid(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        technician: UserLite.fromAny(json['technician']) ?? const UserLite(id: ''),
        amount: _d(json['amount']),
        message: (json['message'] ?? '').toString(),
        etaDays: _i(json['etaDays'], 1),
        status: (json['status'] ?? 'pending').toString(),
        createdAt: _date(json['createdAt']),
      );
}

class JobEvent {
  final String status;
  final String note;
  final String byName;
  final String byRole;
  final DateTime? at;

  JobEvent({required this.status, required this.note, required this.byName, required this.byRole, this.at});

  factory JobEvent.fromJson(Map<String, dynamic> json) {
    final by = json['by'];
    return JobEvent(
      status: (json['status'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      byName: by is Map ? (by['name'] ?? '').toString() : '',
      byRole: by is Map ? (by['role'] ?? '').toString() : '',
      at: _date(json['at']),
    );
  }
}

class Job {
  final String id;
  final UserLite client;
  final UserLite? technician;
  final UserLite? requestedTechnician;
  final bool requestDeclined;
  final String title;
  final String description;
  final String category;
  final double budget;
  final double? agreedPrice;
  final String location;
  final String city;
  final String urgency;
  final DateTime? preferredDate;
  final String status;
  final List<String> images;
  final List<Bid> bids;
  final List<JobEvent> history;
  final double? rating;
  final String review;
  final String cancelReason;
  final DateTime createdAt;
  final DateTime? completedAt;

  Job({
    required this.id,
    required this.client,
    required this.title,
    required this.description,
    required this.category,
    required this.budget,
    required this.location,
    required this.status,
    required this.bids,
    required this.createdAt,
    this.technician,
    this.requestedTechnician,
    this.requestDeclined = false,
    this.agreedPrice,
    this.city = '',
    this.urgency = 'normal',
    this.preferredDate,
    this.images = const [],
    this.history = const [],
    this.rating,
    this.review = '',
    this.cancelReason = '',
    this.completedAt,
  });

  // Older call sites.
  String get clientId => client.id;
  String get clientName => client.name;
  String? get technicianId => technician?.id;
  String? get technicianName => technician?.name;

  bool get isOpen => status == 'pending';
  bool get isActive => status == 'pending' || status == 'in_progress';
  bool get isDirectRequest => requestedTechnician != null;
  int get pendingBids => bids.where((b) => b.status == 'pending').length;

  Bid? bidBy(String userId) {
    for (final b in bids) {
      if (b.technicianId == userId) return b;
    }
    return null;
  }

  double? get lowestBid {
    if (bids.isEmpty) return null;
    return bids.map((b) => b.amount).reduce((a, b) => a < b ? a : b);
  }

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        client: UserLite.fromAny(json['client']) ?? const UserLite(id: ''),
        technician: UserLite.fromAny(json['assignedTechnician']),
        requestedTechnician: UserLite.fromAny(json['requestedTechnician']),
        requestDeclined: json['requestDeclined'] == true,
        title: (json['title'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        category: (json['category'] ?? 'general').toString(),
        budget: _d(json['budget']),
        agreedPrice: json['agreedPrice'] == null ? null : _d(json['agreedPrice']),
        location: (json['location'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        urgency: (json['urgency'] ?? 'normal').toString(),
        preferredDate: _date(json['preferredDate']),
        status: (json['status'] ?? 'pending').toString(),
        images: (json['images'] as List? ?? const []).map((e) => e.toString()).toList(),
        bids: (json['bids'] as List? ?? const []).whereType<Map>().map((b) => Bid.fromJson(Map<String, dynamic>.from(b))).toList(),
        history:
            (json['history'] as List? ?? const []).whereType<Map>().map((h) => JobEvent.fromJson(Map<String, dynamic>.from(h))).toList(),
        rating: json['rating'] == null ? null : _d(json['rating']),
        review: (json['review'] ?? '').toString(),
        cancelReason: (json['cancelReason'] ?? '').toString(),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        completedAt: _date(json['completedAt']),
      );
}
