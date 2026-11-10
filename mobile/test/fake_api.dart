import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surefix/kit.dart';

/// A stand-in backend for widget tests: answers every endpoint the app
/// calls with data shaped like the real API, and records what was sent.

String _ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();
String _in(Duration d) => DateTime.now().toUtc().add(d).toIso8601String();

Json fakeUser(String role) => switch (role) {
      'technician' => _tech1,
      'supplier' => _supplier,
      'admin' => _admin,
      _ => _client,
    };

final Json _client = {
  'id': 'c1', 'name': 'Sara Khan', 'email': 'client@demo.com', 'phone': '0300-1234501', 'role': 'client', 'status': 'active', 'kycStatus': 'none',
  'city': 'Lahore', 'address': 'House 14, Street 7, DHA Phase 4, Lahore', 'walletBalance': 12700, 'favoriteTechnicians': ['t1'], 'favoriteTools': ['tool1'],
  'createdAt': _ago(const Duration(days: 200)),
};

final Json _tech1 = {
  'id': 't1', 'name': 'Ahmad Raza', 'email': 'tech@demo.com', 'phone': '0300-1234503', 'role': 'technician', 'status': 'active', 'kycStatus': 'approved',
  'city': 'Lahore', 'headline': 'Licensed electrician & plumber', 'bio': 'Twelve years fixing homes across Lahore. Clean work, fair prices.',
  'skills': ['plumbing', 'electrical', 'general'], 'hourlyRate': 1500, 'experienceYears': 12, 'isAvailable': true, 'portfolio': <String>[],
  'rating': 4.7, 'ratingCount': 12, 'jobsCompleted': 12, 'jobsAssigned': 13, 'avgResponseMinutes': 18, 'walletBalance': 15510, 'online': true,
  'createdAt': _ago(const Duration(days: 300)),
};

final Json _tech2 = {
  'id': 't2', 'name': 'Noor Fatima', 'role': 'technician', 'kycStatus': 'pending', 'city': 'Lahore', 'headline': 'Certified electrician',
  'skills': ['electrical', 'appliance', 'hvac', 'locksmith'], 'hourlyRate': 1800, 'experienceYears': 6, 'isAvailable': false,
  'rating': 0, 'ratingCount': 0, 'jobsCompleted': 0, 'jobsAssigned': 0, 'avgResponseMinutes': 240, 'createdAt': _ago(const Duration(days: 20)),
};

final Json _supplier = {
  'id': 's1', 'name': 'ToolCo Rentals', 'email': 'supplier@demo.com', 'phone': '042-1234567', 'role': 'supplier', 'status': 'active', 'kycStatus': 'approved',
  'city': 'Lahore', 'address': 'Shop 12, Hall Road, Lahore', 'walletBalance': 4230, 'createdAt': _ago(const Duration(days: 150)),
};

final Json _admin = {'id': 'a1', 'name': 'Admin', 'email': 'admin@demo.com', 'role': 'admin', 'status': 'active', 'city': 'Lahore', 'createdAt': _ago(const Duration(days: 400))};

Json _card(Json u, {bool contact = false}) => {
      '_id': u['id'], 'name': u['name'], 'avatar': '', 'rating': u['rating'] ?? 0, 'ratingCount': u['ratingCount'] ?? 0, 'city': u['city'], 'kycStatus': u['kycStatus'],
      if (contact) 'phone': u['phone'], if (contact) 'email': u['email'],
    };

Json _bid(String id, Json tech, num amount, String status) => {
      '_id': id, 'technician': {..._card(tech), 'headline': tech['headline'], 'skills': tech['skills']}, 'amount': amount, 'etaDays': 0,
      'message': 'I can come this afternoon with spare fittings.', 'status': status, 'createdAt': _ago(const Duration(hours: 2)),
    };

