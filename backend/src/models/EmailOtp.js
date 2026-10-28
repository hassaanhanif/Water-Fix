const mongoose = require('mongoose');

const emailOtpSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    otpHash: {
      type: String,
      required: true,
    },
    attempts: {
      type: Number,
      default: 0,
      min: 0,
    },
    maxAttempts: {
      type: Number,
      default: 5,
    },
    expiresAt: {
      type: Date,
      required: true,
      index: true,
    },
    resendAvailableAt: {
      type: Date,
      required: true,
    },
    isUsed: {
      type: Boolean,
      default: false,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    purpose: {
      type: String,
      enum: ['registration', 'verification', 'password_reset'],
      default: 'registration',
    },
  },
  { timestamps: true }
);

// TTL index to automatically purge expired OTP documents after 1 hour
emailOtpSchema.index({ createdAt: 1 }, { expireAfterSeconds: 3600 });

module.exports = mongoose.model('EmailOtp', emailOtpSchema);
