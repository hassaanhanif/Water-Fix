const mongoose = require('mongoose');

const supplierSettlementSchema = new mongoose.Schema(
  {
    settlementReference: {
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
    },
    amountSettled: {
      type: Number,
      required: true,
      min: 1,
    },
    previousOutstanding: {
      type: Number,
      required: true,
    },
    newOutstanding: {
      type: Number,
      required: true,
    },
    method: {
      type: String,
      default: 'Authorized Manual Settlement',
    },
    notes: {
      type: String,
      default: 'Manual cash/office settlement verified by administrator',
    },
    authorizedBy: {
      type: String,
      required: true,
      default: 'WaterFix Finance Admin',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SupplierSettlement', supplierSettlementSchema);