Json _job(String id, String title, String category, String status, {String stage = 'hired', Json? tech, List<Json> bids = const [], Json? payment, Json? extra}) => {
      '_id': id, 'client': _card(_client, contact: tech != null), 'title': title,
      'description': 'Water is dripping from the pipe under the kitchen sink and the cabinet floor is getting wet. Need it fixed today if possible.',
      'category': category, 'budget': 3000, 'location': 'House 14, Street 7, DHA Phase 4', 'city': 'Lahore', 'urgency': 'high', 'images': <String>[],
      'status': status, 'stage': stage, 'requestedTechnician': null, 'requestDeclined': false,
      'assignedTechnician': tech == null ? null : _card(tech, contact: true), 'agreedPrice': tech == null ? null : 2800,
      'bids': bids, 'bidCount': bids.length,
      'history': [
        {'event': 'posted', 'note': 'Job posted', 'by': {'name': 'Sara Khan', 'role': 'client'}, 'at': _ago(const Duration(hours: 5))},
        if (tech != null) {'event': 'hired', 'note': 'Hired Ahmad Raza for 2800 (paid into escrow)', 'by': {'name': 'Sara Khan', 'role': 'client'}, 'at': _ago(const Duration(hours: 3))},
      ],
      'payment': payment ?? {'method': 'cash', 'status': 'none', 'amount': 0},
      'createdAt': _ago(const Duration(hours: 5)),
      ...?extra,
    };

const _held = {'method': 'wallet', 'status': 'held', 'amount': 2800, 'fee': 280, 'net': 2520};

final List<Json> fakeJobs = [
  _job('j1', 'Fix leaking kitchen sink', 'plumbing', 'pending', bids: [_bid('b1', _tech1, 2800, 'pending'), _bid('b2', _tech2, 3400, 'pending')]),
  _job('j2', 'AC not cooling — needs gas refill', 'hvac', 'in_progress', stage: 'working', tech: _tech1, payment: _held, bids: [_bid('b3', _tech1, 2800, 'accepted')]),
  _job('j3', 'Sparking wall socket in lounge', 'electrical', 'in_progress', stage: 'done', tech: _tech1, payment: {'method': 'cash', 'status': 'cash_due', 'amount': 2800, 'net': 2800}, extra: {
    'doneAt': _ago(const Duration(hours: 1)), 'completionNote': 'Replaced the socket and tightened the neutral. Tested with a load.', 'autoCompleteAt': _in(const Duration(hours: 71)),
  }),
  _job('j4', 'Replace bathroom tap', 'plumbing', 'completed', stage: 'done', tech: _tech1, payment: {'method': 'wallet', 'status': 'released', 'amount': 2800, 'fee': 280, 'net': 2520},
      extra: {'rating': 5, 'review': 'Quick, tidy and fairly priced.', 'completedAt': _ago(const Duration(days: 9))}),
  _job('j5', 'Paint the guest room', 'painting', 'cancelled', extra: {'cancelReason': 'Decided to wait until winter'}),
  _job('j6', 'Install new distribution box', 'electrical', 'pending', extra: {'requestedTechnician': _card(_tech1)}),
];

Json _tool(String id, String name, String category, {int months = 0}) => {
      '_id': id, 'supplier': {'_id': 's1', 'name': 'ToolCo Rentals', 'avatar': '', 'city': 'Lahore', 'kycStatus': 'approved', 'createdAt': _ago(const Duration(days: 150))},
      'name': name, 'description': '18V cordless drill/driver with 2 batteries, charger and a 30-piece bit set.', 'category': category, 'condition': 'like_new', 'city': 'Lahore',
      'images': <String>[], 'rentPricePerDay': 800, 'deposit': 5000, 'purchasePrice': months > 0 ? 32000 : 0, 'installmentMonths': months, 'installmentMonthly': months > 0 ? 5500 : 0,
      'available': true, 'stock': 3, 'rating': 4.8, 'ratingCount': 5, 'rentalsCount': 12,
    };

final List<Json> fakeTools = [
  _tool('tool1', 'Bosch Cordless Drill 18V', 'power', months: 6),
  _tool('tool2', 'Aluminium Extension Ladder 12 ft', 'ladders'),
  _tool('tool3', 'Karcher Pressure Washer K2', 'cleaning'),
];

