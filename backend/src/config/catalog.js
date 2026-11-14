// Single source of truth for marketplace taxonomies. The app reads these
// from GET /api/meta; the AI service uses the same category keys.

// `price` is a typical job price range (PKR) used for estimates until the
// marketplace has enough completed jobs in that category to learn from.
const SERVICE_CATEGORIES = [
  { key: 'plumbing', label: 'Plumbing', price: [1500, 4500] },
  { key: 'electrical', label: 'Electrical', price: [1200, 4000] },
  { key: 'hvac', label: 'AC & heating', price: [2500, 7000] },
  { key: 'appliance', label: 'Appliance repair', price: [2000, 6000] },
  { key: 'carpentry', label: 'Carpentry', price: [2000, 8000] },
  { key: 'painting', label: 'Painting', price: [5000, 25000] },
  { key: 'cleaning', label: 'Cleaning', price: [2000, 7000] },
  { key: 'masonry', label: 'Masonry & tiling', price: [4000, 20000] },
  { key: 'roofing', label: 'Roofing', price: [5000, 30000] },
  { key: 'pest_control', label: 'Pest control', price: [2500, 8000] },
  { key: 'locksmith', label: 'Locksmith', price: [1000, 3500] },
  { key: 'general', label: 'General handyman', price: [1000, 5000] }
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

const REPORT_REASONS = ['spam', 'fraud', 'inappropriate', 'no_show', 'poor_quality', 'payment', 'other'];

// A hired job moves through these stages before the client confirms it.
const JOB_STAGES = ['hired', 'on_the_way', 'working', 'done'];

const PAYMENT_METHODS = ['wallet', 'cash'];

const serviceCategoryKeys = SERVICE_CATEGORIES.map((c) => c.key);
const toolCategoryKeys = TOOL_CATEGORIES.map((c) => c.key);

module.exports = {
  SERVICE_CATEGORIES,
  TOOL_CATEGORIES,
  URGENCY_LEVELS,
  TOOL_CONDITIONS,
  REPORT_REASONS,
  JOB_STAGES,
  PAYMENT_METHODS,
  serviceCategoryKeys,
  toolCategoryKeys
};
