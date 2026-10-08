const mongoose = require('mongoose');

const rentalSchema = new mongoose.Schema(
  {
    tool: { type: mongoose.Schema.Types.ObjectId, ref: 'Tool', required: true },
    renter: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    type: { type: String, enum: ['rent', 'installment'], required: true },
    startDate: { type: Date, default: Date.now },
    endDate: { type: Date },
    days: { type: Number, default: 0 },
    totalCost: { type: Number, default: 0 },
    monthsRemaining: { type: Number, default: 0 },
    status: { type: String, enum: ['active', 'returned', 'completed'], default: 'active' }
  },
  { timestamps: true }
);

module.exports = mongoose.model('Rental', rentalSchema);
