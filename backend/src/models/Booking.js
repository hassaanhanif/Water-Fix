const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema(
  {
    bookingCode: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    idempotencyKey: {
      type: String,
      index: true,
    },
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
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
    listingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'SupplierListing',
      required: false,
      default: null,
    },
    capacityLiters: {
      type: Number,
      required: true,
    },
    waterQuantityLiters: {
      type: Number,
      min: 500,
    },
    pricePer1000Liters: {
      type: Number,
      default: 1800,
    },
    waterPrice: {
      type: Number,
      required: true,
    },
    deliveryFee: {
      type: Number,
      required: true,
      default: 250,
    },
    totalPrice: {
      type: Number,
      required: true,
    },
    deliveryAddress: {
      addressLine: { type: String, required: true },
      city: { type: String, default: 'Islamabad' },
      lat: { type: Number, default: null },
      lng: { type: Number, default: null },
      hasAccurateCoordinates: { type: Boolean, default: true },
    },
    tracking: {
      latitude: { type: Number, default: null },
      longitude: { type: Number, default: null },
      heading: { type: Number, default: null },
      speed: { type: Number, default: null },
      accuracy: { type: Number, default: null },
      updatedAt: { type: Date, default: null },
      trackingActive: { type: Boolean, default: false },
    },
    customerName: {
      type: String,
      required: true,
    },
    customerPhone: {
      type: String,
      required: true,
    },
    supplierBusinessName: {
      type: String,
      required: true,
    },
    supplierPhone: {
      type: String,
      default: '',
    },
    driverName: {
      type: String,
      default: 'Assigned Driver',
    },
    estimatedArrivalMinutesMin: {
      type: Number,
      default: 35,
    },
    estimatedArrivalMinutesMax: {
      type: Number,
      default: 45,
    },
    distanceKm: {
      type: Number,
      default: 3.2,
    },
    paymentMethod: {
      type: String,
      enum: ['cod'],
      default: 'cod',
    },
    status: {
      type: String,
      enum: [
        'requested',
        'accepted',
        'dispatched',
        'arriving',
        'delivered',
        'rejected',
        'cancelled',
        'expired',
        'failed',
      ],
      default: 'requested',
      index: true,
    },
    cancelledBy: {
      type: String,
      enum: [null, 'customer', 'supplier', 'system'],
      default: null,
    },
    cancellationReason: {
      type: String,
      default: '',
    },
    deliveryCode: {
      type: String,
      required: true,
    },
    replacedFromBookingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      default: null,
    },
    replacedByBookingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      default: null,
    },
    isReviewed: {
      type: Boolean,
      default: false,
    },
    reviewRating: {
      type: Number,
      default: null,
    },
    commissionRecorded: {
      type: Boolean,
      default: false,
    },
    commissionAmount: {
      type: Number,
      default: 0,
    },
    inventoryRestored: {
      type: Boolean,
      default: false,
      index: true,
    },
    requestedAt: {
      type: Date,
      default: Date.now,
    },
    acceptedAt: Date,
    dispatchedAt: Date,
    arrivingAt: Date,
    deliveredAt: Date,
    cancelledAt: Date,
  },
  { timestamps: true }
);

bookingSchema.index({ customerId: 1, idempotencyKey: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model('Booking', bookingSchema);
