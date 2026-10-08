import 'package:flutter/material.dart';

import '../../models/rental.dart';
import '../../services/api_client.dart';
import '../../services/realtime_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import 'rental_actions.dart';

/// Supplier's rental pipeline: pending → active → history.
class RentalRequestsScreen extends StatefulWidget {
  /// True when pushed as its own page (e.g. from a notification).
  final bool standalone;
  const RentalRequestsScreen({super.key, this.standalone = false});

  @override
  State<RentalRequestsScreen> createState() => _RentalRequestsScreenState();
}

class _RentalRequestsScreenState extends State<RentalRequestsScreen> {
  final _updates = RealtimeService.instance.on({'rental:new', 'rental:update'});
  final _keys = List.generate(3, (_) => GlobalKey<AsyncListState<Rental>>());

  Future<List<Rental>> _load(String statuses) async =>
      (await ApiClient.getList('/api/rentals', query: {'as': 'supplier', 'status': statuses, 'limit': '100'}))
          .map(Rental.fromJson)
          .toList();

  void _reloadAll() {
    for (final k in _keys) {
      k.currentState?.reload();
    }
  }

  Widget _tab(int i, String statuses, Widget empty) => AsyncList<Rental>(
        key: _keys[i],
        load: () => _load(statuses),
        reloadOn: _updates,
        empty: empty,
        itemBuilder: (context, r, _) => RentalCard(rental: r, perspective: 'supplier', actions: rentalActions(context, r, _reloadAll)),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rental requests'),
          bottom: const TabBar(tabs: [Tab(text: 'Pending'), Tab(text: 'Active'), Tab(text: 'History')]),
        ),
        body: TabBarView(children: [
          _tab(
              0,
              'requested',
              const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No pending requests',
                  message: 'New rental and purchase requests appear here instantly.')),
          _tab(1, 'active', const EmptyState(icon: Icons.timelapse_rounded, title: 'Nothing out on rent')),
          _tab(2, 'returned,completed,rejected,cancelled', const EmptyState(icon: Icons.history_rounded, title: 'No history yet')),
        ]),
      ),
    );
  }
}
