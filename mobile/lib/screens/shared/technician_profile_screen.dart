import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';

/// Read-only profile view for a technician, reachable by a client either
/// from the technician directory or from a bid on their job. Shows the
/// technician's stats plus every rating/review left on their completed jobs.
class TechnicianProfileScreen extends StatefulWidget {
  final String technicianId;
  const TechnicianProfileScreen({super.key, required this.technicianId});

  @override
  State<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ApiClient.get('/api/users/${widget.technicianId}');
      final reviews = await ApiClient.get('/api/reviews/technician/${widget.technicianId}') as List;
      if (!mounted) return;
      setState(() {
        _profile = Map<String, dynamic>.from(profile);
        _reviews = reviews;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_profile?['name'] ?? 'Technician')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ProfileHeader(profile: _profile!),
                      const SizedBox(height: 24),
                      Text('Reviews (${_reviews.length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No reviews yet.', style: TextStyle(color: Colors.black54)),
                        ),
                      ..._reviews.map((r) => _ReviewCard(review: Map<String, dynamic>.from(r))),
                    ],
                  ),
                ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rating = (profile['rating'] ?? 0).toDouble();
    final ratingCount = profile['ratingCount'] ?? 0;
    final jobsCompleted = profile['jobsCompleted'] ?? 0;
    final skills = (profile['skills'] as List?)?.cast<String>() ?? [];
    final bio = (profile['bio'] ?? '') as String;
    final kycApproved = profile['kycStatus'] == 'approved';
    final avatar = (profile['avatar'] ?? '') as String;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.indigo.withOpacity(0.1),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(ApiConfig.mediaUrl(avatar)) : null,
                  child: avatar.isEmpty
                      ? Text(
                          (profile['name'] ?? '?').toString().isNotEmpty
                              ? profile['name'][0].toString().toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 24, color: Colors.indigo),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(profile['name'] ?? '',
                                style: Theme.of(context).textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (kycApproved)
                            const Tooltip(
                              message: 'ID verified',
                              child: Icon(Icons.verified, color: Colors.blue, size: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text('${rating.toStringAsFixed(1)} ($ratingCount reviews)'),
                        ],
                      ),
                      Text('$jobsCompleted jobs completed', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(bio),
            ],
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills
                    .map((s) => Chip(
                          label: Text(s),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.indigo.withOpacity(0.08),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] ?? 0).toDouble();
    final text = (review['review'] ?? '') as String;
    final clientName = review['clientName'] ?? 'Client';
    final jobTitle = review['jobTitle'] ?? '';
    String dateLabel = '';
    if (review['date'] != null) {
      final parsed = DateTime.tryParse(review['date'].toString());
      if (parsed != null) dateLabel = DateFormat.yMMMd().format(parsed);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating.round() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            if (jobTitle.isNotEmpty || dateLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [if (jobTitle.isNotEmpty) jobTitle, if (dateLabel.isNotEmpty) dateLabel].join(' · '),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(text),
            ],
          ],
        ),
      ),
    );
  }
}