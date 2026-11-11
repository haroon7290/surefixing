import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kit.dart';
import '../jobs/job_widgets.dart';
import '../site/info_pages.dart';

/// Layout shared by the sign-in pages: on wide windows a dark brand panel
/// beside the form; on phones just the form.
class _AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _AuthLayout({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hosted = PageFrame.maybeOf(context) != null; // inside the public website
    final form = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, hosted ? 24 : 12, 20, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              if (!hosted) ...[const Align(alignment: Alignment.centerLeft, child: BrandLogo(size: 34)), Gap.h32],
              Text(title, style: context.text.displaySmall),
              Gap.h8,
              Text(subtitle, style: context.text.bodyLarge),
              Gap.h24,
              ...children,
            ]),
          ),
        ),
      ),
    );

    if (!context.isWide) {
      return hosted ? ColoredBox(color: c.canvas, child: form) : Scaffold(body: SafeArea(child: form));
    }
    return ColoredBox(
      color: c.canvas,
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 0, 28),
            child: HeroCard(
              padding: const EdgeInsets.all(44),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Spacer(),
                Text('Repairs you can\nbe sure about.', style: context.text.displayMedium!.copyWith(color: c.onHero)),
                Gap.h16,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text('Verified technicians, AI-ranked quotes, and payments that wait in escrow until the job is done.',
                      style: context.text.bodyLarge!.copyWith(color: c.onHeroMuted, fontSize: 17)),
                ),
                Gap.h32,
                for (final (icon, text) in const [
                  (AppIcons.sparkleFill, 'Match scores with plain-language reasons'),
                  (AppIcons.shieldFill, 'Escrow wallet: pay only for finished work'),
                  (AppIcons.toolsFill, 'Rent tools by the day, or buy monthly'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(children: [
                      Icon(icon, size: 20, color: c.brand),
                      Gap.w12,
                      Text(text, style: TextStyle(fontFamily: kBodyFont, fontSize: 15, fontWeight: FontWeight.w600, color: c.onHero)),
                    ]),
                  ),
                const Spacer(),
              ]),
            ),
          ),
        ),
        Expanded(flex: 6, child: form),
      ]),
    );
  }
}

class _SwitchLine extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;
  const _SwitchLine(this.question, this.action, this.onTap);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(question, style: context.text.bodyMedium),
          LinkText(action, onTap: onTap, color: context.colors.brandDeep),
        ]),
      );
}

// ------------------------------------------------------------------ login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  late final String? _ended = Session.instance.endedReason;

  // One-tap demo sign-in. Hide it in a real release with --dart-define=DEMO=false.
  static const _showDemo = bool.fromEnvironment('DEMO', defaultValue: true);

  static const _demo = [
    ('Customer', 'client@demo.com', AppIcons.home),
    ('Technician', 'tech@demo.com', AppIcons.technicians),
    ('Supplier', 'supplier@demo.com', AppIcons.tools),
    ('Admin', 'admin@demo.com', AppIcons.shield),
  ];

  @override
  void initState() {
    super.initState();
    Session.instance.endedReason = null;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.instance.login(_email.text, _password.text);
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _useDemo(String email) {
    _email.text = email;
    _password.text = 'password123';
    _submit();
  }

  @override
  Widget build(BuildContext context) => _AuthLayout(
        title: 'Welcome back',
        subtitle: 'Log in to pick up where you left off.',
        children: [
          if (_ended != null) ...[Notice(_ended, tone: Tone.warning), Gap.h16],
          if (_error != null) ...[Notice(_error!, tone: Tone.danger), Gap.h16],
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Field(
                label: 'Email',
                hint: 'you@example.com',
                controller: _email,
                icon: AppIcons.mail,
                keyboardType: TextInputType.emailAddress,
                autofill: const [AutofillHints.email],
                validator: validEmail,
              ),
              Gap.h16,
              PasswordField(controller: _password, validator: requiredField('Enter your password'), action: TextInputAction.done, onSubmitted: (_) => _submit()),
              Align(alignment: Alignment.centerRight, child: LinkText('Forgot password?', onTap: () => SiteNav.select('forgot'), color: context.colors.body)),
              Gap.h12,
              Btn('Log in', size: BtnSize.lg, expand: true, loading: _busy, onPressed: _submit),
            ]),
          ),
          _SwitchLine('New to SureFix?', 'Create an account', () {
            SiteNav.signupRole = null;
            SiteNav.select('register');
          }),
          if (_showDemo) Gap.h24,
          if (_showDemo)
            Panel(
              color: context.colors.sunken,
              border: Colors.transparent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Explore with a demo account', style: context.text.titleSmall),
                Gap.h2,
                Text('One tap signs you in as each kind of member.', style: context.text.bodySmall),
                Gap.h12,
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (label, email, icon) in _demo) Btn(label, icon: icon, kind: BtnKind.outline, size: BtnSize.sm, onPressed: _busy ? null : () => _useDemo(email)),
                ]),
              ]),
            ),
        ],
      );
}

