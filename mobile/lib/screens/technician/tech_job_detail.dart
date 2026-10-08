import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/job_image_gallery.dart';
import '../shared/messages_screen.dart';

class TechJobDetail extends StatefulWidget {
  final String jobId;
  const TechJobDetail({super.key, required this.jobId});

  @override
  State<TechJobDetail> createState() => _TechJobDetailState();
}

class _TechJobDetailState extends State<TechJobDetail> {
  Job? _job;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/jobs/${widget.jobId}');
      setState(() => _job = Job.fromJson(Map<String, dynamic>.from(res)));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _placeBid() async {
    final amount = TextEditingController();
    final eta = TextEditingController(text: '1');
    final msg = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Place a bid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (\$)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: eta,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ETA (days)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: msg,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Message (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );
    if (confirmed != true) return;
    final amt = double.tryParse(amount.text);
    if (amt == null || amt <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid amount must be greater than zero')),
      );
      return;
    }
    try {
      await ApiClient.post('/api/jobs/${widget.jobId}/bids', {
        'amount': amt,
        'etaDays': int.tryParse(eta.text) ?? 1,
        'message': msg.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bid placed: \$${amt.toStringAsFixed(2)}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancelBid() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel your bid?'),
        content: const Text('You can place a new bid later as long as the job is still pending.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel bid')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.delete('/api/jobs/${widget.jobId}/bids/me');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid cancelled')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await ApiClient.patch('/api/jobs/${widget.jobId}/status', {'status': status});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated: $status')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meId = AuthService.instance.user!.id;
    if (_loading || _job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final j = _job!;
    final myBid = j.bids.where((b) => b.technicianId == meId).toList();
    final isAssignedToMe = j.technicianId == meId;
    return Scaffold(
      appBar: AppBar(
        title: Text(j.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (isAssignedToMe)
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessagesScreen(
                    jobId: j.id,
                    jobTitle: j.title,
                    counterpartyName: j.clientName,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
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
          const SizedBox(height: 8),
          Text('Posted by ${j.clientName}'),
          const SizedBox(height: 24),
          if (j.status == 'pending' && myBid.isEmpty)
            FilledButton(onPressed: _placeBid, child: const Text('Place bid')),
          if (myBid.isNotEmpty) ...[
            Card(
              color: Colors.indigo.withOpacity(0.05),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.gavel, color: Colors.indigo),
                    title: Text('Your bid: \$${myBid.first.amount.toStringAsFixed(2)}'),
                    subtitle: Text('ETA ${myBid.first.etaDays}d'
                        '${myBid.first.message.isNotEmpty ? ' · ${myBid.first.message}' : ''}'),
                    trailing: StatusChip(myBid.first.status),
                  ),
                  if (myBid.first.status == 'pending' && j.status == 'pending')
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 8),
                        child: TextButton.icon(
                          onPressed: _cancelBid,
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel bid'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (isAssignedToMe && j.status == 'in_progress') ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _updateStatus('completed'),
              child: const Text('Mark completed'),
            ),
          ],
          if (j.status == 'pending') ...(() {
            final others = j.bids.where((b) => b.technicianId != meId).toList();
            if (others.isEmpty) return const <Widget>[];
            return [
              const SizedBox(height: 24),
              Text('Other bids on this job (${others.length})',
                  style: Theme.of(context).textTheme.titleSmall),
              ...others.map((b) => ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(b.technicianName.isEmpty ? 'Technician' : b.technicianName),
                    subtitle: Text('ETA ${b.etaDays}d'),
                    trailing: Text('\$${b.amount.toStringAsFixed(0)}'),
                  )),
            ];
          })(),
        ],
      ),
    );
  }
}