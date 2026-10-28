const { connectDB, disconnectDB } = require('../config/db');
const env = require('../config/env');
const User = require('../models/User');
const Session = require('../models/Session');
const DeliveryAddress = require('../models/DeliveryAddress');
const SupplierProfile = require('../models/SupplierProfile');
const SupplierListing = require('../models/SupplierListing');
const Booking = require('../models/Booking');
const BookingStatusHistory = require('../models/BookingStatusHistory');
const Review = require('../models/Review');
const Notification = require('../models/Notification');
const CommissionLedger = require('../models/CommissionLedger');
const SupplierSettlement = require('../models/SupplierSettlement');
const CommissionPayment = require('../models/CommissionPayment');
const OrderTracking = require('../models/OrderTracking');
const AdminAuditLog = require('../models/AdminAuditLog');

async function resetDatabase() {
  if (env.nodeEnv === 'production') {
    console.error('Refusing to reset database in production mode.');
    process.exit(1);
  }

  await connectDB();
  console.log(`[WaterFix] Clearing development database at ${env.mongoUri}...`);

  await Promise.all([
    User.deleteMany({}),
    Session.deleteMany({}),
    DeliveryAddress.deleteMany({}),
    SupplierProfile.deleteMany({}),
    SupplierListing.deleteMany({}),
    Booking.deleteMany({}),
    BookingStatusHistory.deleteMany({}),
    Review.deleteMany({}),
    Notification.deleteMany({}),
    CommissionLedger.deleteMany({}),
    SupplierSettlement.deleteMany({}),
    CommissionPayment.deleteMany({}),
    OrderTracking.deleteMany({}),
    AdminAuditLog.deleteMany({}),
  ]);

  console.log('[WaterFix] Database reset complete. Marketplace is now completely empty (0 suppliers).');
  await disconnectDB();
}

resetDatabase().catch((err) => {
  console.error('Reset failed:', err);
  process.exit(1);
});
