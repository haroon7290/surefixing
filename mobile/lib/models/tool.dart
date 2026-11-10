import 'job.dart';
import 'json.dart';
import 'user.dart';

class Tool {
  final String id;
  final User supplier;
  final String name;
  final String description;
  final String category;
  final String condition;
  final String city;
  final List<String> images;
  final double rentPricePerDay;
  final double deposit;
  final double purchasePrice;
  final int installmentMonths;
  final double installmentMonthly;
  final bool available;
  final int stock;
  final double rating;
  final int ratingCount;
  final int rentalsCount;
  final List<Review> reviews;

  const Tool({
    required this.id,
    required this.supplier,
    this.name = '',
    this.description = '',
    this.category = 'general',
    this.condition = 'good',
    this.city = '',
    this.images = const [],
    this.rentPricePerDay = 0,
    this.deposit = 0,
    this.purchasePrice = 0,
    this.installmentMonths = 0,
    this.installmentMonthly = 0,
    this.available = true,
    this.stock = 1,
    this.rating = 0,
    this.ratingCount = 0,
    this.rentalsCount = 0,
    this.reviews = const [],
  });

  bool get inStock => stock > 0;
  bool get rentable => available && inStock;
  bool get hasInstallments => installmentMonths > 0;
  String get image => images.isEmpty ? '' : images.first;

  /// Monthly payment on the installment plan.
  double get monthly => installmentMonthly > 0 ? installmentMonthly : (installmentMonths > 0 ? (purchasePrice / installmentMonths).ceilToDouble() : 0);

  factory Tool.ref(dynamic v) => v is Map ? Tool.fromJson(asJson(v)) : Tool(id: idOf(v), supplier: const User(id: ''));

  factory Tool.fromJson(Json j) => Tool(
        id: idOf(j),
        supplier: User.ref(j['supplier']),
        name: str(j['name']),
        description: str(j['description']),
        category: str(j['category'], 'general'),
        condition: str(j['condition'], 'good'),
        city: str(j['city']),
        images: strings(j['images']),
        rentPricePerDay: dbl(j['rentPricePerDay']),
        deposit: dbl(j['deposit']),
        purchasePrice: dbl(j['purchasePrice']),
        installmentMonths: integer(j['installmentMonths']),
        installmentMonthly: dbl(j['installmentMonthly']),
        available: j['available'] != false,
        stock: integer(j['stock'], 1),
        rating: dbl(j['rating']),
        ratingCount: integer(j['ratingCount']),
        rentalsCount: integer(j['rentalsCount']),
        reviews: asJsonList(j['reviews']).map(Review.fromJson).toList(),
      );
}

/// How a tool changes hands: pickup from the supplier or delivery.
class Handover {
  final String method;
  final String address;
  final String city;
  final bool revealed;
  const Handover({this.method = 'pickup', this.address = '', this.city = '', this.revealed = false});

  bool get delivery => method == 'delivery';

  factory Handover.fromJson(dynamic v) {
    final j = asJson(v);
    return Handover(method: str(j['method'], 'pickup'), address: str(j['address']), city: str(j['city']), revealed: j['revealed'] == true);
  }
}

/// A rental (type `rent`) or an installment purchase (type `installment`).
class Rental {
  final String id;
  final Tool tool;
  final User renter;
  final User supplier;
  final String type;
  final DateTime? startDate;
  final DateTime? endDate;
  final int days;
  final double dailyRate;
  final double deposit;
  final int lateDays;
  final double lateFee;
  final int monthsTotal;
  final int monthsPaid;
  final double monthlyAmount;
  final double totalCost;
  final Payment payment;
  final String fulfillment;
  final String note;
  final String status; // requested | active | returned | completed | rejected | cancelled
  final String rejectionReason;
  final DateTime? returnedAt;
  final int? rating;
  final String review;
  final bool overdue;
  final int? daysLeft;
  final Handover handover;
  final DateTime? createdAt;

  const Rental({
    required this.id,
    required this.tool,
    required this.renter,
    required this.supplier,
    this.type = 'rent',
    this.startDate,
    this.endDate,
    this.days = 0,
    this.dailyRate = 0,
    this.deposit = 0,
    this.lateDays = 0,
    this.lateFee = 0,
    this.monthsTotal = 0,
    this.monthsPaid = 0,
    this.monthlyAmount = 0,
    this.totalCost = 0,
    this.payment = const Payment(),
    this.fulfillment = 'pickup',
    this.note = '',
    this.status = 'requested',
    this.rejectionReason = '',
    this.returnedAt,
    this.rating,
    this.review = '',
    this.overdue = false,
    this.daysLeft,
    this.handover = const Handover(),
    this.createdAt,
  });

  bool get isInstallment => type == 'installment';
  bool get requested => status == 'requested';
  bool get active => status == 'active';
  bool get finished => status == 'returned' || status == 'completed';
  bool get open => requested || active;
  int get monthsRemaining => (monthsTotal - monthsPaid).clamp(0, monthsTotal);
  bool get canReview => finished && rating == null;

  factory Rental.fromJson(Json j) => Rental(
        id: idOf(j),
        tool: Tool.ref(j['tool']),
        renter: User.ref(j['renter']),
        supplier: User.ref(j['supplier']),
        type: str(j['type'], 'rent'),
        startDate: date(j['startDate']),
        endDate: date(j['endDate']),
        days: integer(j['days']),
        dailyRate: dbl(j['dailyRate']),
        deposit: dbl(j['deposit']),
        lateDays: integer(j['lateDays']),
        lateFee: dbl(j['lateFee']),
        monthsTotal: integer(j['monthsTotal']),
        monthsPaid: integer(j['monthsPaid']),
        monthlyAmount: dbl(j['monthlyAmount']),
        totalCost: dbl(j['totalCost']),
        payment: Payment.fromJson(j['payment']),
        fulfillment: str(j['fulfillment'], 'pickup'),
        note: str(j['note']),
        status: str(j['status'], 'requested'),
        rejectionReason: str(j['rejectionReason']),
        returnedAt: date(j['returnedAt']),
        rating: j['rating'] == null ? null : integer(j['rating']),
        review: str(j['review']),
        overdue: j['overdue'] == true,
        daysLeft: j['daysLeft'] == null ? null : integer(j['daysLeft']),
        handover: Handover.fromJson(j['handover']),
        createdAt: date(j['createdAt']),
      );
}
