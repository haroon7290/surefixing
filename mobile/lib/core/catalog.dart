import 'package:flutter/material.dart';

import '../ui/icons.dart';
import 'format.dart';
import 'theme.dart';

/// Marketplace taxonomies with how each one looks. The keys match the
/// backend (`src/config/catalog.js`) and the AI service.
class CatalogItem {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const CatalogItem(this.key, this.label, this.icon, this.color);

  /// Soft tile background that works on light and dark surfaces.
  Color get tint => color.withValues(alpha: 0.14);
}

const serviceCategories = [
  CatalogItem('plumbing', 'Plumbing', AppIcons.plumbing, Color(0xFF2E7BE8)),
  CatalogItem('electrical', 'Electrical', AppIcons.electrical, Color(0xFFE5A100)),
  CatalogItem('hvac', 'AC & heating', AppIcons.hvac, Color(0xFF14A3C7)),
  CatalogItem('appliance', 'Appliance repair', AppIcons.appliance, Color(0xFF7C5CFC)),
  CatalogItem('carpentry', 'Carpentry', AppIcons.carpentry, Color(0xFFB7693A)),
  CatalogItem('painting', 'Painting', AppIcons.painting, Color(0xFFE5488B)),
  CatalogItem('cleaning', 'Cleaning', AppIcons.cleaning, Color(0xFF12A679)),
  CatalogItem('masonry', 'Masonry & tiling', AppIcons.masonry, Color(0xFF8C7A66)),
  CatalogItem('roofing', 'Roofing', AppIcons.roofing, Color(0xFFD9512C)),
  CatalogItem('pest_control', 'Pest control', AppIcons.pest, Color(0xFF6F9E1C)),
  CatalogItem('locksmith', 'Locksmith', AppIcons.locksmith, Color(0xFF5A6ACF)),
  CatalogItem('general', 'General handyman', AppIcons.wrench, Color(0xFFFF5A1F)),
];

const toolCategories = [
  CatalogItem('power', 'Power tools', AppIcons.powerTools, Color(0xFFFF5A1F)),
  CatalogItem('hand', 'Hand tools', AppIcons.handTools, Color(0xFFB7693A)),
  CatalogItem('measurement', 'Measurement', AppIcons.measurement, Color(0xFF7C5CFC)),
  CatalogItem('plumbing', 'Plumbing', AppIcons.pipe, Color(0xFF2E7BE8)),
  CatalogItem('electrical', 'Electrical', AppIcons.electrical, Color(0xFFE5A100)),
  CatalogItem('gardening', 'Gardening', AppIcons.gardening, Color(0xFF12A679)),
  CatalogItem('cleaning', 'Cleaning', AppIcons.cleaning, Color(0xFF14A3C7)),
  CatalogItem('ladders', 'Ladders & access', AppIcons.ladder, Color(0xFFD9512C)),
  CatalogItem('general', 'General', AppIcons.tools, Color(0xFF5A6ACF)),
];

CatalogItem serviceCategory(String key) => serviceCategories.firstWhere((c) => c.key == key, orElse: () => serviceCategories.last);

CatalogItem toolCategory(String key) => toolCategories.firstWhere((c) => c.key == key, orElse: () => toolCategories.last);

/// Label for a skill: a known category's name, or the skill tidied up.
String skillLabel(String key) {
  for (final c in serviceCategories) {
    if (c.key == key) return c.label;
  }
  return humanize(key);
}

const urgencyLevels = ['low', 'normal', 'high', 'emergency'];

String urgencyLabel(String key) => const {'low': 'Flexible', 'normal': 'This week', 'high': 'Urgent', 'emergency': 'Emergency'}[key] ?? humanize(key);

Tone urgencyTone(String key) => const {'low': Tone.neutral, 'normal': Tone.info, 'high': Tone.warning, 'emergency': Tone.danger}[key] ?? Tone.neutral;

