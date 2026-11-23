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
  /// The supplier's neighbourhood, where the tool is picked up from.
  final String area;
  /// Distance from the searcher, when known.
  final double? distanceKm;
  final List<String> images;
  final double rentPricePerDay;
  final double deposit;
  /// One-time sale price; 0 = rent only.
  final double purchasePrice;
  /// The supplier delivers, for [deliveryFee] (0 = free).
  final bool deliveryAvailable;
  final double deliveryFee;
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
    this.area = '',
    this.distanceKm,
    this.images = const [],
    this.rentPricePerDay = 0,
    this.deposit = 0,
    this.purchasePrice = 0,
    this.deliveryAvailable = false,
    this.deliveryFee = 0,
    this.available = true,
    this.stock = 1,
    this.rating = 0,
    this.ratingCount = 0,
    this.rentalsCount = 0,
    this.reviews = const [],
  });

  bool get inStock => stock > 0;
  bool get rentable => available && inStock;
  bool get forSale => purchasePrice > 0;
  String get image => images.isEmpty ? '' : images.first;
  String get place => [area, city].where((e) => e.isNotEmpty).join(', ');

  factory Tool.ref(dynamic v) => v is Map ? Tool.fromJson(asJson(v)) : Tool(id: idOf(v), supplier: const User(id: ''));

  factory Tool.fromJson(Json j) => Tool(
        id: idOf(j),
        supplier: User.ref(j['supplier']),
        name: str(j['name']),
        description: str(j['description']),
        category: str(j['category'], 'general'),
        condition: str(j['condition'], 'good'),
        city: str(j['city']),
        area: str(j['area']),
        distanceKm: j['distanceKm'] is num ? dbl(j['distanceKm']) : null,
        images: strings(j['images']),
        rentPricePerDay: dbl(j['rentPricePerDay']),
        deposit: dbl(j['deposit']),
        purchasePrice: dbl(j['purchasePrice']),
        deliveryAvailable: j['deliveryAvailable'] == true,
        deliveryFee: dbl(j['deliveryFee']),
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

/// A rental (type `rent`) or a one-time purchase (type `purchase`), with
/// its invoice.
class Rental {
  final String id;
  final Tool tool;
  final User renter;
  final User supplier;
  final String type;
  final String invoiceNo;
  final DateTime? startDate;
  final DateTime? endDate;
  final int days;
  final double dailyRate;
  final double deposit;
  final int lateDays;
  final double lateFee;
  /// Rent for all days, or the sale price.
  final double totalCost;
  final double deliveryFee;
  final Payment payment;
  final String fulfillment;
  final String note;
  final String status; // requested | active | returned | completed | rejected | cancelled
  final String rejectionReason;
  final DateTime? returnedAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;
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
    this.invoiceNo = '',
    this.startDate,
    this.endDate,
    this.days = 0,
    this.dailyRate = 0,
    this.deposit = 0,
    this.lateDays = 0,
    this.lateFee = 0,
    this.totalCost = 0,
    this.deliveryFee = 0,
    this.payment = const Payment(),
    this.fulfillment = 'pickup',
    this.note = '',
    this.status = 'requested',
    this.rejectionReason = '',
    this.returnedAt,
    this.approvedAt,
    this.completedAt,
    this.rating,
    this.review = '',
    this.overdue = false,
    this.daysLeft,
    this.handover = const Handover(),
    this.createdAt,
  });

  bool get isPurchase => type == 'purchase';
  bool get requested => status == 'requested';
  bool get active => status == 'active';
  bool get finished => status == 'returned' || status == 'completed';
  bool get open => requested || active;
  /// What is paid for the rental or tool itself, delivery included (the
  /// deposit is separate).
  double get amount => totalCost + deliveryFee;
  bool get canReview => finished && rating == null;

  /// Phones and addresses are shared once the supplier approves.
  bool get contactShared => status == 'active' || finished;

  factory Rental.fromJson(Json j) => Rental(
        id: idOf(j),
        tool: Tool.ref(j['tool']),
        renter: User.ref(j['renter']),
        supplier: User.ref(j['supplier']),
        type: str(j['type'], 'rent'),
        invoiceNo: str(j['invoiceNo']),
        startDate: date(j['startDate']),
        endDate: date(j['endDate']),
        days: integer(j['days']),
        dailyRate: dbl(j['dailyRate']),
        deposit: dbl(j['deposit']),
        lateDays: integer(j['lateDays']),
        lateFee: dbl(j['lateFee']),
        totalCost: dbl(j['totalCost']),
        deliveryFee: dbl(j['deliveryFee']),
        payment: Payment.fromJson(j['payment']),
        fulfillment: str(j['fulfillment'], 'pickup'),
        note: str(j['note']),
        status: str(j['status'], 'requested'),
        rejectionReason: str(j['rejectionReason']),
        returnedAt: date(j['returnedAt']),
        approvedAt: date(j['approvedAt']),
        completedAt: date(j['completedAt']),
        rating: j['rating'] == null ? null : integer(j['rating']),
        review: str(j['review']),
        overdue: j['overdue'] == true,
        daysLeft: j['daysLeft'] == null ? null : integer(j['daysLeft']),
        handover: Handover.fromJson(j['handover']),
        createdAt: date(j['createdAt']),
      );
}
