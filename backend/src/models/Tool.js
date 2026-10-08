const mongoose = require('mongoose');
const { TOOL_CONDITIONS } = require('../config/catalog');

const toolSchema = new mongoose.Schema(
  {
    supplier: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    name: { type: String, required: true, trim: true },
    description: { type: String, default: '' },
    category: { type: String, default: 'general' },
    condition: { type: String, enum: TOOL_CONDITIONS, default: 'good' },
    city: { type: String, default: '', trim: true },
    image: { type: String, default: '' }, // cover image (kept for older clients)
    images: { type: [String], default: [] },
    rentPricePerDay: { type: Number, default: 0, min: 0 },
    deposit: { type: Number, default: 0, min: 0 },
    purchasePrice: { type: Number, default: 0, min: 0 },
    installmentMonths: { type: Number, default: 0, min: 0 }, // 0 = not available on installment
    installmentMonthly: { type: Number, default: 0, min: 0 },
    // Supplier-controlled "listed" switch. Stock is tracked separately.
    available: { type: Boolean, default: true },
    stock: { type: Number, default: 1, min: 0 },
    rating: { type: Number, default: 0 },
    ratingCount: { type: Number, default: 0 },
    rentalsCount: { type: Number, default: 0 }
  },
  { timestamps: true }
);

toolSchema.index({ available: 1, category: 1, createdAt: -1 });

// Fields a supplier may set through the API (everything else is managed by
// the server — e.g. supplier, rating, rentalsCount).
toolSchema.statics.EDITABLE = [
  'name',
  'description',
  'category',
  'condition',
  'city',
  'rentPricePerDay',
  'deposit',
  'purchasePrice',
  'installmentMonths',
  'installmentMonthly',
  'available',
  'stock'
];

module.exports = mongoose.model('Tool', toolSchema);