Json _rental(String id, String type, String status, {bool overdue = false, Json? payment}) => {
      '_id': id, 'tool': {'_id': 'tool1', 'name': 'Bosch Cordless Drill 18V', 'images': <String>[], 'category': 'power', 'city': 'Lahore'},
      'renter': {'_id': 'c1', 'name': 'Sara Khan', 'avatar': '', 'city': 'Lahore', if (status == 'active') 'phone': '0300-1234501'},
      'supplier': {'_id': 's1', 'name': 'ToolCo Rentals', 'avatar': '', 'city': 'Lahore', 'kycStatus': 'approved', if (status == 'active') 'phone': '042-1234567'},
      'type': type, 'startDate': _ago(const Duration(days: 5)), 'endDate': overdue ? _ago(const Duration(days: 2)) : _in(const Duration(days: 2)), 'days': 3,
      'dailyRate': 800, 'deposit': 5000, 'totalCost': type == 'rent' ? 2400 : 32000, 'monthsTotal': type == 'rent' ? 0 : 6, 'monthsPaid': type == 'rent' ? 0 : 2,
      'monthlyAmount': type == 'rent' ? 0 : 5500, 'monthsRemaining': type == 'rent' ? 0 : 4,
      'payment': payment ?? {'method': 'wallet', 'status': 'held', 'amount': 2400, 'deposit': 5000, 'fee': 240, 'net': 2160},
      'fulfillment': 'pickup', 'note': 'I can collect after 5 pm', 'status': status, 'overdue': overdue, 'daysLeft': overdue ? -2 : 2,
      if (overdue) 'lateDays': 2, if (overdue) 'lateFee': 1600,
      'handover': {'method': 'pickup', 'address': status == 'active' ? 'Shop 12, Hall Road, Lahore' : '', 'city': 'Lahore', 'revealed': status == 'active'},
      'createdAt': _ago(const Duration(days: 6)),
    };

final List<Json> fakeRentals = [
  _rental('r1', 'rent', 'requested'),
  _rental('r2', 'rent', 'active', overdue: true),
  _rental('r3', 'installment', 'active', payment: {'method': 'cash', 'status': 'none', 'amount': 32000, 'net': 32000}),
  _rental('r4', 'rent', 'returned', payment: {'method': 'wallet', 'status': 'released', 'amount': 2400, 'deposit': 5000, 'fee': 240, 'net': 2160}),
];

final List<Json> _txns = [
  {'_id': 'x1', 'type': 'job_hold', 'amount': -2800, 'balanceAfter': 12700, 'job': {'title': 'AC not cooling'}, 'createdAt': _ago(const Duration(days: 1))},
  {'_id': 'x2', 'type': 'topup', 'amount': 10000, 'balanceAfter': 15500, 'note': 'Demo funds added', 'createdAt': _ago(const Duration(days: 3))},
  {'_id': 'x3', 'type': 'platform_fee', 'amount': 280, 'balanceAfter': 0, 'user': null, 'createdAt': _ago(const Duration(days: 9))},
];

Json _message(String id, String from, String to, String text) =>
    {'_id': id, 'job': 'j2', 'tool': null, 'thread': 'j2', 'sender': from, 'recipient': to, 'text': text, 'image': '', 'readAt': null, 'createdAt': _ago(const Duration(minutes: 20))};

/// Requests the app made, newest last: `POST /api/jobs/j1/accept/b1`.
final List<String> sent = [];
final Map<String, dynamic> sentBodies = {};