const toolConditions = {'new': 'New', 'like_new': 'Like new', 'good': 'Good', 'fair': 'Fair'};

const reportReasons = {
  'spam': 'Spam or fake',
  'fraud': 'Fraud or scam',
  'inappropriate': 'Inappropriate behaviour',
  'no_show': "Didn't show up",
  'poor_quality': 'Poor quality work',
  'payment': 'Payment problem',
  'other': 'Something else',
};

const idTypes = {'cnic': 'CNIC', 'passport': 'Passport', 'driver_license': "Driver's licence"};

const cities = ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan', 'Peshawar', 'Quetta', 'Sialkot', 'Gujranwala'];

const roleLabels = {'client': 'Customer', 'technician': 'Technician', 'supplier': 'Tool supplier', 'admin': 'Admin'};

// ------------------------------------------------------------- statuses

/// Label + colour for a job, taking progress into account.
(String, Tone) jobStatus(String status, {String stage = 'hired', bool directRequest = false, bool declined = false}) => switch (status) {
      'pending' => declined ? ('Request declined', Tone.danger) : (directRequest ? ('Awaiting reply', Tone.info) : ('Getting quotes', Tone.info)),
      'in_progress' => switch (stage) {
          'on_the_way' => ('On the way', Tone.brand),
          'working' => ('Work in progress', Tone.brand),
          'done' => ('Confirm completion', Tone.warning),
          _ => ('Hired', Tone.brand),
        },
      'completed' => ('Completed', Tone.success),
      'cancelled' => ('Cancelled', Tone.neutral),
      _ => (humanize(status), Tone.neutral),
    };

const stageLabels = {'hired': 'Hired', 'on_the_way': 'On the way', 'working': 'Working', 'done': 'Finished'};

(String, Tone) rentalStatus(String status, {bool installment = false, bool overdue = false}) => switch (status) {
      'requested' => ('Awaiting approval', Tone.info),
      'active' => overdue ? ('Overdue', Tone.danger) : (installment ? ('Paying monthly', Tone.brand) : ('Rented out', Tone.brand)),
      'returned' => ('Returned', Tone.success),
      'completed' => ('Paid off', Tone.success),
      'rejected' => ('Declined', Tone.danger),
      'cancelled' => ('Cancelled', Tone.neutral),
      _ => (humanize(status), Tone.neutral),
    };

(String, Tone) paymentStatus(String status) => switch (status) {
      'held' => ('In escrow', Tone.info),
      'released' => ('Paid out', Tone.success),
      'refunded' => ('Refunded', Tone.neutral),
      'cash_due' => ('Cash on completion', Tone.warning),
      'cash_paid' => ('Paid in cash', Tone.success),
      _ => ('Not paid', Tone.neutral),
    };

(String, Tone) kycStatus(String status) => switch (status) {
      'approved' => ('Verified', Tone.success),
      'pending' => ('Under review', Tone.warning),
      'rejected' => ('Rejected', Tone.danger),
      _ => ('Not verified', Tone.neutral),
    };

/// Title + icon + whether money came in, for a wallet ledger row.
(String, IconData) txnInfo(String type) => switch (type) {
      'topup' => ('Funds added', AppIcons.topUp),
      'withdrawal' => ('Withdrawal', AppIcons.withdraw),
      'job_hold' => ('Paid into escrow', AppIcons.lock),
      'job_refund' => ('Job refund', AppIcons.refresh),
      'job_earning' => ('Job earnings', AppIcons.work),
      'rental_hold' => ('Rental payment held', AppIcons.lock),
      'rental_refund' => ('Rental refund', AppIcons.refresh),
      'rental_earning' => ('Rental income', AppIcons.tools),
      'installment_payment' => ('Installment paid', AppIcons.calendar),
      'installment_earning' => ('Installment received', AppIcons.calendar),
      'platform_fee' => ('Service fee', AppIcons.payments),
      _ => (humanize(type), AppIcons.coins),
    };
