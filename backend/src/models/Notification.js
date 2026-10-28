const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: [
        'booking_requested',
        'booking_accepted',
        'booking_rejected',
        'delivery_dispatched',
        'delivery_arriving',
        'delivery_completed',
        'supplier_cancelled',
        'customer_cancelled',
        'alternatives_found',
        'review_reminder',
        'commission_recorded',
        'settlement_recorded',
        'schedule_info',
        'account_update',
        'account_locked',
        'account_unlocked',
      ],
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    body: {
      type: String,
      required: true,
    },
    bookingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      default: null,
    },
    bookingCode: {
      type: String,
      default: '',
    },
    isRead: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Notification', notificationSchema);
