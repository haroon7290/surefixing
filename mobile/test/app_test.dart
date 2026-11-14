import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surefix/app.dart';
import 'package:surefix/features/account/edit_profile_screen.dart';
import 'package:surefix/features/account/kyc_screen.dart';
import 'package:surefix/features/auth/auth_screens.dart';
import 'package:surefix/features/chat/chat_screen.dart';
import 'package:surefix/features/jobs/job_detail_screen.dart';
import 'package:surefix/features/jobs/job_widgets.dart';
import 'package:surefix/features/jobs/post_job_screen.dart';
import 'package:surefix/features/rentals/rentals_screens.dart';
import 'package:surefix/features/shell/shell.dart';
import 'package:surefix/features/site/public_site.dart';
import 'package:surefix/features/technicians/technician_profile_screen.dart';
import 'package:surefix/features/technicians/technicians_screen.dart';
import 'package:surefix/features/tools/tool_detail_screen.dart';
import 'package:surefix/features/tools/tool_form_screen.dart';
import 'package:surefix/features/tools/tool_market_screen.dart';
import 'package:surefix/kit.dart';

import 'fake_api.dart';

const phone = Size(390, 844);
const desktop = Size(1440, 900);

void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));

/// Scrolls the widget into view, then taps it.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

Future<void> pumpApp(WidgetTester tester, {String? role, Size size = phone}) async {
  useSize(tester, size);
  signIn(role);
  await tester.pumpWidget(const SureFixApp());
  await settle(tester);
}

/// Opens a page on top of the running app, lets it load, then closes it.
Future<void> visit(WidgetTester tester, Widget page) async {
  navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => page));
  await settle(tester);
  expect(find.byType(ErrorState), findsNothing, reason: '${page.runtimeType} failed to load');
  navigatorKey.currentState!.pop();
  await settle(tester);
}

