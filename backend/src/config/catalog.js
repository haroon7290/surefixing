// Single source of truth for marketplace taxonomies. The mobile app fetches
// these from GET /api/meta so labels stay consistent across clients; the AI
// service uses the same category keys for its classifier.

const SERVICE_CATEGORIES = [
  { key: 'plumbing', label: 'Plumbing' },
  { key: 'electrical', label: 'Electrical' },
  { key: 'carpentry', label: 'Carpentry' },
  { key: 'painting', label: 'Painting' },
  { key: 'appliance', label: 'Appliance repair' },
  { key: 'hvac', label: 'AC & heating' },
  { key: 'cleaning', label: 'Cleaning' },
  { key: 'masonry', label: 'Masonry & tiling' },
  { key: 'roofing', label: 'Roofing' },
  { key: 'pest_control', label: 'Pest control' },
  { key: 'locksmith', label: 'Locksmith' },
  { key: 'general', label: 'General handyman' }
];

const TOOL_CATEGORIES = [
  { key: 'power', label: 'Power tools' },
  { key: 'hand', label: 'Hand tools' },
  { key: 'measurement', label: 'Measurement' },
  { key: 'plumbing', label: 'Plumbing' },
  { key: 'electrical', label: 'Electrical' },
  { key: 'gardening', label: 'Gardening' },
  { key: 'cleaning', label: 'Cleaning' },
  { key: 'ladders', label: 'Ladders & access' },
  { key: 'general', label: 'General' }
];

const URGENCY_LEVELS = ['low', 'normal', 'high', 'emergency'];

const TOOL_CONDITIONS = ['new', 'like_new', 'good', 'fair'];

const REPORT_REASONS = ['spam', 'fraud', 'inappropriate', 'no_show', 'poor_quality', 'other'];

const serviceCategoryKeys = SERVICE_CATEGORIES.map((c) => c.key);
const toolCategoryKeys = TOOL_CATEGORIES.map((c) => c.key);

module.exports = {
  SERVICE_CATEGORIES,
  TOOL_CATEGORIES,
  URGENCY_LEVELS,
  TOOL_CONDITIONS,
  REPORT_REASONS,
  serviceCategoryKeys,
  toolCategoryKeys
};
