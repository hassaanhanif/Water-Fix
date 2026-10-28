const mongoose = require('mongoose');

const paymentAllocationSchema = new mongoose.Schema(
  {
    ledgerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CommissionLedger',
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
    amountAllocated: {
      type: Number,
      required: true,
      min: 0,
    },
  },
  { _id: false }
);

const commissionPaymentSchema = new mongoose.Schema(
  {
    paymentReference: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    supplierId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'SupplierProfile',
      required: true,
      index: true,
    },
    supplierUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 1,
    },
    currency: {
      type: String,
      required: true,
      default: 'PKR',
      enum: ['PKR'],
    },
    provider: {
      type: String,
      required: true,
      default: 'Safepay',
      enum: ['Safepay', 'Manual Admin Settlement'],
    },
    environment: {
      type: String,
      required: true,
      default: 'sandbox',
      enum: ['sandbox', 'production'],
    },
    tracker: {
      type: String,
      index: true,
      default: null,
    },
    providerReference: {
      type: String,
      default: null,
    },
    checkoutUrl: {
      type: String,
      default: null,
    },
    returnTarget: {
      type: String,
      enum: ['wallet', 'orders', 'listings', 'account'],
      default: 'wallet',
    },
    clientOrigin: {
      type: String,
      default: null,
    },
    clientRedirectUrl: {
      type: String,
      default: null,
    },
    status: {
      type: String,
      required: true,
      enum: ['pending', 'paid', 'failed', 'cancelled', 'expired', 'refunded'],
      default: 'pending',
      index: true,
    },
    outstandingBefore: {
      type: Number,
      required: true,
      default: 0,
    },
    outstandingAfter: {
      type: Number,
      default: null,
    },
    allocations: {
      type: [paymentAllocationSchema],
      default: [],
    },
    webhookEventIds: {
      type: [String],
      default: [],
    },
    verifiedVia: {
      type: String,
      default: null,
    },
    verifiedAt: {
      type: Date,
      default: null,
    },
    failedAt: {
      type: Date,
      default: null,
    },
    cancelledAt: {
      type: Date,
      default: null,
    },
    refundedAt: {
      type: Date,
      default: null,
    },
    failureReason: {
      type: String,
      default: null,
    },
    notes: {
      type: String,
      default: '',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('CommissionPayment', commissionPaymentSchema);
