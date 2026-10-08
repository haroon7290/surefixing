class Tool {
  final String id;
  final String supplierId;
  final String supplierName;
  final String name;
  final String description;
  final String category;
  final double rentPricePerDay;
  final double purchasePrice;
  final int installmentMonths;
  final double installmentMonthly;
  final bool available;
  final int stock;

  Tool({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.name,
    required this.description,
    required this.category,
    required this.rentPricePerDay,
    required this.purchasePrice,
    required this.installmentMonths,
    required this.installmentMonthly,
    required this.available,
    required this.stock,
  });

  factory Tool.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'];
    String supplierId = '';
    String supplierName = '';
    if (supplier is Map) {
      supplierId = (supplier['_id'] ?? supplier['id'] ?? '').toString();
      supplierName = supplier['name']?.toString() ?? '';
    } else if (supplier != null) {
      supplierId = supplier.toString();
    }
    return Tool(
      id: (json['_id'] ?? json['id']).toString(),
      supplierId: supplierId,
      supplierName: supplierName,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      rentPricePerDay: (json['rentPricePerDay'] ?? 0).toDouble(),
      purchasePrice: (json['purchasePrice'] ?? 0).toDouble(),
      installmentMonths: json['installmentMonths'] ?? 0,
      installmentMonthly: (json['installmentMonthly'] ?? 0).toDouble(),
      available: json['available'] ?? true,
      stock: json['stock'] ?? 1,
    );
  }
}
