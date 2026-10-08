import 'package:flutter/material.dart';

import '../../models/rental.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/cards.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import 'tool_detail_screen.dart';

/// Rentals and installment plans the signed-in user has requested.
class MyRentalsScreen extends StatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  State<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentalsScreen> {
  final _current = GlobalKey<AsyncListState<Rental>>();
  final _past = GlobalKey<AsyncListState<Rental>>();
  final _updates = RealtimeService.instance.on({'rental:update'});

  Future<List<Rental>> _load(String statuses) async {
    final res = await ApiClient.getList('/api/rentals', query: {'status': statuses});
    return res.map(Rental.fromJson).toList();
  }

  void _reload() {
    _current.currentState?.reload();
    _past.currentState?.reload();
  }

  Future<void> _cancel(Rental r) async {
    final ok = await confirmDialog(context, title: 'Cancel this request?', confirm: 'Cancel request', cancel: 'Keep', destructive: true);
    if (!ok) return;
    try {
      await ApiClient.post('/api/rentals/${r.id}/cancel');
      toast('Request cancelled');
      _reload();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _review(Rental r) async {
    final res = await showRatingSheet(context, title: 'Rate ${r.tool.name}', subtitle: 'How was the tool and the supplier?');
    if (res == null) return;
    try {
      await ApiClient.post('/api/rentals/${r.id}/review', {'rating': res.rating, 'review': res.review});
      toast('Thanks for the review!', kind: ToastKind.success);
      _reload();
    } catch (e) {
      toastError(e);
    }
  }

  Widget _card(BuildContext context, Rental r) => RentalCard(
        rental: r,
        perspective: 'renter',
        onTap: r.tool.id.isEmpty ? null : () => push(context, ToolDetailScreen(toolId: r.tool.id)),
        actions: [
          if (r.status == 'requested')
            OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _cancel(r),
                child: const Text('Cancel request')),
          if (r.canReview)
            FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _review(r),
                child: const Text('Leave a review')),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My rentals'),
          bottom: const TabBar(tabs: [Tab(text: 'Current'), Tab(text: 'History')]),
        ),
        body: TabBarView(children: [
          AsyncList<Rental>(
            key: _current,
            load: () => _load('requested,active'),
            reloadOn: _updates,
            empty: const EmptyState(
                icon: Icons.handyman_outlined,
                title: 'No current rentals',
                message: 'Rent a tool from the Tools tab — requests show up here.'),
            itemBuilder: (c, r, _) => _card(c, r),
          ),
          AsyncList<Rental>(
            key: _past,
            load: () => _load('returned,completed,rejected,cancelled'),
            reloadOn: _updates,
            empty: const EmptyState(icon: Icons.history_rounded, title: 'No past rentals yet'),
            itemBuilder: (c, r, _) => _card(c, r),
          ),
        ]),
      ),
    );
  }
}
