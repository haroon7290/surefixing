import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surefix/app.dart';
import 'package:surefix/core/format.dart';
import 'package:surefix/core/theme.dart';
import 'package:surefix/models/job.dart';
import 'package:surefix/models/recommendation.dart';
import 'package:surefix/models/rental.dart';
import 'package:surefix/models/tool.dart';
import 'package:surefix/models/user.dart';
import 'package:surefix/services/auth_service.dart';
import 'package:surefix/services/settings_service.dart';
import 'package:surefix/widgets/match_card.dart';
import 'package:surefix/widgets/pills.dart';
import 'package:surefix/widgets/rating_stars.dart';
import 'package:surefix/widgets/states.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(theme: theme ?? AppTheme.light(), home: Scaffold(body: child));

void main() {
  group('models', () {
    test('Job parses populated + raw references, bids and history', () {
      final job = Job.fromJson({
        '_id': 'j1',
        'client': {'_id': 'c1', 'name': 'Sara Khan', 'rating': 0},
        'assignedTechnician': 't1',
        'requestedTechnician': null,
        'title': 'Fix sink',
        'description': 'Leaking',
        'category': 'plumbing',
        'budget': 3000,
        'agreedPrice': 2800,
        'urgency': 'high',
        'status': 'in_progress',
        'bids': [
          {
            '_id': 'b1',
            'technician': {'_id': 't1', 'name': 'Ahmad'},
            'amount': 2800,
            'etaDays': 0,
            'status': 'accepted'
          },
          {'_id': 'b2', 'technician': 't2', 'amount': 3500, 'status': 'rejected'},
        ],
        'history': [
          {
            'status': 'pending',
            'note': 'Job posted',
            'by': {'name': 'Sara', 'role': 'client'},
            'at': '2026-01-01T10:00:00Z'
          },
        ],
        'createdAt': '2026-01-01T10:00:00Z',
      });
      expect(job.clientName, 'Sara Khan');
      expect(job.technicianId, 't1');
      expect(job.bids.first.technicianName, 'Ahmad');
      expect(job.bids.last.technicianId, 't2');
      expect(job.lowestBid, 2800);
      expect(job.bidBy('t2')?.amount, 3500);
      expect(job.history.single.byName, 'Sara');
      expect(job.isActive, isTrue);
      expect(job.isDirectRequest, isFalse);
    });

    test('Tool falls back to the legacy single image field', () {
      final t = Tool.fromJson({'_id': 'x', 'name': 'Drill', 'image': 'a.jpg', 'stock': 0, 'available': true, 'supplier': 's1'});
      expect(t.images, ['a.jpg']);
      expect(t.inStock, isFalse);
      expect(t.supplierId, 's1');
    });

    test('Rental flags and computed helpers', () {
      final r = Rental.fromJson({
        '_id': 'r1',
        'tool': {
          '_id': 't',
          'name': 'Ladder',
          'images': ['l.png']
        },
        'type': 'rent',
        'status': 'returned',
        'totalCost': 500,
        'overdue': false,
      });
      expect(r.tool.image, 'l.png');
      expect(r.canReview, isTrue);
      expect(r.isOpen, isFalse);
    });

    test('User profile completeness and completion rate', () {
      final u = User.fromJson({
        'id': 'u',
        'name': 'Ahmad Raza',
        'email': 'a@b.c',
        'role': 'technician',
        'jobsCompleted': 14,
        'jobsAssigned': 15,
        'skills': ['plumbing'],
        'hourlyRate': 1500,
      });
      expect(u.firstName, 'Ahmad');
      expect(u.completionRate, closeTo(0.933, 0.01));
      expect(u.profileCompleteness, closeTo(2 / 7, 0.01));
    });

    test('TechMatch falls back to score when matchPercent is missing (v1 AI service)', () {
      final m = TechMatch.fromJson({'technicianId': 't', 'name': 'A', 'score': 4.2});
      expect(m.matchPercent, 84);
    });
  });

  group('format', () {
    test('money and plurals', () {
      expect(Fmt.money(2800), '${Fmt.currency} 2,800');
      expect(Fmt.money(12.5), '${Fmt.currency} 12.5');
      expect(Fmt.plural(1, 'day'), '1 day');
      expect(Fmt.plural(3, 'day'), '3 days');
      expect(Fmt.titleCase('pest_control'), 'Pest Control');
      expect(Fmt.responseTime(22), '~22 min');
      expect(Fmt.responseTime(130), '~2 hr');
    });

    test('relative time', () {
      expect(Fmt.ago(DateTime.now().subtract(const Duration(minutes: 5))), '5m ago');
      expect(Fmt.ago(DateTime.now().subtract(const Duration(hours: 3))), '3h ago');
      expect(Fmt.dayLabel(DateTime.now()), 'Today');
    });
  });

  group('widgets', () {
    testWidgets('StatusPill labels', (tester) async {
      await tester.pumpWidget(_wrap(const Wrap(children: [StatusPill('pending'), StatusPill('in_progress'), StatusPill('approved')])));
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('RatingLabel shows New for unrated technicians', (tester) async {
      await tester.pumpWidget(_wrap(const Column(children: [RatingLabel(rating: 0, count: 0), RatingLabel(rating: 4.6, count: 12)])));
      expect(find.text('New'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text(' (12)'), findsOneWidget);
    });

    testWidgets('EmptyState action fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(EmptyState(icon: Icons.work, title: 'Nothing', actionLabel: 'Do it', onAction: () => tapped = true)));
      await tester.tap(find.text('Do it'));
      expect(tapped, isTrue);
    });

    testWidgets('MatchCard renders reasons, notes and quote in dark mode', (tester) async {
      final m = TechMatch.fromJson({
        'technicianId': 't',
        'name': 'Usman Ali',
        'rating': 4.8,
        'ratingCount': 21,
        'matchPercent': 94,
        'reasons': ['Specialises in AC & heating', 'Rated 4.8★ by 21 clients'],
        'notes': ['20% over your budget'],
        'amount': 6000,
        'etaDays': 0,
        'kycStatus': 'approved',
      });
      await tester.pumpWidget(_wrap(SingleChildScrollView(child: MatchCard(match: m, rank: 0, showQuote: true)), theme: AppTheme.dark()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Best overall quote'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      expect(find.text('Specialises in AC & heating'), findsOneWidget);
      expect(find.text('20% over your budget'), findsOneWidget);
      expect(find.text('Can start today'), findsOneWidget);
    });
  });

  group('app', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('first launch shows onboarding, then login', (tester) async {
      await SettingsService.instance.load();
      await AuthService.instance.load();
      await tester.pumpWidget(const SureFixApp());
      await tester.pumpAndSettle();
      expect(find.text('Trusted pros for every repair'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
    });

    testWidgets('login validates fields before calling the server', (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingSeen': true});
      await SettingsService.instance.load();
      await tester.pumpWidget(const SureFixApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });
  });
}