dynamic _route(String method, String path, Map<String, String> q, String role) {
  final me = fakeUser(role);
  final id = path.split('/').last;
  Json job(String id) => fakeJobs.firstWhere((j) => j['_id'] == id, orElse: () => fakeJobs.first);

  if (path == '/api/auth/login' || path == '/api/auth/register') return {'token': 'test-token', 'user': _client};
  if (path == '/api/auth/forgot-password') return {'ok': true, 'minutes': 15, 'emailed': false, 'devCode': '482913'};
  if (path == '/api/users/me') return me;
  if (path == '/api/users/me/summary') {
    return {
      'unreadMessages': 2, 'unreadNotifications': 1, 'walletBalance': me['walletBalance'] ?? 0,
      'jobs': {'pending': 2, 'in_progress': 2, 'completed': 1}, 'jobsToConfirm': 1, 'activeRentals': 2, 'spent': 2800,
      'requests': 1, 'activeJobs': 2, 'completedJobs': 12, 'earnings': 28310, 'earningsThisMonth': 3240, 'inEscrow': 2520, 'pendingBids': 1,
      'tools': 3, 'rentals': {'requested': 1, 'active': 2, 'returned': 1}, 'revenue': 17850,
    };
  }
  if (path == '/api/users/me/notifications') {
    return [
      {'_id': 'n1', 'type': 'bid', 'title': 'New quote on your job', 'body': 'Ahmad Raza quoted 2800 for "Fix leaking kitchen sink"', 'data': {'jobId': 'j1'}, 'readAt': null, 'createdAt': _ago(const Duration(minutes: 30))},
      {'_id': 'n2', 'type': 'rental', 'title': 'Your rental was approved', 'body': 'Collect "Bosch Cordless Drill 18V" from Shop 12, Hall Road', 'data': {'rentalId': 'r2'}, 'readAt': _ago(const Duration(days: 1)), 'createdAt': _ago(const Duration(days: 2))},
    ];
  }
  if (path.endsWith('/unread-count')) return {'count': 1};
  if (path == '/api/users/me/favorites') return method == 'POST' ? {'type': 'tool', 'id': 'tool1', 'saved': false} : {'technicians': [_tech1], 'tools': [fakeTools.first]};
  if (path == '/api/users/technicians') return [_tech1, _tech2];
  if (path.startsWith('/api/users/')) return id == 's1' ? _supplier : (id == 't2' ? _tech2 : _tech1);
  if (path.contains('/api/reviews/technician/')) {
    if (path.endsWith('/summary')) return {'count': 12, 'average': 4.7, 'distribution': {'1': 0, '2': 0, '3': 1, '4': 2, '5': 9}};
    return [
      {'id': 'rv1', 'jobTitle': 'Replace bathroom tap', 'category': 'plumbing', 'rating': 5, 'review': 'Quick, tidy and fairly priced.', 'date': _ago(const Duration(days: 9)), 'clientName': 'Sara Khan', 'clientAvatar': ''},
    ];
  }

  if (path == '/api/jobs' && method == 'GET') {
    if (q['view'] == 'requests') return [fakeJobs[5]];
    if (q['view'] == 'bids') return [fakeJobs[0]];
    final status = q['status']?.split(',');
    return [for (final j in fakeJobs) if (status == null || status.contains(j['status'])) j];
  }
  if (path == '/api/jobs') return fakeJobs.first;
  if (path.endsWith('/ranked-bids')) {
    return [
      {'bidId': 'b1', 'technicianId': 't1', ..._tech1, 'amount': 2800, 'etaDays': 0, 'message': 'I can come this afternoon with spare fittings.', 'bidStatus': 'pending',
        'score': 4.45, 'matchPercent': 89, 'reasons': ['Rated 4.7★ by 12 clients', 'Specialises in plumbing', 'Lowest bid'], 'notes': <String>[], 'engine': 'fallback'},
      {'bidId': 'b2', 'technicianId': 't2', ..._tech2, 'amount': 3400, 'etaDays': 1, 'message': '', 'bidStatus': 'pending',
        'score': 2.6, 'matchPercent': 52, 'reasons': ['In your city'], 'notes': ['New on SureFix — no reviews yet'], 'engine': 'fallback'},
    ];
  }
  if (path.startsWith('/api/jobs/')) return job(path.split('/')[3]);

  if (path == '/api/tools' && method == 'GET') return fakeTools;
  if (path.startsWith('/api/tools/') && method == 'GET') {
    return {...fakeTools.firstWhere((t) => t['_id'] == id, orElse: () => fakeTools.first), 'reviews': [
      {'id': 'tr1', 'rating': 5, 'review': 'Worked perfectly, batteries were fully charged.', 'date': _ago(const Duration(days: 12)), 'renterName': 'Bilal Ahmed', 'renterAvatar': ''},
    ]};
  }
  if (path.startsWith('/api/tools')) return _rental('r9', 'rent', 'requested');
  if (path == '/api/rentals') return fakeRentals;
  if (path.startsWith('/api/rentals/')) return fakeRentals.firstWhere((r) => r['_id'] == path.split('/')[3], orElse: () => fakeRentals.first);

  if (path == '/api/wallet') return {'balance': me['walletBalance'] ?? 0, 'held': 9800, 'incoming': 2520, 'feePercent': 10, 'maxTopUp': 100000, 'sandbox': true, 'recent': _txns};
  if (path == '/api/wallet/transactions') return _txns;
  if (path.startsWith('/api/wallet/')) return {'balance': 17700};

  if (path == '/api/messages') {
    return [
      {'kind': 'job', 'jobId': 'j2', 'jobTitle': 'AC not cooling — needs gas refill', 'jobStatus': 'in_progress', 'jobCategory': 'hvac',
        'other': {'id': role == 'client' ? 't1' : 'c1', 'name': role == 'client' ? 'Ahmad Raza' : 'Sara Khan', 'avatar': '', 'role': 'technician', 'online': true},
        'lastMessage': _message('m2', 't1', 'c1', 'On my way, about 20 minutes.'), 'unread': 2},
      {'kind': 'tool', 'toolId': 'tool1', 'toolName': 'Bosch Cordless Drill 18V', 'toolCategory': 'power', 'toolImage': '',
        'other': {'id': 's1', 'name': 'ToolCo Rentals', 'avatar': '', 'role': 'supplier', 'online': false},
        'lastMessage': {..._message('m3', 'c1', 's1', 'Is the charger included?'), 'job': null, 'tool': 'tool1', 'thread': 'tool:tool1'}, 'unread': 0},
    ];
  }
  if (path.startsWith('/api/messages/')) {
    if (method == 'POST') return _message('m9', me['id'] as String, 't1', 'Thanks!');
    return [_message('m1', 'c1', 't1', 'Hi, when can you come?'), _message('m2', 't1', 'c1', 'On my way, about 20 minutes.')];
  }

  if (path == '/api/meta/stats') return {'technicians': 8, 'verifiedTechnicians': 5, 'jobsCompleted': 75, 'tools': 11, 'cities': 4, 'averageRating': 4.6, 'reviews': 75};
  if (path == '/api/meta/testimonials') {
    return [
      {'rating': 5, 'review': 'Excellent work, very professional. Arrived on time and left everything spotless.', 'category': 'hvac', 'jobTitle': 'AC gas refill', 'clientName': 'Kamran B.', 'clientCity': 'Lahore', 'technicianId': 't1', 'technicianName': 'Usman Ali', 'technicianAvatar': ''},
    ];
  }
  const estimate = {'category': 'plumbing', 'urgency': 'high', 'low': 1900, 'high': 5600, 'typical': 3800, 'basis': 'history', 'samples': 14};
  if (path == '/api/ai/status') return {'online': true, 'url': 'http://localhost:5001', 'version': '3.0.0'};
  if (path == '/api/ai/estimate') return estimate;
  if (path == '/api/ai/analyze') return {'category': 'plumbing', 'confidence': 0.82, 'urgency': 'high', 'keywords': ['tap', 'leaking'], 'urgencyTerms': ['today'], 'engine': 'fallback', 'estimate': estimate};
  if (path == '/api/ai/recommend') return {'engine': 'fallback', 'analysis': {'category': 'plumbing', 'confidence': 0.82, 'urgency': 'high', 'keywords': ['tap']}, 'category': 'plumbing', 'urgency': 'high', 'estimate': estimate, 'total': 2, 'ranked': _route('GET', '/x/ranked-bids', q, role)};
  if (path == '/api/kyc/me') return null;

  if (path == '/api/admin/stats') {
    List<Json> week(List<num> v) => [for (var i = 0; i < 7; i++) {'date': DateTime.now().subtract(Duration(days: 6 - i)).toIso8601String().substring(0, 10), 'count': v[i]}];
    return {
      'users': 18, 'jobs': 82, 'tools': 11, 'rentals': 6, 'pendingKyc': 1, 'openReports': 1, 'suspendedUsers': 0,
      'usersByRole': {'client': 7, 'technician': 8, 'supplier': 2, 'admin': 1}, 'jobsByStatus': {'pending': 4, 'in_progress': 2, 'completed': 75, 'cancelled': 1},
      'rentalsByStatus': {'active': 2}, 'topCategories': [{'category': 'hvac', 'count': 12}, {'category': 'plumbing', 'count': 12}, {'category': 'electrical', 'count': 9}],
      'jobsValue': 378000, 'rentalsValue': 17850, 'platformRevenue': 25990, 'escrowHeld': 15000, 'feePercent': 10, 'jobsPaidBy': {'wallet': 60, 'cash': 15}, 'avgTechnicianRating': 4.45,
      'signupsLast7Days': week([1, 1, 2, 1, 2, 1, 0]), 'jobsLast7Days': week([0, 0, 0, 7, 1, 2, 3]), 'revenueLast7Days': week([0, 0, 0, 0, 3180, 0, 0]),
    };
  }
  if (path == '/api/admin/users') return [_client, _tech1, _tech2, _supplier, _admin];
  if (path == '/api/admin/kyc') return [{'_id': 'k1', 'user': {'_id': 't2', 'name': 'Noor Fatima', 'email': 'tech2@demo.com', 'role': 'technician', 'avatar': '', 'city': 'Lahore'}, 'fullName': 'Noor Fatima', 'idType': 'cnic', 'idNumber': '35202-1234567-1', 'idFrontImage': '', 'idBackImage': '', 'selfieImage': '', 'status': 'pending', 'createdAt': _ago(const Duration(hours: 4))}];
  if (path == '/api/admin/reports') return [{'_id': 'rp1', 'reporter': {'_id': 'c1', 'name': 'Sara Khan', 'email': 'client@demo.com', 'role': 'client', 'avatar': ''}, 'targetType': 'user', 'targetId': 't2', 'targetLabel': 'Noor Fatima (technician)', 'reason': 'no_show', 'details': 'Agreed a time twice and never arrived.', 'status': 'open', 'createdAt': _ago(const Duration(hours: 6))}];
  if (path == '/api/admin/jobs') return fakeJobs;
  if (path == '/api/admin/tools') return fakeTools;
  if (path == '/api/admin/transactions') return [for (final t in _txns) {...t, 'user': {'_id': 'c1', 'name': 'Sara Khan', 'role': 'client', 'avatar': ''}}];
  return {'ok': true};
}

