import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../models/tool.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/brand.dart';
import '../../widgets/cards.dart';
import '../../widgets/pills.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import '../shared/notifications_screen.dart';
import '../shared/technician_profile_screen.dart';
import '../shared/technicians_list_screen.dart';
import '../shared/tool_detail_screen.dart';
import '../shells.dart';
import 'job_detail_client.dart';
import 'post_job_screen.dart';
import 'smart_match_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  List<Job>? _jobs;
  List<User>? _techs;
  List<Tool>? _tools;
  StreamSubscription? _sub;

  static const _suggestions = ['Leaking tap', 'AC not cooling', 'Install ceiling fan', 'Deep cleaning', 'Locked out'];

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.on({'job:bid', 'job:status', 'job:rated', 'job:hired'}).listen((_) => _loadJobs());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() => Future.wait([_loadJobs(), _loadTechs(), _loadTools()]);

  Future<void> _loadJobs() async {
    try {
      final res = await ApiClient.getList('/api/jobs', query: {'mine': '1'});
      if (mounted) setState(() => _jobs = res.map(Job.fromJson).where((j) => j.isActive).take(3).toList());
    } catch (_) {
      if (mounted) setState(() => _jobs ??= []);
    }
  }

  Future<void> _loadTechs() async {
    try {
      final res = await ApiClient.getList('/api/users/technicians', query: {'sort': 'rating', 'limit': '10'});
      if (mounted) setState(() => _techs = res.map(User.fromJson).toList());
    } catch (_) {
      if (mounted) setState(() => _techs ??= []);
    }
  }

  Future<void> _loadTools() async {
    try {
      final res = await ApiClient.getList('/api/tools', query: {'sort': 'popular', 'limit': '8', 'available': '1'});
      if (mounted) setState(() => _tools = res.map(Tool.fromJson).toList());
    } catch (_) {
      if (mounted) setState(() => _tools ??= []);
    }
  }

  Future<void> _postJob() async {
    final created = await push<bool>(context, const PostJobScreen());
    if (created == true) _loadJobs();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user!;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _hero(context, user)),
            SliverToBoxAdapter(
              child:
                  SectionHeader('Services', actionLabel: 'All technicians', onAction: () => push(context, const TechniciansListScreen())),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
                children: [
                  for (final c in Catalog.services.take(8))
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => push(context, TechniciansListScreen(category: c.key)),
                      child: Column(
                        children: [
                          CategoryIcon(c, size: 58),
                          const SizedBox(height: 8),
                          Text(c.label,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_jobs == null || _jobs!.isNotEmpty) ...[
              SliverToBoxAdapter(
                  child: SectionHeader('Your active jobs', actionLabel: 'See all', onAction: () => HomeShell.goTo(context, 1))),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: _jobs?.length ?? 2,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _jobs == null
                      ? const SkeletonCard()
                      : JobCard(
                          job: _jobs![i],
                          onTap: () async {
                            await push(context, JobDetailClient(jobId: _jobs![i].id));
                            _loadJobs();
                          },
                        ),
                ),
              ),
            ] else
              SliverToBoxAdapter(child: _firstJobCard(context)),
            SliverToBoxAdapter(
              child: SectionHeader('Top-rated technicians',
                  actionLabel: 'See all', onAction: () => push(context, const TechniciansListScreen())),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 186,
                child: _techs == null
                    ? ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, __) => const Skeleton(width: 156, height: 186, radius: 16),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _techs!.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => TechnicianTile(
                          tech: _techs![i],
                          onTap: () => push(context, TechnicianProfileScreen(technicianId: _techs![i].id)),
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader('Popular tool rentals', actionLabel: 'Browse', onAction: () => HomeShell.goTo(context, 2)),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _tools?.length ?? 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => SizedBox(
                    width: 168,
                    child: _tools == null
                        ? const Skeleton(height: 210, radius: 16)
                        : ToolCard(tool: _tools![i], onTap: () => push(context, ToolDetailScreen(toolId: _tools![i].id))),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'client-post-job',
        onPressed: _postJob,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Post a job'),
      ),
    );
  }

  Widget _hero(BuildContext context, User user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(name: user.name, url: user.avatar, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, ${user.firstName} 👋',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        if (user.city.isNotEmpty)
                          Row(children: [
                            Icon(Icons.place_rounded, size: 14, color: Colors.white.withValues(alpha: 0.75)),
                            const SizedBox(width: 2),
                            Text(user.city, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
                          ]),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    color: Colors.white,
                    onPressed: () async {
                      await push(context, const NotificationsScreen());
                      BadgeService.instance.refresh();
                    },
                    icon: BadgeIcon(icon: Icons.notifications_none_rounded, count: BadgeService.instance.unreadNotifications),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text('What needs fixing\ntoday?',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.6)),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => push(context, const SmartMatchScreen()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Brand.primary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Describe your problem…', style: TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w500)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Brand.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child:
                                const Text('AI match', style: TextStyle(color: Brand.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => push(context, SmartMatchScreen(initialText: _suggestions[i])),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Text(_suggestions[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _firstJobCard(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Brand.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.rocket_launch_rounded, color: Brand.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Post your first job', style: context.text.titleSmall),
                      const SizedBox(height: 2),
                      Text('Get quotes from verified technicians in minutes.',
                          style: TextStyle(color: context.palette.muted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton.filledTonal(onPressed: _postJob, icon: const Icon(Icons.arrow_forward_rounded)),
              ],
            ),
          ),
        ),
      );
}
