import 'json.dart';
import 'user.dart';

/// How a job or rental is paid.
///   wallet: none → held (escrow) → released | refunded
///   cash:   none → cash_due → cash_paid
class Payment {
  final String method;
  final String status;
  final double amount;
  final double deposit;
  final double fee;
  final double net;
  const Payment({this.method = 'cash', this.status = 'none', this.amount = 0, this.deposit = 0, this.fee = 0, this.net = 0});

  bool get isWallet => method == 'wallet';
  bool get held => status == 'held';
  bool get released => status == 'released';
  bool get refunded => status == 'refunded';
  bool get exists => status != 'none';

  factory Payment.fromJson(dynamic v) {
    final j = asJson(v);
    return Payment(
      method: str(j['method'], 'cash'),
      status: str(j['status'], 'none'),
      amount: dbl(j['amount']),
      deposit: dbl(j['deposit']),
      fee: dbl(j['fee']),
      net: dbl(j['net']),
    );
  }
}

/// A technician's quote on a job.
class Bid {
  final String id;
  final User technician;
  final double amount;
  final String message;
  final int etaDays;
  final String status;
  final DateTime? createdAt;
  const Bid({required this.id, required this.technician, this.amount = 0, this.message = '', this.etaDays = 1, this.status = 'pending', this.createdAt});

  bool get pending => status == 'pending';

  factory Bid.fromJson(Json j) => Bid(
        id: idOf(j),
        technician: User.ref(j['technician']),
        amount: dbl(j['amount']),
        message: str(j['message']),
        etaDays: integer(j['etaDays'], 1),
        status: str(j['status'], 'pending'),
        createdAt: date(j['createdAt']),
      );
}

/// One line of a job's activity log.
class JobEvent {
  final String event;
  final String note;
  final String byName;
  final String byRole;
  final DateTime? at;
  const JobEvent({required this.event, this.note = '', this.byName = '', this.byRole = '', this.at});

  factory JobEvent.fromJson(Json j) {
    final by = asJson(j['by']);
    return JobEvent(event: str(j['event']), note: str(j['note']), byName: str(by['name']), byRole: str(by['role']), at: date(j['at']));
  }
}

const jobStages = ['hired', 'on_the_way', 'working', 'done'];

class Job {
  final String id;
  final User client;
  final String title;
  final String description;
  final String category;
  final double budget;
  final String location;
  final String city;
  final String urgency;
  final DateTime? preferredDate;
  final List<String> images;
  final String status; // pending | in_progress | completed | cancelled
  final User? requestedTechnician;
  final bool requestDeclined;
  final User? technician; // hired
  final double? agreedPrice;
  final List<Bid> bids;
  final int bidCount;
  final List<JobEvent> history;
  final String stage; // hired | on_the_way | working | done
  final DateTime? hiredAt;
  final DateTime? doneAt;
  final String completionNote;
  final List<String> completionImages;
  final Payment payment;
  final DateTime? autoCompleteAt;
  final DateTime? completedAt;
  final String cancelReason;
  final int? rating;
  final String review;
  final DateTime? createdAt;

  const Job({
    required this.id,
    required this.client,
    this.title = '',
    this.description = '',
    this.category = 'general',
    this.budget = 0,
    this.location = '',
    this.city = '',
    this.urgency = 'normal',
    this.preferredDate,
    this.images = const [],
    this.status = 'pending',
    this.requestedTechnician,
    this.requestDeclined = false,
    this.technician,
    this.agreedPrice,
    this.bids = const [],
    this.bidCount = 0,
    this.history = const [],
    this.stage = 'hired',
    this.hiredAt,
    this.doneAt,
    this.completionNote = '',
    this.completionImages = const [],
    this.payment = const Payment(),
    this.autoCompleteAt,
    this.completedAt,
    this.cancelReason = '',
    this.rating,
    this.review = '',
    this.createdAt,
  });

  bool get pending => status == 'pending';
  bool get inProgress => status == 'in_progress';
  bool get completed => status == 'completed';
  bool get cancelled => status == 'cancelled';
  bool get isDirectRequest => requestedTechnician != null;

  /// The technician said the work is finished; the client has yet to confirm.
  bool get awaitingConfirmation => inProgress && stage == 'done';

  /// Before any work was done: the client may cancel, the technician withdraw.
  bool get beforeWork => inProgress && (stage == 'hired' || stage == 'on_the_way');

  int get stageIndex => jobStages.indexOf(stage).clamp(0, jobStages.length - 1);

  /// What the job costs: the agreed price once hired, else the budget.
  double get price => agreedPrice ?? budget;

  Bid? bidBy(String technicianId) {
    for (final b in bids) {
      if (b.technician.id == technicianId) return b;
    }
    return null;
  }

  List<Bid> get openBids => bids.where((b) => b.status != 'withdrawn').toList();

  double? get lowestBid {
    final open = bids.where((b) => b.pending).map((b) => b.amount);
    return open.isEmpty ? null : open.reduce((a, b) => a < b ? a : b);
  }

