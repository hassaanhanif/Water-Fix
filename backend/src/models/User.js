const mongoose = require('mongoose');
const { maskCnic } = require('../utils/validators');

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    phone: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      index: true,
    },
    passwordHash: {
      type: String,
      required: true,
      select: false,
    },
    role: {
      type: String,
      enum: ['customer', 'supplier', 'admin'],
      required: true,
      default: 'customer',
    },
    customerCategory: {
      type: String,
      enum: ['Household', 'Construction site', 'Property', 'Business'],
      default: 'Household',
    },
    preferences: {
      defaultCapacityLiters: { type: Number, default: 2000 },
      scheduleMode: { type: String, enum: ['One time', 'Recurring'], default: 'Recurring' },
      repeatDays: { type: [String], default: ['Mon', 'Thu'] },
      deliveryWindow: { type: String, default: 'Morning' },
      scheduleQuantityLiters: { type: Number, default: 2000 },
      scheduleActive: { type: Boolean, default: false },
    },
    favorites: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'SupplierProfile',
      },
    ],
    isActive: {
      type: Boolean,
      default: true,
    },
    isLocked: {
      type: Boolean,
      default: false,
      index: true,
    },
    lockReason: {
      type: String,
      default: '',
      trim: true,
    },
    lockedAt: {
      type: Date,
      default: null,
    },
    lockedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    lockedByName: {
      type: String,
      default: '',
      trim: true,
    },
    unlockedAt: {
      type: Date,
      default: null,
    },
    unlockedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    unlockedByName: {
      type: String,
      default: '',
      trim: true,
    },
    // CNIC & Identity Information (Pakistan 13-digit standard)
    cnicNumber: {
      type: String,
      default: '',
      trim: true,
    },
    emailVerified: {
      type: Boolean,
      default: false,
      index: true,
    },
    approvalStatus: {
      type: String,
      enum: ['pending_approval', 'approved', 'rejected'],
      default: 'pending_approval',
      index: true,
    },
    approvedAt: {
      type: Date,
      default: null,
    },
    approvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    approvedByName: {
      type: String,
      default: '',
      trim: true,
    },
    rejectedAt: {
      type: Date,
      default: null,
    },
    rejectedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    rejectedByName: {
      type: String,
      default: '',
      trim: true,
    },
    rejectionReason: {
      type: String,
      default: '',
      trim: true,
    },
  },
  { timestamps: true }
);

userSchema.methods.toSafeJSON = function () {
  const obj = this.toObject();
  delete obj.passwordHash;
  if (obj.cnicNumber) {
    obj.cnicMasked = maskCnic(obj.cnicNumber);
    delete obj.cnicNumber;
  } else {
    obj.cnicMasked = '';
  }
  return obj;
};

module.exports = mongoose.model('User', userSchema);
