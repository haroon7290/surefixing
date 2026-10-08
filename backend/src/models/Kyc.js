const mongoose = require('mongoose');

const kycSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
    fullName: { type: String, required: true },
    idType: { type: String, enum: ['cnic', 'passport', 'driver_license'], required: true },
    idNumber: { type: String, required: true },
    idFrontImage: { type: String, default: '' },
    idBackImage: { type: String, default: '' },
    selfieImage: { type: String, default: '' },
    status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' },
    rejectionReason: { type: String, default: '' }
  },
  { timestamps: true }
);

module.exports = mongoose.model('Kyc', kycSchema);