// --------------------------------------------------------------- register

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late String _role = SiteNav.signupRole ?? 'client';
  String? _city;
  bool _busy = false;
  String? _error;

  static const _roles = [
    ('client', 'I need a repair', 'Post jobs, hire technicians, rent tools', AppIcons.home),
    ('technician', "I'm a technician", 'Quote on jobs and get paid', AppIcons.technicians),
    ('supplier', 'I rent out tools', 'List equipment and manage rentals', AppIcons.tools),
  ];

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.instance.register(name: _name.text, email: _email.text, password: _password.text, role: _role, phone: _phone.text, city: _city ?? '');
      TextInput.finishAutofillContext();
      toastOk('Welcome to SureFix!');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _AuthLayout(
      title: 'Create your account',
      subtitle: 'Free to join. Choose how you will use SureFix.',
      children: [
        for (final (key, title, body, icon) in _roles)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              button: true,
              selected: _role == key,
              child: Panel(
                onTap: () => setState(() => _role = key),
                padding: const EdgeInsets.all(12),
                border: _role == key ? c.ink : null,
                borderWidth: _role == key ? 1.6 : 1,
                child: Row(children: [
                  IconTile(icon, tone: _role == key ? Tone.brand : Tone.neutral),
                  Gap.w12,
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(title, style: context.text.titleSmall!.copyWith(fontSize: 14.5)),
                      Text(body, style: context.text.bodySmall),
                    ]),
                  ),
                  Icon(_role == key ? AppIcons.success : AppIcons.circle, size: 22, color: _role == key ? c.brand : c.line),
                ]),
              ),
            ),
          ),
        Gap.h12,
        if (_error != null) ...[Notice(_error!, tone: Tone.danger), Gap.h16],
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Field(
              label: _role == 'supplier' ? 'Business or full name' : 'Full name',
              hint: _role == 'supplier' ? 'ToolCo Rentals' : 'Sara Khan',
              controller: _name,
              icon: AppIcons.user,
              capitalization: TextCapitalization.words,
              autofill: const [AutofillHints.name],
              validator: minLength(2, 'Enter your name'),
            ),
            Gap.h16,
            Field(
                label: 'Email',
                hint: 'you@example.com',
                controller: _email,
                icon: AppIcons.mail,
                keyboardType: TextInputType.emailAddress,
                autofill: const [AutofillHints.email],
                validator: validEmail),
            Gap.h16,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Field(label: 'Phone', hint: '0300-1234567', controller: _phone, icon: AppIcons.phone, keyboardType: TextInputType.phone, optional: true)),
              Gap.w12,
              Expanded(child: SelectField<String>(label: 'City', hint: 'Choose', value: _city, items: {for (final c in cities) c: c}, onChanged: (v) => setState(() => _city = v))),
            ]),
            Gap.h16,
            PasswordField(controller: _password, hint: 'At least 6 characters', validator: validPassword, isNew: true, action: TextInputAction.done, onSubmitted: (_) => _submit()),
            Gap.h20,
            Btn('Create account', size: BtnSize.lg, expand: true, loading: _busy, onPressed: _submit),
            Gap.h12,
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'By creating an account you agree to the '),
                WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: _InlineLink('Terms', () => push(context, const LegalPage()))),
                const TextSpan(text: ' and '),
                WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: _InlineLink('Privacy notice', () => push(context, const LegalPage(privacy: true)))),
                const TextSpan(text: '.'),
              ]),
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ]),
        ),
        _SwitchLine('Already have an account?', 'Log in', () => SiteNav.select('login')),
      ],
    );
  }
}

