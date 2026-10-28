const mongoose = require('mongoose');

const commissionLedgerSchema = new mongoose.Schema(
  {
    bookingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      unique: true,
      sparse: true,
      index: true,
    },
    bookingCode: {
      type: String,
      default: '',
    },
    orderDate: {
      type: Date,
      default: Date.now,
    },
    dueDate: {
      type: Date,
      default: Date.now,
      index: true,
    },
    currency: {
      type: String,
      default: 'PKR',
      enum: ['PKR'],
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
    type: {
      type: String,
      enum: ['commission_charge', 'safepay_payment', 'manual_settlement', 'commission_reversal'],
      required: true,
    },
    grossBookingAmount: {
      type: Number,
      required: true,
      default: 0,
    },
    commissionRate: {
      type: Number,
      required: true,
      default: 0.1,
    },
    commissionAmount: {
      type: Number,
      required: true,
    },
    paidAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    reversalAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    supplierNetAmount: {
      type: Number,
      required: true,
      default: 0,
    },
    status: {
      type: String,
      enum: ['accrued', 'outstanding', 'partially_paid', 'paid', 'settled', 'reversed'],
      default: 'accrued',
    },
    outstandingBalanceAfter: {
      type: Number,
      required: true,
    },
    settlementReference: {
      type: String,
      default: null,
    },
    providerTransactionId: {
      type: String,
      default: null,
    },
    referenceNote: {
      type: String,
      default: '',
    },
  },
  { timestamps: true }
);

commissionLedgerSchema.index({ supplierId: 1, type: 1, status: 1, dueDate: 1 });

module.exports = mongoose.model('CommissionLedger', commissionLedgerSchema);
