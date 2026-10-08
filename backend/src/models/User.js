const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const ROLES = ['client', 'technician', 'supplier', 'admin'];

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    phone: { type: String, trim: true },
    password: { type: String, required: true },
    role: { type: String, enum: ROLES, required: true },
    kycStatus: { type: String, enum: ['none', 'pending', 'approved', 'rejected'], default: 'none' },
    // Technician-specific stats used by the AI ranker.
    rating: { type: Number, default: 0 },           // 0-5
    ratingCount: { type: Number, default: 0 },
    jobsCompleted: { type: Number, default: 0 },
    jobsAssigned: { type: Number, default: 0 },
    avgResponseMinutes: { type: Number, default: 60 },
    skills: { type: [String], default: [] },
    bio: { type: String, default: '' },
    avatar: { type: String, default: '' }
  },
  { timestamps: true }
);

userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

userSchema.methods.matchPassword = function (plain) {
  return bcrypt.compare(plain, this.password);
};

userSchema.methods.toPublicJSON = function () {
  return {
    id: this._id,
    name: this.name,
    email: this.email,
    phone: this.phone,
    role: this.role,
    kycStatus: this.kycStatus,
    rating: this.rating,
    ratingCount: this.ratingCount,
    jobsCompleted: this.jobsCompleted,
    jobsAssigned: this.jobsAssigned,
    avgResponseMinutes: this.avgResponseMinutes,
    skills: this.skills,
    bio: this.bio,
    avatar: this.avatar,
    createdAt: this.createdAt
  };
};

module.exports = mongoose.model('User', userSchema);
module.exports.ROLES = ROLES;
