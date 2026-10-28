const mongoose = require('mongoose');

const supplierListingSchema = new mongoose.Schema(
  {
    supplierId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'SupplierProfile',
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    capacityLiters: {
      type: Number,
      required: true,
      min: 500,
      index: true,
    },
    isCustomCapacity: {
      type: Boolean,
      default: false,
    },
    label: {
      type: String,
      default: 'Standard tanker',
      trim: true,
    },
    waterPrice: {
      type: Number,
      required: true,
      min: 100,
    },
    deliveryFee: {
      type: Number,
      required: true,
      default: 250,
      min: 0,
    },
    totalPrice: {
      type: Number,
      required: true,
      min: 100,
    },
    estimatedArrivalMinutesMin: {
      type: Number,
      required: true,
      default: 35,
      min: 5,
    },
    estimatedArrivalMinutesMax: {
      type: Number,
      required: true,
      default: 45,
      min: 10,
    },
    isAvailable: {
      type: Boolean,
      default: true,
      index: true,
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    serviceNotes: {
      type: String,
      default: '',
      trim: true,
    },
  },
  { timestamps: true }
);

supplierListingSchema.index({ supplierId: 1, capacityLiters: 1 });

module.exports = mongoose.model('SupplierListing', supplierListingSchema);
