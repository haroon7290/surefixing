const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const ROLES = ['client', 'technician', 'supplier', 'admin'];

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

    // Technician professional profile.
    headline: { type: String, default: '', trim: true },
    skills: { type: [String], default: [] },
    hourlyRate: { type: Number, default: 0, min: 0 },
    experienceYears: { type: Number, default: 0, min: 0 },
    isAvailable: { type: Boolean, default: true },

    // Technician stats used by the AI ranker.
    rating: { type: Number, default: 0 }, // 0-5 running average
    ratingCount: { type: Number, default: 0 },
    jobsCompleted: { type: Number, default: 0 },
    jobsAssigned: { type: Number, default: 0 },
    avgResponseMinutes: { type: Number, default: 60 },
    responseSamples: { type: Number, default: 0 },

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
    rating: u.rating,
    ratingCount: u.ratingCount,
    jobsCompleted: u.jobsCompleted,
    jobsAssigned: u.jobsAssigned,
    avgResponseMinutes: u.avgResponseMinutes,
    lastSeenAt: u.lastSeenAt,
    createdAt: u.createdAt
  };
}

// Full projection — for the account owner and admins.
userSchema.methods.toPublicJSON = function () {
  return {
    ...profileFields(this),
    email: this.email,
    phone: this.phone,
    status: this.status
  };
};

// What other marketplace users may see: no email/phone.
userSchema.methods.toProfileJSON = function () {
  return profileFields(this);
};

module.exports = mongoose.model('User', userSchema);
module.exports.ROLES = ROLES;
