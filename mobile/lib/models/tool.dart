import 'user.dart';

double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class ToolReview {
  final double rating;
  final String review;
  final String renterName;
  final String renterAvatar;
  final DateTime? date;

  ToolReview({required this.rating, required this.review, required this.renterName, required this.renterAvatar, this.date});

  factory ToolReview.fromJson(Map<String, dynamic> j) => ToolReview(
        rating: _d(j['rating']),
        review: (j['review'] ?? '').toString(),
        renterName: (j['renterName'] ?? 'Customer').toString(),
        renterAvatar: (j['renterAvatar'] ?? '').toString(),
        date: _date(j['date']),
      );
}

class Tool {
  final String id;
  final UserLite supplier;
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
  final List<ToolReview> reviews;

  Tool({
    required this.id,
    required this.supplier,
    required this.name,
    required this.description,
    required this.category,
    required this.rentPricePerDay,
    required this.purchasePrice,
    required this.installmentMonths,
    required this.installmentMonthly,
    required this.available,
    required this.stock,
    this.condition = 'good',
    this.city = '',
    this.images = const [],
    this.deposit = 0,
    this.rating = 0,
    this.ratingCount = 0,
    this.rentalsCount = 0,
    this.reviews = const [],
  });

  String get supplierId => supplier.id;
  String get supplierName => supplier.name;
  bool get inStock => available && stock > 0;
  bool get hasInstallments => installmentMonths > 0;
  String get coverImage => images.isNotEmpty ? images.first : '';

  factory Tool.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List? ?? const []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    final legacy = (json['image'] ?? '').toString();
    if (images.isEmpty && legacy.isNotEmpty) images.add(legacy);
    return Tool(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      supplier: UserLite.fromAny(json['supplier']) ?? const UserLite(id: ''),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'general').toString(),
      condition: (json['condition'] ?? 'good').toString(),
      city: (json['city'] ?? '').toString(),
      images: images,
      rentPricePerDay: _d(json['rentPricePerDay']),
      deposit: _d(json['deposit']),
      purchasePrice: _d(json['purchasePrice']),
      installmentMonths: _i(json['installmentMonths']),
      installmentMonthly: _d(json['installmentMonthly']),
      available: json['available'] != false,
      stock: _i(json['stock'], 1),
      rating: _d(json['rating']),
      ratingCount: _i(json['ratingCount']),
      rentalsCount: _i(json['rentalsCount']),
      reviews:
          (json['reviews'] as List? ?? const []).whereType<Map>().map((r) => ToolReview.fromJson(Map<String, dynamic>.from(r))).toList(),
    );
  }
}
