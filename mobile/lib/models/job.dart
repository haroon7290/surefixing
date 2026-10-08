class Bid {
  final String id;
  final String technicianId;
  final String technicianName;
  final double amount;
  final String message;
  final int etaDays;
  final String status;

  Bid({
    required this.id,
    required this.technicianId,
    required this.technicianName,
    required this.amount,
    required this.message,
    required this.etaDays,
    required this.status,
  });

  factory Bid.fromJson(Map<String, dynamic> json) {
    final tech = json['technician'];
    String techId = '';
    String techName = '';
    if (tech is Map) {
      techId = (tech['_id'] ?? tech['id'] ?? '').toString();
      techName = tech['name']?.toString() ?? '';
    } else if (tech != null) {
      techId = tech.toString();
    }
    return Bid(
      id: (json['_id'] ?? json['id']).toString(),
      technicianId: techId,
      technicianName: techName,
      amount: (json['amount'] ?? 0).toDouble(),
      message: json['message'] ?? '',
      etaDays: json['etaDays'] ?? 1,
      status: json['status'] ?? 'pending',
    );
  }
}

class Job {
  final String id;
  final String clientId;
  final String clientName;
  final String? technicianId;
  final String? technicianName;
  final String title;
  final String description;
  final String category;
  final double budget;
  final String location;
  final String status;
  final List<String> images;
  final List<Bid> bids;
  final double? rating;
  final String review;
  final DateTime createdAt;

  Job({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.title,
    required this.description,
    required this.category,
    required this.budget,
    required this.location,
    required this.status,
    required this.bids,
    required this.createdAt,
    this.images = const [],
    this.technicianId,
    this.technicianName,
    this.rating,
    this.review = '',
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final client = json['client'];
    final tech = json['assignedTechnician'];
    String clientId = '';
    String clientName = '';
    if (client is Map) {
      clientId = (client['_id'] ?? client['id'] ?? '').toString();
      clientName = client['name']?.toString() ?? '';
    } else if (client != null) {
      clientId = client.toString();
    }
    String? techId;
    String? techName;
    if (tech is Map) {
      techId = (tech['_id'] ?? tech['id'])?.toString();
      techName = tech['name']?.toString();
    } else if (tech != null) {
      techId = tech.toString();
    }
    final bids = (json['bids'] as List? ?? [])
        .map((b) => Bid.fromJson(Map<String, dynamic>.from(b)))
        .toList();
    return Job(
      id: (json['_id'] ?? json['id']).toString(),
      clientId: clientId,
      clientName: clientName,
      technicianId: techId,
      technicianName: techName,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      budget: (json['budget'] ?? 0).toDouble(),
      location: json['location'] ?? '',
      status: json['status'] ?? 'pending',
      images: (json['images'] as List? ?? []).map((e) => e.toString()).toList(),
      bids: bids,
      rating: json['rating']?.toDouble(),
      review: json['review'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}