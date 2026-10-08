import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/pills.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import '../shared/technician_profile_screen.dart';

class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  final _search = TextEditingController();
  String _role = '';
  String _status = '';
  List<User>? _users;
  Object? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.getList('/api/admin/users', query: {'q': _search.text.trim(), 'role': _role, 'status': _status});
      if (mounted) {
        setState(() {
          _users = res.map(User.fromJson).toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _setStatus(User u, String status) async {
    final suspend = status == 'suspended';
    final ok = await confirmDialog(
      context,
      title: suspend ? 'Suspend ${u.name}?' : 'Reactivate ${u.name}?',
      message:
          suspend ? 'They\'ll be logged out immediately and can\'t use SureFix until reactivated.' : 'They\'ll be able to log in again.',
      confirm: suspend ? 'Suspend' : 'Reactivate',
      destructive: suspend,
    );
    if (!ok) return;
    try {
      await ApiClient.patch('/api/admin/users/${u.id}/status', {'status': status});
      toast(suspend ? 'Account suspended' : 'Account reactivated', kind: ToastKind.success);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _delete(User u) async {
    final ok = await confirmDialog(context,
        title: 'Delete ${u.name}?',
        message: 'This permanently removes the account. Consider suspending instead.',
        confirm: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ApiClient.delete('/api/admin/users/${u.id}');
      toast('User deleted');
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  void _details(User u) {
    final me = AuthService.instance.user!.id;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AppAvatar(name: u.name, url: u.avatar, size: 56, online: u.online),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: ctx.text.titleLarge),
                  Text(u.email, style: TextStyle(color: ctx.palette.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Pill(Fmt.titleCase(u.role), color: ctx.colors.primary),
              StatusPill(u.isSuspended ? 'suspended' : (u.kycStatus == 'pending' ? 'requested' : u.kycStatus)),
            ]),
            const SizedBox(height: 8),
            if ((u.phone ?? '').isNotEmpty) InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: u.phone!),
            if (u.city.isNotEmpty) InfoRow(icon: Icons.location_city_outlined, label: 'City', value: u.city),
            InfoRow(icon: Icons.calendar_month_outlined, label: 'Joined', value: Fmt.date(u.createdAt)),
            if (u.isTechnician)
              InfoRow(
                  icon: Icons.star_outline_rounded,
                  label: 'Rating',
                  value: '${u.rating.toStringAsFixed(1)} (${u.ratingCount}) · ${u.jobsCompleted} jobs'),
            const SizedBox(height: 12),
            if (u.id != me)
              Row(children: [
                if (u.isTechnician) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        push(context, TechnicianProfileScreen(technicianId: u.id));
                      },
                      child: const Text('Profile'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: u.isSuspended ? ctx.palette.success : ctx.palette.warning),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setStatus(u, u.isSuspended ? 'active' : 'suspended');
                    },
                    child: Text(u.isSuspended ? 'Reactivate' : 'Suspend'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Delete',
                  color: ctx.palette.danger,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _delete(u);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.user!.id;
    final users = _users;
    return Scaffold(
      appBar: AppBar(title: Text('Users${users == null ? '' : ' (${users.length})'}')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _load);
            },
            decoration:
                const InputDecoration(hintText: 'Search name, email, phone, city', prefixIcon: Icon(Icons.search_rounded), isDense: true),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final r in const [
              ('', 'All'),
              ('client', 'Clients'),
              ('technician', 'Technicians'),
              ('supplier', 'Suppliers'),
              ('admin', 'Admins')
            ]) ...[
              ChoiceChip(
                label: Text(r.$2),
                selected: _role == r.$1,
                onSelected: (_) {
                  setState(() => _role = r.$1);
                  _load();
                },
              ),
              const SizedBox(width: 6),
            ],
            FilterChip(
              label: const Text('Suspended'),
              selected: _status == 'suspended',
              onSelected: (v) {
                setState(() => _status = v ? 'suspended' : '');
                _load();
              },
            ),
          ]),
        ),
        Expanded(
          child: users == null
              ? (_error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: users.isEmpty
                      ? ListView(
                          children: const [SizedBox(height: 60), EmptyState(icon: Icons.person_search_rounded, title: 'No users found')])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: users.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final u = users[i];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: AppAvatar(name: u.name, url: u.avatar, size: 44, online: u.online, verified: u.isVerified),
                                title: Row(children: [
                                  Flexible(
                                      child: Text(u.name,
                                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  if (u.id == me) ...[const SizedBox(width: 6), Pill('You', color: context.colors.primary)],
                                ]),
                                subtitle: Text('${Fmt.titleCase(u.role)} · ${u.email}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: u.isSuspended ? const StatusPill('suspended') : const Icon(Icons.chevron_right_rounded),
                                onTap: () => _details(u),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ]),
    );
  }
}
