import 'dart:async';

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';

/// Every account: search, filter by role, suspend, reactivate or delete.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _view = GlobalKey<AsyncViewState<List<User>>>();
  String _query = '';
  String _role = 'all';
  Timer? _debounce;

  static const _roles = {'all': 'Everyone', 'client': 'Customers', 'technician': 'Technicians', 'supplier': 'Suppliers', 'suspended': 'Suspended'};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _setStatus(User u, String status) async {
    if (status == 'suspended' &&
        !await confirm(context, title: 'Suspend ${u.name}?', message: 'They are signed out and cannot log in until you reactivate the account.', confirmLabel: 'Suspend', danger: true, icon: AppIcons.blocked)) {
      return;
    }
    try {
      await Api.patch('/api/admin/users/${u.id}/status', {'status': status});
      toastOk(status == 'suspended' ? '${u.name} is suspended' : '${u.name} is active again');
      _view.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _delete(User u) async {
    if (!await confirm(
      context,
      title: 'Delete ${u.name}?',
      message: 'Their tools, pending jobs, messages and verification are removed for good. Accounts with a job in progress or a tool out on rent cannot be deleted.',
      confirmLabel: 'Delete account',
      danger: true,
      icon: AppIcons.trash,
    )) {
      return;
    }
    try {
      await Api.delete('/api/admin/users/${u.id}');
      toast('${u.name} was deleted');
      _view.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final me = Session.instance.user?.id;
    return AppPage(
      title: 'Users',
      subtitle: 'Search, review and moderate every account.',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PagePad(
          child: SearchBox(
            hint: 'Search by name, email, phone or city',
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
            },
          ),
        ),
        PagePad(child: Pills<String>(scroll: true, values: _roles.keys.toList(), label: (k) => _roles[k]!, selected: _role, onTap: (k) => setState(() => _role = k))),
        Expanded(
          child: AsyncView<List<User>>(
            key: _view,
            token: '$_query|$_role',
            load: () async => (await Api.list('/api/admin/users', query: {
              'q': _query,
              'role': _role == 'all' || _role == 'suspended' ? null : _role,
              'status': _role == 'suspended' ? 'suspended' : null,
              'limit': 150,
            }))
                .map(User.fromJson)
                .toList(),
            builder: (context, users) => users.isEmpty
                ? const EmptyState(icon: AppIcons.users, title: 'No accounts match')
                : PageList(
                    onRefresh: () => _view.currentState!.reload(),
                    children: [
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(plural(users.length, 'account'), style: context.text.bodySmall)),
                      Panel(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < users.length; i++) ...[
                            if (i > 0) Divider(indent: 72, color: c.line),
                            Builder(builder: (context) {
                              final u = users[i];
                              final public = u.isTechnician || u.isSupplier;
                              return InkWell(
                                onTap: public ? () => openTechnician(context, u.id) : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(children: [
                                    Avatar(name: u.name, image: u.avatar, size: 44, online: u.online),
                                    Gap.w12,
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                        Row(children: [
                                          Flexible(child: Text(u.name, style: context.text.titleSmall!.copyWith(fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          if (u.verified) ...[Gap.w4, const VerifiedTick(size: 14)],
                                        ]),
                                        Text([u.email, if (u.city.isNotEmpty) u.city].join('  ·  '), style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Gap.h4,
                                        Wrap(spacing: 6, runSpacing: 4, children: [
                                          Pill(roleLabels[u.role] ?? u.role, tone: u.isAdmin ? Tone.info : Tone.neutral),
                                          if (u.suspended) const Pill('Suspended', tone: Tone.danger, dot: true),
                                          if (context.isWide && !u.isAdmin) Pill('Wallet ${moneyCompact(u.walletBalance)}'),
                                          if (context.isWide) Pill('Joined ${shortDate(u.createdAt)}'),
                                        ]),
                                      ]),
                                    ),
                                    if (u.id != me)
                                      PopupMenuButton<String>(
                                        tooltip: 'Actions for ${u.name}',
                                        icon: Icon(AppIcons.dots, size: 18, color: c.body),
                                        onSelected: (v) => switch (v) {
                                          'profile' => openTechnician(context, u.id),
                                          'delete' => _delete(u),
                                          _ => _setStatus(u, v),
                                        },
                                        itemBuilder: (_) => [
                                          if (public) const PopupMenuItem(value: 'profile', child: Text('View public profile')),
                                          u.suspended ? const PopupMenuItem(value: 'active', child: Text('Reactivate account')) : const PopupMenuItem(value: 'suspended', child: Text('Suspend account')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete account', style: TextStyle(color: c.danger))),
                                        ],
                                      ),
                                  ]),
                                ),
                              );
                            }),
                          ],
                        ]),
                      ),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }
}
