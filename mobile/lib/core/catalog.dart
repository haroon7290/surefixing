import 'package:flutter/material.dart';

/// Visual metadata for the taxonomies defined in backend/src/config/catalog.js.
/// Keys must match the backend; labels/icons/colours are presentation only.
class CategoryInfo {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const CategoryInfo(this.key, this.label, this.icon, this.color);
}

class Catalog {
  static const services = <CategoryInfo>[
    CategoryInfo('plumbing', 'Plumbing', Icons.plumbing, Color(0xFF2E90FA)),
    CategoryInfo('electrical', 'Electrical', Icons.electrical_services, Color(0xFFF79009)),
    CategoryInfo('hvac', 'AC & heating', Icons.ac_unit, Color(0xFF06AED4)),
    CategoryInfo('appliance', 'Appliances', Icons.kitchen, Color(0xFF7A5AF8)),
    CategoryInfo('carpentry', 'Carpentry', Icons.carpenter, Color(0xFFB54708)),
    CategoryInfo('painting', 'Painting', Icons.format_paint, Color(0xFFEE46BC)),
    CategoryInfo('cleaning', 'Cleaning', Icons.cleaning_services, Color(0xFF12B76A)),
    CategoryInfo('masonry', 'Masonry & tiling', Icons.foundation, Color(0xFF667085)),
    CategoryInfo('roofing', 'Roofing', Icons.roofing, Color(0xFFE04F16)),
    CategoryInfo('pest_control', 'Pest control', Icons.pest_control, Color(0xFF4CA30D)),
    CategoryInfo('locksmith', 'Locksmith', Icons.key, Color(0xFFDC6803)),
    CategoryInfo('general', 'Handyman', Icons.handyman, Color(0xFF2F54EB)),
  ];

  static const tools = <CategoryInfo>[
    CategoryInfo('power', 'Power tools', Icons.bolt_rounded, Color(0xFFF79009)),
    CategoryInfo('hand', 'Hand tools', Icons.hardware_rounded, Color(0xFFB54708)),
    CategoryInfo('measurement', 'Measurement', Icons.straighten, Color(0xFF7A5AF8)),
    CategoryInfo('plumbing', 'Plumbing', Icons.plumbing, Color(0xFF2E90FA)),
    CategoryInfo('electrical', 'Electrical', Icons.electrical_services, Color(0xFFDC6803)),
    CategoryInfo('gardening', 'Gardening', Icons.grass, Color(0xFF4CA30D)),
    CategoryInfo('cleaning', 'Cleaning', Icons.cleaning_services, Color(0xFF12B76A)),
    CategoryInfo('ladders', 'Ladders', Icons.stairs, Color(0xFF06AED4)),
    CategoryInfo('general', 'General', Icons.build, Color(0xFF667085)),
  ];

  static const _fallback = CategoryInfo('general', 'General', Icons.handyman, Color(0xFF2F54EB));

  static CategoryInfo service(String? key) => services.firstWhere((c) => c.key == key, orElse: () => _fallback);

  static CategoryInfo tool(String? key) => tools.firstWhere((c) => c.key == key, orElse: () => tools.last);

  static const toolConditions = {
    'new': 'New',
    'like_new': 'Like new',
    'good': 'Good',
    'fair': 'Fair',
  };

  static const reportReasons = {
    'no_show': 'Didn\'t show up',
    'poor_quality': 'Poor quality work',
    'fraud': 'Fraud or scam',
    'inappropriate': 'Inappropriate behaviour',
    'spam': 'Spam or fake',
    'other': 'Something else',
  };
}

class UrgencyInfo {
  final String key;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  const UrgencyInfo(this.key, this.label, this.hint, this.icon, this.color);

  static const all = <UrgencyInfo>[
    UrgencyInfo('low', 'Flexible', 'Any time this week', Icons.schedule, Color(0xFF667085)),
    UrgencyInfo('normal', 'Normal', 'Within a few days', Icons.event_available, Color(0xFF2E90FA)),
    UrgencyInfo('high', 'Urgent', 'Today if possible', Icons.bolt, Color(0xFFF79009)),
    UrgencyInfo('emergency', 'Emergency', 'Right now — safety risk', Icons.warning_amber_rounded, Color(0xFFF04438)),
  ];

  static UrgencyInfo of(String? key) => all.firstWhere((u) => u.key == key, orElse: () => all[1]);
}
