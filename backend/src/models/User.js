const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const ROLES = ['client', 'technician', 'supplier', 'admin'];
const PORTFOLIO_MAX = 8;

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    phone: { type: String, trim: true },
    password: { type: String, required: true },
    role: { type: String, enum: ROLES, required: true, index: true },
    status: { type: String, enum: ['active', 'suspended'], default: 'active' },
    kycStatus: { type: String, enum: ['none', 'pending', 'approved', 'rejected'], default: 'none' },
    avatar: { type: String, default: '' },
    bio: { type: String, default: '' },
    city: { type: String, default: '', trim: true },
    // Street address. Suppliers: where customers collect tools (shared with a
    // renter once a request is approved). Others: default delivery address.
    // Never shown on public profiles.
    address: { type: String, default: '', trim: true, maxlength: 300 },

    // Technician professional profile.
    headline: { type: String, default: '', trim: true },
    skills: { type: [String], default: [] },
    hourlyRate: { type: Number, default: 0, min: 0 },
    experienceYears: { type: Number, default: 0, min: 0 },
    isAvailable: { type: Boolean, default: true },
    portfolio: { type: [String], default: [] }, // photos of past work

    // Technician stats used by the AI ranker.
    rating: { type: Number, default: 0 }, // 0-5 running average
    ratingCount: { type: Number, default: 0 },
    jobsCompleted: { type: Number, default: 0 },
    jobsAssigned: { type: Number, default: 0 },
    avgResponseMinutes: { type: Number, default: 60 },
    responseSamples: { type: Number, default: 0 },

    // Wallet balance; every change has a Transaction row.
    walletBalance: { type: Number, default: 0, min: 0 },
    // Where withdrawals are sent (remembered from the last request).
    payoutAccount: {
      method: { type: String, enum: ['bank', 'mobile_wallet'], default: 'bank' },
      provider: { type: String, default: '', trim: true },
      accountTitle: { type: String, default: '', trim: true },
      accountNumber: { type: String, default: '', trim: true }
    },

    favoriteTechnicians: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    favoriteTools: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Tool' }],

    // Password reset: bcrypt hash of a 6-digit code, valid for a few minutes.
    resetCodeHash: { type: String, default: '' },
    resetCodeExpires: { type: Date, default: null },
    resetAttempts: { type: Number, default: 0 },

    lastSeenAt: { type: Date, default: null }
  },
  { timestamps: true }
);

userSchema.index({ role: 1, rating: -1 });

userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

userSchema.methods.matchPassword = function (plain) {
  return bcrypt.compare(plain, this.password);
};

// Folds one more "minutes until first response" sample into the running
// average the ranker uses for responsiveness.
userSchema.methods.recordResponse = function (minutes) {
  const m = Math.max(0, Math.min(minutes, 7 * 24 * 60));
  const n = this.responseSamples || 0;
  this.avgResponseMinutes = n === 0 ? m : (this.avgResponseMinutes * n + m) / (n + 1);
  this.responseSamples = n + 1;
};

function profileFields(u) {
  return {
    id: u._id,
    name: u.name,
    role: u.role,
    kycStatus: u.kycStatus,
    avatar: u.avatar,
    bio: u.bio,
    city: u.city,
    headline: u.headline,
    skills: u.skills,
    hourlyRate: u.hourlyRate,
    experienceYears: u.experienceYears,
    isAvailable: u.isAvailable,
    portfolio: u.portfolio,
    rating: u.rating,
    ratingCount: u.ratingCount,
    jobsCompleted: u.jobsCompleted,
    jobsAssigned: u.jobsAssigned,
    avgResponseMinutes: u.avgResponseMinutes,
    lastSeenAt: u.lastSeenAt,
    createdAt: u.createdAt
  };
}

// Everything about an account — for its owner and admins.
userSchema.methods.toPrivateJSON = function () {
  return {
    ...profileFields(this),
    email: this.email,
    phone: this.phone,
    address: this.address,
    status: this.status,
    walletBalance: this.walletBalance,
    payoutAccount: this.payoutAccount,
    favoriteTechnicians: this.favoriteTechnicians,
    favoriteTools: this.favoriteTools
  };
};

// What other marketplace users (and website visitors) may see.
userSchema.methods.toProfileJSON = function () {
  return profileFields(this);
};

module.exports = mongoose.model('User', userSchema);
module.exports.ROLES = ROLES;
module.exports.PORTFOLIO_MAX = PORTFOLIO_MAX;