  factory Job.fromJson(Json j) {
    final bids = asJsonList(j['bids']).map(Bid.fromJson).toList();
    return Job(
      id: idOf(j),
      client: User.ref(j['client']),
      title: str(j['title']),
      description: str(j['description']),
      category: str(j['category'], 'general'),
      budget: dbl(j['budget']),
      location: str(j['location']),
      city: str(j['city']),
      urgency: str(j['urgency'], 'normal'),
      preferredDate: date(j['preferredDate']),
      images: strings(j['images']),
      status: str(j['status'], 'pending'),
      requestedTechnician: j['requestedTechnician'] == null ? null : User.ref(j['requestedTechnician']),
      requestDeclined: j['requestDeclined'] == true,
      technician: j['assignedTechnician'] == null ? null : User.ref(j['assignedTechnician']),
      agreedPrice: j['agreedPrice'] == null ? null : dbl(j['agreedPrice']),
      bids: bids,
      bidCount: integer(j['bidCount'], bids.length),
      history: asJsonList(j['history']).map(JobEvent.fromJson).toList(),
      stage: str(j['stage'], 'hired'),
      hiredAt: date(j['hiredAt']),
      doneAt: date(j['doneAt']),
      completionNote: str(j['completionNote']),
      completionImages: strings(j['completionImages']),
      payment: Payment.fromJson(j['payment']),
      autoCompleteAt: date(j['autoCompleteAt']),
      completedAt: date(j['completedAt']),
      cancelReason: str(j['cancelReason']),
      rating: j['rating'] == null ? null : integer(j['rating']),
      review: str(j['review']),
      createdAt: date(j['createdAt']),
    );
  }
}

/// What jobs in a category usually cost.
class Estimate {
  final String category;
  final String urgency;
  final double low;
  final double high;
  final double typical;
  final bool fromHistory;
  final int samples;
  const Estimate({this.category = 'general', this.urgency = 'normal', this.low = 0, this.high = 0, this.typical = 0, this.fromHistory = false, this.samples = 0});

  bool get exists => high > 0;

  factory Estimate.fromJson(dynamic v) {
    final j = asJson(v);
    return Estimate(
      category: str(j['category'], 'general'),
      urgency: str(j['urgency'], 'normal'),
      low: dbl(j['low']),
      high: dbl(j['high']),
      typical: dbl(j['typical']),
      fromHistory: j['basis'] == 'history',
      samples: integer(j['samples']),
    );
  }
}

/// What the AI understood from a problem description.
class Analysis {
  final String category;
  final double confidence;
  final String urgency;
  final List<String> keywords;
  final List<String> urgencyTerms;
  final String engine;
  final Estimate estimate;
  const Analysis({
    this.category = 'general',
    this.confidence = 0,
    this.urgency = 'normal',
    this.keywords = const [],
    this.urgencyTerms = const [],
    this.engine = '',
    this.estimate = const Estimate(),
  });

  bool get confident => confidence >= 0.45;

  factory Analysis.fromJson(dynamic v) {
    final j = asJson(v);
    return Analysis(
      category: str(j['category'], 'general'),
      confidence: dbl(j['confidence']),
      urgency: str(j['urgency'], 'normal'),
      keywords: strings(j['keywords']),
      urgencyTerms: strings(j['urgencyTerms']),
      engine: str(j['engine']),
      estimate: Estimate.fromJson(j['estimate']),
    );
  }
}

/// One AI-ranked technician: Smart Match results and ranked quotes.
class TechMatch {
  final User technician;
  final int matchPercent;
  final List<String> reasons;
  final List<String> notes;
  final Map<String, double> breakdown;
  final String engine;
  // Only on ranked quotes:
  final String bidId;
  final double amount;
  final int etaDays;
  final String message;
  final String bidStatus;

  const TechMatch({
    required this.technician,
    this.matchPercent = 0,
    this.reasons = const [],
    this.notes = const [],
    this.breakdown = const {},
    this.engine = '',
    this.bidId = '',
    this.amount = 0,
    this.etaDays = 0,
    this.message = '',
    this.bidStatus = '',
  });

  factory TechMatch.fromJson(Json j) => TechMatch(
        technician: User.fromJson({...j, '_id': j['technicianId']}),
        matchPercent: integer(j['matchPercent'], (dbl(j['score']) * 20).round()).clamp(0, 100),
        reasons: strings(j['reasons']),
        notes: strings(j['notes']),
        breakdown: asJson(j['breakdown']).map((k, v) => MapEntry(k, dbl(v))),
        engine: str(j['engine']),
        bidId: str(j['bidId']),
        amount: dbl(j['amount']),
        etaDays: integer(j['etaDays']),
        message: str(j['message']),
        bidStatus: str(j['bidStatus']),
      );
}

/// Result of POST /api/ai/recommend.
class Recommendation {
  final String engine;
  final Analysis? analysis;
  final String category;
  final String urgency;
  final Estimate estimate;
  final List<TechMatch> ranked;
  const Recommendation({this.engine = '', this.analysis, this.category = 'general', this.urgency = 'normal', this.estimate = const Estimate(), this.ranked = const []});

  factory Recommendation.fromJson(Json j) => Recommendation(
        engine: str(j['engine']),
        analysis: j['analysis'] == null ? null : Analysis.fromJson(j['analysis']),
        category: str(j['category'], 'general'),
        urgency: str(j['urgency'], 'normal'),
        estimate: Estimate.fromJson(j['estimate']),
        ranked: asJsonList(j['ranked']).map(TechMatch.fromJson).toList(),
      );
}
