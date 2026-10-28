const mongoose = require('mongoose');

const adminAuditLogSchema = new mongoose.Schema(
  {
    adminId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    adminName: {
      type: String,
      required: true,
      trim: true,
    },
    adminEmail: {
      type: String,
      required: true,
      trim: true,
    },
    targetType: {
      type: String,
      enum: ['supplier', 'customer', 'payment', 'commission'],
      required: true,
      index: true,
    },
    targetId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    targetUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    targetName: {
      type: String,
      default: '',
      trim: true,
    },
    action: {
      type: String,
      enum: [
        'lock_supplier',
        'unlock_supplier',
        'lock_customer',
        'unlock_customer',
        'manual_settlement',
        'approve_supplier',
        'reject_supplier',
        'approve_customer',
        'reject_customer',
      ],
      required: true,
      index: true,
    },
    reason: {
      type: String,
      default: '',
      trim: true,
    },
    previousState: {
      type: String,
      default: '',
    },
    newState: {
      type: String,
      default: '',
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
  },
  { timestamps: true }
);

adminAuditLogSchema.index({ targetType: 1, targetId: 1, createdAt: -1 });

module.exports = mongoose.model('AdminAuditLog', adminAuditLogSchema);