/// Routes every API call to the fake backend, answering as [role].
void installFakeApi(String role) {
  sent.clear();
  sentBodies.clear();
  Api.client = MockClient((request) async {
    final key = '${request.method} ${request.url.path}';
    if (request.method != 'GET') {
      sent.add(key);
      try {
        sentBodies[key] = jsonDecode(request.body);
      } catch (_) {
        sentBodies[key] = request.body;
      }
    }
    final body = _route(request.method, request.url.path, request.url.queryParameters, role);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

/// Signs in as [role] (or out, with null) without touching the network.
void signIn(String? role) {
  Session.instance.token = role == null ? null : 'test-token';
  Session.instance.user = role == null ? null : User.fromJson(fakeUser(role));
  SiteNav.section.value = 'home';
  Settings.instance.introSeen = true;
  Settings.instance.themeMode = ThemeMode.light;
  installFakeApi(role ?? 'client');
}

/// Loads the app's real fonts so text measures as it does on a device
/// (the default test font is much wider and would report false overflows).
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'introSeen': true});
  Future<void> family(String name, String file, List<int> weights) async {
    final loader = FontLoader(name);
    for (final w in weights) {
      loader.addFont(File('assets/fonts/$file-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  }

  await family('Jakarta', 'PlusJakartaSans', [400, 500, 600, 700, 800]);
  await family('Bricolage', 'BricolageGrotesque', [500, 600, 700, 800]);
}
