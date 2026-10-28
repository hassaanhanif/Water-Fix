const mongoose = require('mongoose');

const supplierProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    ownerName: {
      type: String,
      required: true,
      trim: true,
    },
    businessName: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      required: true,
      trim: true,
    },
    phone: {
      type: String,
      required: true,
      trim: true,
    },
    city: {
      type: String,
      default: 'Islamabad',
      trim: true,
    },
    serviceAreaText: {
      type: String,
      default: 'Islamabad & Rawalpindi',
      trim: true,
    },
    lat: {
      type: Number,
      required: true,
      default: 33.6938,
    },
    lng: {
      type: Number,
      required: true,
      default: 73.0169,
    },
    serviceRadiusKm: {
      type: Number,
      required: true,
      default: 15,
      min: 1,
      max: 20,
    },
    tankersOwned: {
      type: Number,
      default: 1,
      min: 1,
      max: 100,
    },
    availableWaterLiters: {
      type: Number,
      default: 10000,
      min: 0,
      max: 500000,
      index: true,
    },
    pricePer1000Liters: {
      type: Number,
      default: 1800,
      min: 100,
      max: 25000,
    },
    companyLogo: {
      type: String,
      default: null,
    },
    isAvailable: {
      type: Boolean,
      default: true,
      index: true,
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
    deliveryInfo: {
      type: String,
      default: 'Standard domestic & commercial water tanker delivery.',
      trim: true,
    },
    driverName: {
      type: String,
      default: '',
      trim: true,
    },
    ratingAverage: {
      type: Number,
      default: 0,
    },
    reviewCount: {
      type: Number,
      default: 0,
    },
    completedDeliveriesCount: {
      type: Number,
      default: 0,
    },
    onTimeDeliveriesCount: {
      type: Number,
      default: 0,
    },
    cancelledDeliveriesCount: {
      type: Number,
      default: 0,
    },
    totalRequestsCount: {
      type: Number,
      default: 0,
    },
    avgArrivalMinutes: {
      type: Number,
      default: null,
    },
    totalGrossEarnings: {
      type: Number,
      default: 0,
    },
    totalCommissionCharged: {
      type: Number,
      default: 0,
    },
    outstandingCommission: {
      type: Number,
      default: 0,
      index: true,
    },
    totalSettledCommission: {
      type: Number,
      default: 0,
    },
    lastCommissionPaymentAt: {
      type: Date,
      default: null,
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
    // CNIC & Admin Approval Status
    cnicNumber: {
      type: String,
      default: '',
      trim: true,
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

module.exports = mongoose.model('SupplierProfile', supplierProfileSchema);