class _InlineLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _InlineLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Semantics(
        link: true,
        child: GestureDetector(
          onTap: onTap,
          child: Text(label, style: context.text.bodySmall!.copyWith(color: context.colors.ink, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
        ),
      );
}

// -------------------------------------------------------- forgot password

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;
  String? _devCode;
  int _minutes = 15;

  @override
  void dispose() {
    for (final c in [_email, _code, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        final res = await Session.instance.forgotPassword(_email.text);
        if (!mounted) return;
        setState(() {
          _sent = true;
          _minutes = integer(res['minutes'], 15);
          _devCode = res['devCode']?.toString();
        });
      });

  Future<void> _reset() => _run(() async {
        await Session.instance.resetPassword(email: _email.text, code: _code.text, newPassword: _password.text);
        toastOk('Password changed');
        if (!Session.instance.loggedIn) SiteNav.select('login');
      });

  @override
  Widget build(BuildContext context) => _AuthLayout(
        title: _sent ? 'Enter your code' : 'Reset your password',
        subtitle: _sent ? 'Type the 6-digit code and choose a new password.' : 'We will send a 6-digit code to your email.',
        children: [
          if (_error != null) ...[Notice(_error!, tone: Tone.danger), Gap.h16],
          if (_sent) ...[
            _devCode != null
                ? Notice('No email server is set up, so here is your code: $_devCode', title: 'Demo mode', tone: Tone.brand, icon: AppIcons.infoFill)
                : Notice('If ${_email.text.trim()} has an account, a code is on its way. It expires in $_minutes minutes.', tone: Tone.success),
            Gap.h16,
          ],
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Field(label: 'Email', hint: 'you@example.com', controller: _email, icon: AppIcons.mail, enabled: !_sent, keyboardType: TextInputType.emailAddress, validator: validEmail),
              if (_sent) ...[
                Gap.h16,
                Field(
                  label: '6-digit code',
                  hint: '123456',
                  controller: _code,
                  icon: AppIcons.shield,
                  keyboardType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  validator: (v) => (v ?? '').trim().length == 6 ? null : 'Enter the 6-digit code',
                ),
                Gap.h16,
                PasswordField(
                    label: 'New password', hint: 'At least 6 characters', controller: _password, validator: validPassword, isNew: true, action: TextInputAction.done, onSubmitted: (_) => _reset()),
              ],
              Gap.h20,
              Btn(_sent ? 'Change password' : 'Send code', size: BtnSize.lg, expand: true, loading: _busy, onPressed: _sent ? _reset : _send),
              if (_sent) ...[
                Gap.h8,
                Btn('Use a different email',
                    kind: BtnKind.ghost,
                    expand: true,
                    onPressed: () => setState(() {
                          _sent = false;
                          _devCode = null;
                          _code.clear();
                        })),
              ],
            ]),
          ),
          _SwitchLine('Remembered it?', 'Back to log in', () => SiteNav.select('login')),
        ],
      );
}

// ------------------------------------------------------------------ intro

/// First-launch introduction on phones: three ideas, then sign in.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _slides = [
    ('Something broken?\nConsider it fixed.', 'Post a job in a minute. Verified technicians near you reply with quotes.'),
    ('The right person,\nnot just the cheapest.', 'Our AI scores every quote and tells you why: skills, ratings, reliability and price.'),
    ('Pay when the job\nis actually done.', 'Your money waits in escrow while you follow the work live. Release it with one tap.'),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish({bool register = false}) {
    SiteNav.select(register ? 'register' : 'login');
    Settings.instance.finishIntro();
  }

  Widget _art(BuildContext context, int i) {
    final c = context.colors;
    return switch (i) {
      0 => Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
          for (final cat in serviceCategories.take(9))
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: c.onHero.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(22), border: Border.all(color: c.heroLine)),
              child: Icon(cat.icon, size: 32, color: cat.key == 'plumbing' || cat.key == 'carpentry' || cat.key == 'roofing' ? c.brand : c.onHero),
            ),
        ]),
      1 => const ExcludeSemantics(
          child: IgnorePointer(
            child: MatchCard(
              TechMatch(
                technician:
                    User(id: 'demo', name: 'Noor Fatima', headline: 'Certified electrician', kycStatus: 'approved', rating: 4.9, ratingCount: 86, jobsCompleted: 140, city: 'Lahore', online: true),
                matchPercent: 94,
                reasons: ['Electrical specialist, 140 jobs done', 'Rated 4.9 by 86 customers', 'In your city, replies in ~15 min'],
              ),
              rank: 1,
            ),
          ),
        ),
      _ => ExcludeSemantics(
          child: Panel(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const IconTile(AppIcons.shieldFill, tone: Tone.brand),
                Gap.w12,
                Expanded(child: Text('Rs 2,800 held in escrow', style: context.text.titleMedium)),
              ]),
              Gap.h20,
              const StageTrack(2),
              Gap.h20,
              const Btn('Confirm & release payment', icon: AppIcons.check, expand: true, onPressed: null),
            ]),
          ),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = _index == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const BrandLogo(size: 30),
              const Spacer(),
              if (!last) Btn('Skip', kind: BtnKind.ghost, size: BtnSize.sm, onPressed: _finish),
            ]),
            Gap.h16,
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(
                    child: HeroCard(
                      padding: const EdgeInsets.all(22),
                      child: Center(child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: _art(context, i))),
                    ),
                  ),
                  Gap.h24,
                  Text(_slides[i].$1, style: context.text.displaySmall),
                  Gap.h12,
                  Text(_slides[i].$2, style: context.text.bodyLarge),
                ]),
              ),
            ),
            Gap.h20,
            Row(children: [
              for (var i = 0; i < _slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6),
                  width: i == _index ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: i == _index ? c.brand : c.line, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            Gap.h20,
            if (last) ...[
              Btn('Create an account', size: BtnSize.lg, expand: true, onPressed: () => _finish(register: true)),
              Gap.h8,
              Btn('I already have an account', kind: BtnKind.ghost, expand: true, onPressed: _finish),
            ] else
              Btn('Next', size: BtnSize.lg, expand: true, trailing: AppIcons.forward, onPressed: () => _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut)),
          ]),
        ),
      ),
    );
  }
}
