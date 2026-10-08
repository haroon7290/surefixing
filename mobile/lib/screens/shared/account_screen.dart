import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/navigation.dart';
import '../../services/settings_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/media.dart';
import '../../widgets/pills.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/visuals.dart';
import '../admin/admin_jobs.dart';
import '../admin/admin_tools.dart';
import 'about_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'kyc_screen.dart';
import 'my_rentals_screen.dart';
import 'notifications_screen.dart';
import 'technician_profile_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _changePhoto(BuildContext context) async {
    final file = await pickImage(context, maxWidth: 800);
    if (file == null) return;
    try {
      await AuthService.instance.uploadAvatar(file);
      toast('Profile photo updated', kind: ToastKind.success);
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(context, title: 'Log out?', confirm: 'Log out');
    if (ok) await AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.user;
        if (user == null) return const SizedBox.shrink();
        final p = context.palette;
        final roleLabel = switch (user.role) {
          'technician' => 'Technician',
          'supplier' => 'Tool supplier',
          'admin' => 'Administrator',
          _ => 'Client',
        };
        return Scaffold(
          appBar: AppBar(title: const Text('Account')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => _changePhoto(context),
                      child: Stack(children: [
                        AppAvatar(name: user.name, url: user.avatar, size: 68),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                color: context.colors.primary, shape: BoxShape.circle, border: Border.all(color: p.card, width: 2)),
                            child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(user.name, overflow: TextOverflow.ellipsis, style: context.text.titleLarge)),
                          if (user.isVerified) ...[const SizedBox(width: 6), const VerifiedBadge(size: 18)],
                        ]),
                        Text(user.email, style: TextStyle(color: p.muted, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          Pill(roleLabel, color: context.colors.primary),
                          if (user.isTechnician) RatingLabel(rating: user.rating, count: user.ratingCount, size: 12.5),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
              if (user.isTechnician || user.isSupplier) ...[
                const SizedBox(height: 12),
                _ProfileStrength(value: user.profileCompleteness),
              ],
              const SizedBox(height: 8),
              _group(context, 'Profile', [
                _tile(context, Icons.person_outline_rounded, 'Edit profile', onTap: () => push(context, const EditProfileScreen())),
                if (user.isTechnician)
                  _tile(context, Icons.visibility_outlined, 'View my public profile',
                      onTap: () => push(context, TechnicianProfileScreen(technicianId: user.id))),
                if (user.isTechnician || user.isSupplier)
                  _tile(context, Icons.verified_user_outlined, 'Identity verification',
                      trailing: StatusPill(user.kycStatus == 'pending' ? 'requested' : user.kycStatus),
                      onTap: () => push(context, const KycScreen())),
              ]),
              _group(context, 'Activity', [
                _tile(context, Icons.notifications_none_rounded, 'Notifications',
                    trailing: ValueListenableBuilder<int>(
                      valueListenable: BadgeService.instance.unreadNotifications,
                      builder: (_, n, __) =>
                          n == 0 ? const Icon(Icons.chevron_right_rounded) : Pill('$n new', color: p.danger, solid: true),
                    ),
                    onTap: () => push(context, const NotificationsScreen())),
                if (user.isClient || user.isTechnician)
                  _tile(context, Icons.receipt_long_outlined, 'My tool rentals', onTap: () => push(context, const MyRentalsScreen())),
                if (user.isAdmin) ...[
                  _tile(context, Icons.work_outline_rounded, 'All jobs', onTap: () => push(context, const AdminJobs())),
                  _tile(context, Icons.handyman_outlined, 'All tools', onTap: () => push(context, const AdminTools())),
                ],
              ]),
              _group(context, 'Preferences', [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    Icon(Icons.dark_mode_outlined, color: p.muted),
                    const SizedBox(width: 16),
                    const Expanded(child: Text('Theme', style: TextStyle(fontWeight: FontWeight.w600))),
                    ListenableBuilder(
                      listenable: SettingsService.instance,
                      builder: (_, __) => SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18)),
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined, size: 18)),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18)),
                        ],
                        selected: {SettingsService.instance.themeMode},
                        onSelectionChanged: (s) => SettingsService.instance.setThemeMode(s.first),
                      ),
                    ),
                  ]),
                ),
                _tile(context, Icons.lock_outline_rounded, 'Change password', onTap: () => push(context, const ChangePasswordScreen())),
                _tile(context, Icons.info_outline_rounded, 'About SureFix', onTap: () => push(context, const AboutScreen())),
              ]),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: p.danger, side: BorderSide(color: p.danger.withValues(alpha: 0.4))),
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 18, 0, 8),
            child: Text(title.toUpperCase(),
                style: TextStyle(color: context.palette.subtle, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 56), children[i]],
            ]),
          ),
        ],
      );

  Widget _tile(BuildContext context, IconData icon, String title, {Widget? trailing, VoidCallback? onTap}) => ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        shape: const RoundedRectangleBorder(),
      );
}

class _ProfileStrength extends StatelessWidget {
  final double value;
  const _ProfileStrength({required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    final done = pct >= 100;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: done ? null : () => push(context, const EditProfileScreen()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            MatchRing(percent: pct, size: 52, label: ''),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(done ? 'Profile complete' : 'Complete your profile', style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  done
                      ? 'Great — complete profiles rank higher in Smart Match.'
                      : 'A photo, headline, skills and rate help you rank higher in Smart Match.',
                  style: TextStyle(color: context.palette.muted, fontSize: 13),
                ),
              ]),
            ),
            if (!done) const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }
}
