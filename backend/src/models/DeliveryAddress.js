const mongoose = require('mongoose');

const deliveryAddressSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    label: {
      type: String,
      required: true,
      trim: true,
      default: 'Home',
    },
    addressLine: {
      type: String,
      required: true,
      trim: true,
    },
    area: {
      type: String,
      trim: true,
      default: '',
    },
    city: {
      type: String,
      trim: true,
      default: 'Islamabad',
    },
    lat: {
      type: Number,
      default: 33.6938,
    },
    lng: {
      type: Number,
      default: 73.0169,
    },
    hasAccurateCoordinates: {
      type: Boolean,
      default: true,
    },
    isDefault: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('DeliveryAddress', deliveryAddressSchema);
