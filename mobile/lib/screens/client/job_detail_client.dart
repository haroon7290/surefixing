import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/job_image_gallery.dart';
import '../shared/messages_screen.dart';
import '../shared/technician_profile_screen.dart';

class JobDetailClient extends StatefulWidget {
  final String jobId;
  const JobDetailClient({super.key, required this.jobId});

  @override
  State<JobDetailClient> createState() => _JobDetailClientState();
}

class _JobDetailClientState extends State<JobDetailClient> {
  Job? _job;
  List _rankedBids = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final job = await ApiClient.get('/api/jobs/${widget.jobId}');
      final ranked = await ApiClient.get('/api/jobs/${widget.jobId}/ranked-bids') as List;
      if (!mounted) return;
      setState(() {
        _job = Job.fromJson(Map<String, dynamic>.from(job));
        _rankedBids = ranked;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acceptBid(String bidId) async {
    try {
      await ApiClient.post('/api/jobs/${widget.jobId}/accept/$bidId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid accepted — technician hired')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _markComplete() async {
    try {
      await ApiClient.patch('/api/jobs/${widget.jobId}/status', {'status': 'completed'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job marked completed')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _rate() async {
    int rating = 5;
    final reviewCtl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rate the technician'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final v = i + 1;
                  return IconButton(
                    icon: Icon(v <= rating ? Icons.star : Icons.star_border, color: Colors.amber),
                    onPressed: () => setDialogState(() => rating = v),
                  );
                }),
              ),
              TextField(
                controller: reviewCtl,
                decoration: const InputDecoration(labelText: 'Review (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.post('/api/jobs/${widget.jobId}/rate',
          {'rating': rating, 'review': reviewCtl.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rating submitted: $rating★')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final j = _job!;
    return Scaffold(
      appBar: AppBar(
        title: Text(j.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (j.technicianId != null)
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessagesScreen(
                    jobId: j.id,
                    jobTitle: j.title,
                    counterpartyName: j.technicianName ?? 'Technician',
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [StatusChip(j.status), const Spacer(), Text('Budget \$${j.budget.toStringAsFixed(0)}')]),
            if (j.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              JobImageGallery(images: j.images),
            ],
            const SizedBox(height: 12),
            Text(j.description),
            if (j.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.place, size: 16), const SizedBox(width: 4), Text(j.location)]),
            ],
            const SizedBox(height: 16),
            if (j.status == 'in_progress')
              FilledButton(onPressed: _markComplete, child: const Text('Mark completed')),
            if (j.status == 'completed' && j.rating == null)
              FilledButton(onPressed: _rate, child: const Text('Rate & review')),
            if (j.rating != null)
              Text('You rated: ${j.rating!.toStringAsFixed(1)} ★'),
            const SizedBox(height: 24),
            Text('Bids (${_rankedBids.length}) — AI ranked',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_rankedBids.isEmpty) const Text('No bids yet. Technicians will appear here.'),
            ..._rankedBids.map((b) {
              final score = (b['score'] ?? 0).toDouble();
              final isAccepted = j.bids.any((x) => x.id == b['bidId'] && x.status == 'accepted');
              return Card(
                color: isAccepted ? Colors.green.withOpacity(0.08) : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TechnicianProfileScreen(
                                    technicianId: b['technicianId'],
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(b['name'] ?? 'Technician',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.black26,
                                        ),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.person_search, size: 14, color: Colors.black45),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('AI score ${score.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.indigo, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('\$${(b['amount'] ?? 0).toStringAsFixed(2)} · ETA ${b['etaDays'] ?? 1}d · '
                          '${(b['rating'] ?? 0).toStringAsFixed(1)}★ (${b['ratingCount'] ?? 0})'),
                      if ((b['message'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(b['message'], style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (j.status == 'pending')
                            FilledButton(
                              onPressed: () => _acceptBid(b['bidId']),
                              child: const Text('Accept bid'),
                            ),
                          if (isAccepted)
                            const Chip(label: Text('Accepted'), backgroundColor: Color(0xFFB9F6CA)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}