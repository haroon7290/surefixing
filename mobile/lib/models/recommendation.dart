import 'user.dart';

double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
List<String> _strings(dynamic v) => (v as List? ?? const []).map((e) => e.toString()).toList();

/// What the AI understood from a problem description.
class Analysis {
  final String category;
  final double confidence;
  final List<MapEntry<String, double>> alternatives;
  final String urgency;
  final List<String> urgencyTerms;
  final List<String> keywords;
  final String engine;

  Analysis({
    required this.category,
    required this.confidence,
    required this.alternatives,
    required this.urgency,
    required this.urgencyTerms,
    required this.keywords,
    required this.engine,
  });

  bool get isConfident => confidence >= 0.45;

  factory Analysis.fromJson(Map<String, dynamic> j) => Analysis(
        category: (j['category'] ?? 'general').toString(),
        confidence: _d(j['confidence']),
        alternatives: (j['categories'] as List? ?? const [])
            .whereType<Map>()
            .map((c) => MapEntry(c['category'].toString(), _d(c['confidence'])))
            .toList(),
        urgency: (j['urgency'] ?? 'normal').toString(),
        urgencyTerms: _strings(j['urgencyTerms']),
        keywords: _strings(j['keywords']),
        engine: (j['engine'] ?? '').toString(),
      );
}

/// One AI-ranked technician — used by Smart Match and ranked quotes.
class TechMatch {
  final String technicianId;
  final String name;
  final String avatar;
  final String headline;
  final String city;
  final List<String> skills;
  final double rating;
  final int ratingCount;
  final int jobsCompleted;
  final double avgResponseMinutes;
  final double hourlyRate;
  final bool verified;
  final bool isAvailable;
  final bool online;
  final double score;
  final int matchPercent;
  final List<String> reasons;
  final List<String> notes;
  final Map<String, double> breakdown;
  final String engine;

  // Quote-only fields (ranked bids).
  final String bidId;
  final double amount;
  final int etaDays;
  final String message;
  final String bidStatus;

  TechMatch({
    required this.technicianId,
    required this.name,
    required this.avatar,
    required this.headline,
    required this.city,
    required this.skills,
    required this.rating,
    required this.ratingCount,
    required this.jobsCompleted,
    required this.avgResponseMinutes,
    required this.hourlyRate,
    required this.verified,
    required this.isAvailable,
    required this.online,
    required this.score,
    required this.matchPercent,
    required this.reasons,
    required this.notes,
    required this.breakdown,
    required this.engine,
    this.bidId = '',
    this.amount = 0,
    this.etaDays = 0,
    this.message = '',
    this.bidStatus = '',
  });

  UserLite get asUser => UserLite(
        id: technicianId,
        name: name,
        avatar: avatar,
        rating: rating,
        ratingCount: ratingCount,
        city: city,
        kycStatus: verified ? 'approved' : 'none',
        online: online,
      );

  factory TechMatch.fromJson(Map<String, dynamic> j) => TechMatch(
        technicianId: (j['technicianId'] ?? '').toString(),
        name: (j['name'] ?? 'Technician').toString(),
        avatar: (j['avatar'] ?? '').toString(),
        headline: (j['headline'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
        skills: _strings(j['skills']),
        rating: _d(j['rating']),
        ratingCount: _i(j['ratingCount']),
        jobsCompleted: _i(j['jobsCompleted']),
        avgResponseMinutes: _d(j['avgResponseMinutes'], 60),
        hourlyRate: _d(j['hourlyRate']),
        verified: j['kycStatus'] == 'approved' || j['verified'] == true,
        isAvailable: j['isAvailable'] != false,
        online: j['online'] == true,
        score: _d(j['score']),
        matchPercent: _i(j['matchPercent'], (_d(j['score']) * 20).round()),
        reasons: _strings(j['reasons']),
        notes: _strings(j['notes']),
        breakdown: (j['breakdown'] is Map) ? Map<String, dynamic>.from(j['breakdown']).map((k, v) => MapEntry(k, _d(v))) : const {},
        engine: (j['engine'] ?? '').toString(),
        bidId: (j['bidId'] ?? '').toString(),
        amount: _d(j['amount']),
        etaDays: _i(j['etaDays']),
        message: (j['message'] ?? '').toString(),
        bidStatus: (j['bidStatus'] ?? '').toString(),
      );
}
