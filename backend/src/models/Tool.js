const mongoose = require('mongoose');

const toolSchema = new mongoose.Schema(
  {
    supplier: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    name: { type: String, required: true },
    description: { type: String, default: '' },
    category: { type: String, default: 'general' },
    image: { type: String, default: '' },
    rentPricePerDay: { type: Number, default: 0 },
    purchasePrice: { type: Number, default: 0 },
    installmentMonths: { type: Number, default: 0 },      // 0 = not available on installment
    installmentMonthly: { type: Number, default: 0 },
    available: { type: Boolean, default: true },
    stock: { type: Number, default: 1 }
  },
  { timestamps: true }
);

module.exports = mongoose.model('Tool', toolSchema);
