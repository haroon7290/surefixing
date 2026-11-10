import 'package:flutter/material.dart';

import '../../kit.dart';
import '../shell/shell.dart';
import '../site/info_pages.dart';
import 'edit_profile_screen.dart';
import 'kyc_screen.dart';

/// Profile, shortcuts, settings and support.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _changePhoto(BuildContext context) async {
    final file = await pickPhoto(context);
    if (file == null) return;
    try {
      await Session.instance.uploadAvatar(file);
      toastOk('Profile photo updated');
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final form = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    var busy = false;
    await showAppSheet<void>(
      context,
      title: 'Change password',
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PasswordField(label: 'Current password', controller: current, validator: requiredField('Enter your current password')),
            Gap.h16,
            PasswordField(label: 'New password', hint: 'At least 6 characters', controller: next, validator: validPassword, isNew: true, action: TextInputAction.done),
            Gap.h20,
            Btn('Change password', size: BtnSize.lg, expand: true, loading: busy, onPressed: () async {
              if (!(form.currentState?.validate() ?? false)) return;
              setState(() => busy = true);
              try {
                await Session.instance.changePassword(current.text, next.text);
                toastOk('Password changed');
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                toastError(e);
                if (context.mounted) setState(() => busy = false);
              }
            }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Session.instance, Settings.instance]),
        builder: (context, _) {
          final user = Session.instance.user;
          if (user == null) return const SizedBox.shrink();
          final c = context.colors;
          final wide = context.isWide;
          final kyc = kycStatus(user.kycStatus);
          final shortcuts = destinationsFor(user.role).where((d) => !d.dock && d.key != 'account').toList();

          final profile = Panel(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Semantics(
                  button: true,
                  label: 'Change profile photo',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => _changePhoto(context),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Avatar(name: user.name, image: user.avatar, size: 76),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2.5)),
                          child: Icon(AppIcons.camera, size: 14, color: c.canvas),
                        ),
                      ),
                    ]),
                  ),
                ),
                Gap.w16,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Flexible(child: Text(user.name, style: context.text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (user.verified) ...[Gap.w6, const VerifiedTick(size: 20)],
                    ]),
                    Gap.h2,
                    Text(user.email, style: context.text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Gap.h8,
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      Pill(roleLabels[user.role] ?? user.role, tone: Tone.brand),
                      if (user.city.isNotEmpty) Pill(user.city, icon: AppIcons.pin),
                    ]),
                  ]),
                ),
              ]),
              if (user.isTechnician) ...[
                Gap.h16,
                const Divider(),
                Gap.h12,
                Row(children: [
                  Expanded(child: _Figure(user.ratingCount == 0 ? 'New' : user.rating.toStringAsFixed(1), 'Rating')),
                  Expanded(child: _Figure(count(user.jobsCompleted), 'Jobs done')),
                  Expanded(child: _Figure(user.completionRate == null ? '—' : '${(user.completionRate! * 100).round()}%', 'Completion')),
                ]),
              ],
              Gap.h16,
              Btn('Edit profile', icon: AppIcons.edit, kind: BtnKind.dark, expand: true, onPressed: () => push(context, const EditProfileScreen())),
            ]),
          );

          final groups = <Widget>[
            if (!wide && shortcuts.isNotEmpty) ...[
              const SectionTitle('Your SureFix', top: 20),
              MenuGroup(children: [
                for (final d in shortcuts)
                  d.badge == null
                      ? MenuRow(icon: d.icon, title: d.label, onTap: () => openSection(context, d.key))
                      : ValueListenableBuilder<int>(
                          valueListenable: d.badge!,
                          builder: (context, n, _) => MenuRow(icon: d.icon, title: d.label, badge: n, onTap: () => openSection(context, d.key)),
                        ),
              ]),
            ],
            if (!user.isAdmin && !user.isClient) ...[
              const SectionTitle('Trust', top: 20),
              MenuGroup(children: [
                MenuRow(
                  icon: AppIcons.verify,
                  tone: kyc.$2 == Tone.neutral ? Tone.brand : kyc.$2,
                  title: 'Identity verification',
                  subtitle: user.verified ? 'Your profile shows the verified seal' : 'Verified profiles win more work',
                  trailing: Pill.status(kyc),
                  onTap: () => push(context, const KycScreen()),
                ),
              ]),
            ],
            const SectionTitle('Settings', top: 20),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  IconTile(context.isDark ? AppIcons.moon : AppIcons.sun, size: 40),
                  Gap.w12,
                  Text('Appearance', style: context.text.titleSmall!.copyWith(fontSize: 14.5)),
                ]),
                Gap.h12,
                Segmented<ThemeMode>(
                  options: const {ThemeMode.system: 'Auto', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'},
                  value: Settings.instance.themeMode,
                  onChanged: Settings.instance.setThemeMode,
                ),
              ]),
            ),
            Gap.h12,
            MenuGroup(children: [MenuRow(icon: AppIcons.lock, title: 'Change password', onTap: () => _changePassword(context))]),
            const SectionTitle('Support', top: 20),
            MenuGroup(children: [
              MenuRow(icon: AppIcons.help, title: 'Help & FAQ', subtitle: 'Payments, rentals, verification', onTap: () => push(context, const HelpPage())),
              MenuRow(icon: AppIcons.document, title: 'Terms of use', onTap: () => push(context, const LegalPage())),
              MenuRow(icon: AppIcons.shield, title: 'Privacy', onTap: () => push(context, const LegalPage(privacy: true))),
            ]),
            Gap.h20,
            Btn('Sign out', icon: AppIcons.logout, kind: BtnKind.danger, expand: true, onPressed: () async {
              if (await confirm(context, title: 'Sign out?', message: 'You can sign back in any time.', confirmLabel: 'Sign out', icon: AppIcons.logout)) Session.instance.logout();
            }),
            Gap.h16,
            Center(child: Text('SureFix 3.0  ·  Member since ${shortDate(user.createdAt)}', style: context.text.bodySmall)),
          ];

          return AppPage(
            title: 'Account',
            body: PageList(children: [
              TwoCol(
                sideWidth: 420,
                sideFirstOnPhone: true,
                side: profile,
                main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: wide ? groups.skip(0).toList() : groups),
              ),
            ]),
          );
        },
      );
}

class _Figure extends StatelessWidget {
  final String value;
  final String label;
  const _Figure(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: context.text.titleLarge),
        Text(label, style: context.text.bodySmall!.copyWith(fontSize: 11.5)),
      ]);
}
