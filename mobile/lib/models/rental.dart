import 'user.dart';

double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class RentalTool {
  final String id;
  final String name;
  final String image;
  final String category;
  final double rentPricePerDay;
  final String supplierId;

  RentalTool(
      {required this.id,
      required this.name,
      required this.image,
      required this.category,
      required this.rentPricePerDay,
      required this.supplierId});

  factory RentalTool.fromAny(dynamic v) {
    if (v is Map) {
      final images = (v['images'] as List? ?? const []).map((e) => e.toString()).toList();
      final supplier = v['supplier'];
      return RentalTool(
        id: (v['_id'] ?? v['id'] ?? '').toString(),
        name: (v['name'] ?? 'Tool').toString(),
        image: images.isNotEmpty ? images.first : (v['image'] ?? '').toString(),
        category: (v['category'] ?? 'general').toString(),
        rentPricePerDay: _d(v['rentPricePerDay']),
        supplierId: supplier is Map ? (supplier['_id'] ?? '').toString() : (supplier ?? '').toString(),
      );
    }
    return RentalTool(id: (v ?? '').toString(), name: 'Tool', image: '', category: 'general', rentPricePerDay: 0, supplierId: '');
  }
}

class Rental {
  final String id;
  final RentalTool tool;
  final UserLite? renter;
  final UserLite? supplier;
  final String type; // rent | installment
  final DateTime? startDate;
  final DateTime? endDate;
  final int days;
  final double totalCost;
  final double deposit;
  final int monthsRemaining;
  final String fulfillment;
  final String note;
  final String status;
  final String rejectionReason;
  final double? rating;
  final String review;
  final bool overdue;
  final int? daysLeft;
  final DateTime? createdAt;

  Rental({
    required this.id,
    required this.tool,
    required this.type,
    required this.status,
    required this.totalCost,
    this.renter,
    this.supplier,
    this.startDate,
    this.endDate,
    this.days = 0,
    this.deposit = 0,
    this.monthsRemaining = 0,
    this.fulfillment = 'pickup',
    this.note = '',
    this.rejectionReason = '',
    this.rating,
    this.review = '',
    this.overdue = false,
    this.daysLeft,
    this.createdAt,
  });

  bool get isInstallment => type == 'installment';
  bool get isOpen => status == 'requested' || status == 'active';
  bool get canReview => (status == 'returned' || status == 'completed') && rating == null;

  factory Rental.fromJson(Map<String, dynamic> json) => Rental(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        tool: RentalTool.fromAny(json['tool']),
        renter: UserLite.fromAny(json['renter']),
        supplier: UserLite.fromAny(json['supplier']),
        type: (json['type'] ?? 'rent').toString(),
        startDate: _date(json['startDate']),
        endDate: _date(json['endDate']),
        days: _i(json['days']),
        totalCost: _d(json['totalCost']),
        deposit: _d(json['deposit']),
        monthsRemaining: _i(json['monthsRemaining']),
        fulfillment: (json['fulfillment'] ?? 'pickup').toString(),
        note: (json['note'] ?? '').toString(),
        status: (json['status'] ?? 'requested').toString(),
        rejectionReason: (json['rejectionReason'] ?? '').toString(),
        rating: json['rating'] == null ? null : _d(json['rating']),
        review: (json['review'] ?? '').toString(),
        overdue: json['overdue'] == true,
        daysLeft: json['daysLeft'] == null ? null : _i(json['daysLeft']),
        createdAt: _date(json['createdAt']),
      );
}