void main() {
  setUpAll(loadAppFonts);

  group('formatting', () {
    test('money, plurals and labels', () {
      expect(money(2500), 'Rs 2,500');
      expect(moneyCompact(12700), 'Rs 12.7K');
      expect(signedMoney(-500), '−Rs 500');
      expect(plural(1, 'quote'), '1 quote');
      expect(plural(3, 'quote'), '3 quotes');
      expect(humanize('on_the_way'), 'On the way');
      expect(initials('Sara Khan'), 'SK');
      expect(etaLabel(0), 'Can start today');
      expect(responseTime(18), '~18 min');
    });

    test('status labels follow the job lifecycle', () {
      expect(jobStatus('pending').$1, 'Getting quotes');
      expect(jobStatus('pending', directRequest: true).$1, 'Awaiting reply');
      expect(jobStatus('in_progress', stage: 'done').$1, 'Confirm completion');
      expect(jobStatus('completed').$2, Tone.success);
      expect(rentalStatus('active', overdue: true).$1, 'Overdue');
      expect(paymentStatus('held').$1, 'In escrow');
      expect(serviceCategory('nonsense').key, 'general');
    });
  });

  group('models', () {
    test('Job reads stages, payment, quotes and the activity log', () {
      final job = Job.fromJson(fakeJobs[2]);
      expect(job.inProgress, isTrue);
      expect(job.awaitingConfirmation, isTrue);
      expect(job.beforeWork, isFalse);
      expect(job.stageIndex, 3);
      expect(job.technician?.name, 'Ahmad Raza');
      expect(job.technician?.phone, '0300-1234503');
      expect(job.payment.status, 'cash_due');
      expect(job.autoCompleteAt, isNotNull);
      expect(job.history.first.event, 'posted');

      final open = Job.fromJson(fakeJobs[0]);
      expect(open.pending, isTrue);
      expect(open.bidCount, 2);
      expect(open.lowestBid, 2800);
      expect(open.bidBy('t2')?.amount, 3400);
      expect(open.price, 3000);
      expect(Job.fromJson(fakeJobs[5]).isDirectRequest, isTrue);
    });

    test('references may be populated objects or bare ids', () {
      final job = Job.fromJson({
        '_id': 'x',
        'client': 'c9',
        'assignedTechnician': null,
        'bids': [
          {'_id': 'b', 'technician': 't9', 'amount': 10}
        ]
      });
      expect(job.client.id, 'c9');
      expect(job.client.name, '');
      expect(job.technician, isNull);
      expect(job.bids.single.technician.id, 't9');
    });

    test('locations: areas, distances and who covers what', () {
      final t = User.fromJson({'id': 't', 'role': 'technician', 'city': 'Lahore', 'area': 'Gulberg', 'serviceRadiusKm': 10, 'distanceKm': 6.8, 'geo': {'lat': 31.5, 'lng': 74.3}});
      expect(t.place, 'Gulberg, Lahore');
      expect(t.covers(6.8), isTrue);
      expect(t.covers(12), isFalse);
      expect(t.geo, const GeoPoint(31.5, 74.3));
      expect(User.fromJson(t.toJson()).geo, const GeoPoint(31.5, 74.3)); // survives the saved session
      expect(User.fromJson({'id': 'x'}).distanceKm, isNull);
      expect(User.fromJson({'id': 'x'}).serviceRadiusKm, 15);
      expect(Tool.fromJson({'_id': 'k', 'area': 'Garden Town', 'city': 'Lahore', 'distanceKm': 7.1}).place, 'Garden Town, Lahore');
      expect(distance(0.85), '850 m');
      expect(distance(2.34), '2.3 km');
      expect(distance(12.4), '12 km');
      expect(DistanceText.describe(2, 'DHA Phase 5'), '2.0 km · DHA Phase 5');
      expect(DistanceText.describe(null, 'Lahore'), 'Lahore');
      expect(kmBetween(const GeoPoint(31.463, 74.408), const GeoPoint(31.515, 74.344)), closeTo(8.4, 0.3));
    });

    test('Tool and Rental computed helpers', () {
      final tool = Tool.fromJson(fakeTools.first);
      expect(tool.hasInstallments, isTrue);
      expect(tool.monthly, 5500);
      expect(tool.rentable, isTrue);
      expect(Tool.fromJson({'_id': 't', 'supplier': 's', 'stock': 0}).rentable, isFalse);

      final late = Rental.fromJson(fakeRentals[1]);
      expect(late.overdue, isTrue);
      expect(late.lateFee, 1600);
      expect(late.handover.revealed, isTrue);
      expect(late.supplier.phone, '042-1234567');
      final plan = Rental.fromJson(fakeRentals[2]);
      expect(plan.isInstallment, isTrue);
      expect(plan.monthsRemaining, 4);
      expect(Rental.fromJson(fakeRentals[0]).handover.address, isEmpty);
      expect(Rental.fromJson(fakeRentals[3]).canReview, isTrue);
    });

    test('ChatTarget addresses job and tool threads', () {
      const job = ChatTarget(jobId: 'j2', otherId: 't1');
      const tool = ChatTarget(toolId: 'tool1', otherId: 's1');
      expect(job.thread, 'j2');
      expect(job.path, '/api/messages/j2');
      expect(tool.thread, 'tool:tool1');
      expect(tool.path, '/api/messages/tool/tool1');
    });
  });

  group('components', () {
    testWidgets('StageTrack marks finished, current and future stages', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: StageTrack(2))));
      for (final label in ['Hired', 'On the way', 'Working', 'Finished']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byIcon(AppIcons.check), findsNWidgets(3)); // two done + the last stage's own icon
    });

    testWidgets('Btn shows a spinner and ignores taps while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: Btn('Save', loading: true, onPressed: () => taps++))));
      await tester.tap(find.text('Save'));
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AsyncView shows an error with retry, then the data', (tester) async {
      var fail = true;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: AsyncView<String>(load: () async => fail ? throw ApiError(0, 'No connection') : 'Loaded', builder: (_, v) => Text(v))),
      ));
      await tester.pumpAndSettle();
      expect(find.text("Can't connect"), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Loaded'), findsOneWidget);
    });
  });

  // Every section of every role must lay out without overflowing, on a
  // phone and on a desktop window, in light and dark themes.
  for (final (name, size) in [('phone', phone), ('desktop', desktop)]) {
    group('every screen renders on $name', () {
      for (final role in ['client', 'technician', 'supplier', 'admin']) {
        testWidgets('$role sections', (tester) async {
          await pumpApp(tester, role: role, size: size);
          for (final dest in destinationsFor(role)) {
            SiteNav.select(dest.key);
            await settle(tester);
            expect(find.byType(ErrorState), findsNothing, reason: '${dest.key} failed to load');
          }
        });
      }

      testWidgets('client detail pages', (tester) async {
        await pumpApp(tester, role: 'client', size: size);
        for (final job in fakeJobs) {
          await visit(tester, JobDetailScreen(jobId: job['_id'] as String));
        }
        await visit(tester, const PostJobScreen());
        await visit(tester, const ToolDetailScreen(toolId: 'tool1'));
        await visit(tester, const TechnicianProfileScreen(technicianId: 't1'));
        for (final r in ['r1', 'r2', 'r3', 'r4']) {
          await visit(tester, RentalDetailScreen(rentalId: r, forSupplier: false));
        }
        await visit(tester, const ChatScreen(target: ChatTarget(jobId: 'j2', otherId: 't1', otherName: 'Ahmad Raza', subject: 'AC not cooling')));
        await visit(tester, const EditProfileScreen());
      });

      testWidgets('technician and supplier detail pages', (tester) async {
        await pumpApp(tester, role: 'technician', size: size);
        for (final job in fakeJobs) {
          await visit(tester, JobDetailScreen(jobId: job['_id'] as String));
        }
        await visit(tester, const EditProfileScreen());
        await visit(tester, const KycScreen());

        await pumpApp(tester, role: 'supplier', size: size);
        for (final r in ['r1', 'r2', 'r3']) {
          await visit(tester, RentalDetailScreen(rentalId: r, forSupplier: true));
        }
        await visit(tester, const ToolFormScreen());
        await visit(tester, ToolFormScreen(tool: Tool.fromJson(fakeTools.first)));
      });

      testWidgets('public website pages', (tester) async {
        useSize(tester, size);
        signIn(null);
        // Off the web a phone shows the sign-in flow, so host the site directly.
        await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), navigatorKey: navigatorKey, scaffoldMessengerKey: messengerKey, home: const PublicSite()));
        for (final section in ['home', 'technicians', 'tools', 'about', 'help', 'terms', 'privacy', 'login', 'register', 'forgot']) {
          SiteNav.select(section);
          await settle(tester);
          expect(find.byType(ErrorState), findsNothing, reason: '$section failed to load');
        }
      });

      testWidgets('dark theme', (tester) async {
        useSize(tester, size);
        signIn('client');
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), navigatorKey: navigatorKey, scaffoldMessengerKey: messengerKey, home: const HomeShell(role: 'client')));
        await settle(tester);
        expect(find.textContaining('Sara'), findsWidgets);
      });
    });
  }

  group('flows', () {
    testWidgets('signed-out phone shows log in; demo account signs in', (tester) async {
      await pumpApp(tester);
      expect(find.text('Welcome back'), findsOneWidget);
      installFakeApi('client');
      await tapOn(tester, find.text('Customer'));
      expect(sent, contains('POST /api/auth/login'));
      expect(sentBodies['POST /api/auth/login'], {'email': 'client@demo.com', 'password': 'password123'});
      expect(Session.instance.loggedIn, isTrue);
      expect(find.byType(TabBarNav), findsOneWidget);
      Realtime.instance.disconnect();
      Badges.instance.stop();
    });

    testWidgets('log in validates before calling the server', (tester) async {
      await pumpApp(tester);
      await tapOn(tester, find.text('Log in').last);
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(sent, isEmpty);
    });

    testWidgets('forgot password shows the demo code and resets', (tester) async {
      useSize(tester, phone);
      signIn(null);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), navigatorKey: navigatorKey, scaffoldMessengerKey: messengerKey, home: const ForgotPasswordScreen()));
      await tester.enterText(find.byType(TextFormField).first, 'client@demo.com');
      await tester.tap(find.text('Send code'));
      await settle(tester);
      expect(find.textContaining('482913'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
    });

    testWidgets('client hires a technician through the escrow wallet', (tester) async {
      await pumpApp(tester, role: 'client', size: desktop);
      navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const JobDetailScreen(jobId: 'j1')));
      await settle(tester);
      expect(find.text('Best match'), findsOneWidget);
      expect(find.text('Ranked by AI'), findsOneWidget);

      await tapOn(tester, find.text('Hire · Rs 2,800'));
      expect(find.text('Hire Ahmad'), findsOneWidget);
      expect(find.text('SureFix Wallet'), findsOneWidget);

      await tester.tap(find.text('Hire · Rs 2,800').last);
      await settle(tester);
      expect(sent, contains('POST /api/jobs/j1/accept/b1'));
      expect(sentBodies['POST /api/jobs/j1/accept/b1'], {'paymentMethod': 'wallet'});
    });

    testWidgets('client confirms finished work', (tester) async {
      await pumpApp(tester, role: 'client');
      navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const JobDetailScreen(jobId: 'j3')));
      await settle(tester);
      expect(find.text('Ahmad says the work is finished'), findsOneWidget);
      await tester.tap(find.text('Confirm job is done'));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(sent, contains('POST /api/jobs/j3/complete'));
    });

    testWidgets('technician moves a job forward', (tester) async {
      await pumpApp(tester, role: 'technician');
      navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const JobDetailScreen(jobId: 'j2')));
      await settle(tester);
      expect(find.text('Work in progress'), findsWidgets);
      expect(find.text('You receive'), findsOneWidget); // net after the fee
      await tester.tap(find.text('Mark as finished'));
      await settle(tester);
      await tester.tap(find.text('Finish & ask client to confirm'));
      await settle(tester);
      expect(sent, contains('POST /api/jobs/j2/done'));
    });

    testWidgets('technician sends a quote', (tester) async {
      signIn('technician');
      useSize(tester, phone);
      // A job this technician has not quoted on yet.
      Session.instance.user = User.fromJson({...fakeUser('technician'), 'id': 't9'});
      await tester.pumpWidget(const SureFixApp());
      await settle(tester);
      navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const JobDetailScreen(jobId: 'j1')));
      await settle(tester);
      expect(find.text('Send your quote'), findsOneWidget);
      await tapOn(tester, find.text('Send quote'));
      expect(sent, contains('POST /api/jobs/j1/bids'));
      expect(sentBodies['POST /api/jobs/j1/bids']['amount'], 3000);
    });

    testWidgets('supplier approves a rental request from the dashboard', (tester) async {
      await pumpApp(tester, role: 'supplier');
      await tapOn(tester, find.text('Approve').first);
      expect(sent, contains('POST /api/rentals/r1/approve'));
    });

    testWidgets('customer adds money with a transaction ID', (tester) async {
      await pumpApp(tester, role: 'client', size: desktop);
      SiteNav.select('wallet');
      await settle(tester);
      expect(find.text('Waiting for review (2)'), findsOneWidget);
      await tapOn(tester, find.text('Add money').first);
      expect(find.text('Meezan Bank'), findsWidgets);
      expect(find.text('0101-0104567890'), findsWidgets);
      await tapOn(tester, find.text('JazzCash').last);
      await tester.enterText(find.widgetWithText(TextFormField, '5000'), '7500');
      await tester.enterText(find.byType(TextFormField).at(1), 'JC-99887766');
      await tapOn(tester, find.text('Submit for review'));
      expect(sent, contains('POST /api/wallet/deposits'));
    });

    testWidgets('withdrawal asks for an account and the amount', (tester) async {
      await pumpApp(tester, role: 'client', size: desktop);
      SiteNav.select('wallet');
      await settle(tester);
      await tapOn(tester, find.text('Withdraw').first);
      expect(find.text('Send it to'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '0300-1234501'), findsOneWidget); // saved account prefilled
      await tester.enterText(find.byType(TextFormField).first, '2000');
      await tapOn(tester, find.text('Request withdrawal'));
      expect(sent, contains('POST /api/wallet/withdrawals'));
      expect(sentBodies['POST /api/wallet/withdrawals'], containsPair('amount', 2000));
      expect(sentBodies['POST /api/wallet/withdrawals'], containsPair('provider', 'JazzCash'));
    });

    testWidgets('admin approves a deposit and rejects a withdrawal', (tester) async {
      await pumpApp(tester, role: 'admin', size: desktop);
      expect(find.text('Deposits to check'), findsOneWidget);
      SiteNav.select('payments');
      await settle(tester);
      expect(find.text('JC48213977'), findsOneWidget);
      await tapOn(tester, find.text('Approve').first);
      await tapOn(tester, find.text('Approve and add to wallet'));
      expect(sent, contains('POST /api/admin/wallet-requests/wr1/approve'));
      expect(sentBodies['POST /api/admin/wallet-requests/wr1/approve'], {'amount': 5000});

      await tapOn(tester, find.text('Withdrawals').first);
      await tapOn(tester, find.text('Reject').first);
      await tester.enterText(find.byType(TextFormField).last, 'Account title does not match');
      await tapOn(tester, find.text('Reject').last);
      expect(sent, contains('POST /api/admin/wallet-requests/wr2/reject'));
    });

    testWidgets('technicians are searched near the saved location, with distance filters', (tester) async {
      await pumpApp(tester, role: 'client', size: desktop);
      SiteNav.select('technicians');
      await settle(tester);
      var q = lastGet('/api/users/technicians')!.queryParameters;
      expect(q['lat'], '31.46800');
      expect(q['lng'], '74.38300');
      expect(q['sort'], 'distance'); // nearest first by default once a location is known
      expect(q.containsKey('radius'), isFalse);
      expect(find.text('5.5 km · Model Town'), findsOneWidget);
      expect(find.text('Usually travels up to 5 km'), findsOneWidget); // Noor is 6.8 km away, covers 5
      expect(find.textContaining('nearest to DHA Phase 4 first'), findsOneWidget);

      await tapOn(tester, find.text('Within 10 km'));
      q = lastGet('/api/users/technicians')!.queryParameters;
      expect(q['radius'], '10');
      expect(Locations.instance.radiusKm, 10);

      await tapOn(tester, find.text('Travels to me'));
      await tapOn(tester, find.text('4.5+'));
      q = lastGet('/api/users/technicians')!.queryParameters;
      expect(q['covers'], '1');
      expect(q['minRating'], '4.5');
      expect(find.text('Filters · 3'), findsOneWidget);

      await tapOn(tester, find.text('Reset'));
      q = lastGet('/api/users/technicians')!.queryParameters;
      expect(q.containsKey('radius'), isFalse);
      expect(q.containsKey('covers'), isFalse);
    });

    testWidgets('phone filter sheet applies only on "Show results"', (tester) async {
      await pumpApp(tester, role: 'client');
      navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const TechniciansScreen()));
      await settle(tester);
      expect(find.text('Near DHA Phase 4'), findsOneWidget);
      await tapOn(tester, find.text('Filters'));
      await tapOn(tester, find.text('Verified ID'));
      await tapOn(tester, find.text('Within 5 km'));
      expect(lastGet('/api/users/technicians')!.queryParameters.containsKey('verified'), isFalse);
      await tapOn(tester, find.text('Show results'));
      final q = lastGet('/api/users/technicians')!.queryParameters;
      expect(q['verified'], '1');
      expect(q['radius'], '5');
      expect(find.text('Near DHA Phase 4 · 5 km'), findsOneWidget);
    });

    testWidgets('a visitor picks an area and tools are sorted by distance from it', (tester) async {
      await pumpApp(tester, size: desktop);
      navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const ToolMarketScreen()));
      await settle(tester);
      expect(lastGet('/api/tools')!.queryParameters.containsKey('lat'), isFalse);
      expect(find.text('Set your location'), findsOneWidget);
      await tapOn(tester, find.text('Set your location'));
      expect(find.text('Use my current location'), findsOneWidget);
      expect(find.text('Pick on the map'), findsOneWidget);
      await tapOn(tester, find.text('DHA Phase 5'));
      expect(Locations.instance.chosen?.area, 'DHA Phase 5');
      final q = lastGet('/api/tools')!.queryParameters;
      expect(q['lat'], '31.46300');
      expect(q['sort'], 'distance');
      expect(find.text('7.1 km'), findsOneWidget);
      expect(find.textContaining('nearest to DHA Phase 5 first'), findsOneWidget);
    });

    testWidgets('technician sets where they work and how far they travel', (tester) async {
      await pumpApp(tester, role: 'technician', size: desktop);
      navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
      await settle(tester);
      expect(find.text('Model Town, Lahore'), findsOneWidget);
      await tapOn(tester, find.text('20 km'));
      await tapOn(tester, find.text('Model Town, Lahore'));
      await tapOn(tester, find.text('Gulberg'));
      await tapOn(tester, find.text('Save changes'));
      final body = sentBodies['PATCH /api/users/me'] as Map;
      expect(body['serviceRadiusKm'], 20);
      expect(body['lat'], 31.515);
      expect(body['area'], 'Gulberg');
    });

    testWidgets('find jobs shows how far each job is and filters by urgency', (tester) async {
      await pumpApp(tester, role: 'technician', size: desktop);
      SiteNav.select('find');
      await settle(tester);
      expect(find.textContaining('2.1 km away'), findsWidgets);
      expect(find.textContaining('4.6 km away'), findsWidgets);
      Finder inPanel(String text) => find.descendant(of: find.byType(FilterPanel), matching: find.text(text));
      await tapOn(tester, inPanel('Urgent'));
      await tapOn(tester, inPanel('Emergency'));
      expect(lastGet('/api/jobs')!.queryParameters['urgency'], 'high,emergency');
      await tapOn(tester, inPanel('Rs 5,000+'));
      expect(lastGet('/api/jobs')!.queryParameters['minBudget'], '5000');
    });

    testWidgets('the dock switches sections', (tester) async {
      await pumpApp(tester, role: 'client');
      await tester.tap(find.bySemanticsLabel('My jobs'));
      await settle(tester);
      expect(SiteNav.section.value, 'jobs');
      expect(find.text('Getting quotes · 2'), findsOneWidget);
    });
  });
}
