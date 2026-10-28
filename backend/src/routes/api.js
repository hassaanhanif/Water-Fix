const express = require('express');
const rateLimit = require('express-rate-limit');
const { authenticate, authorizeRoles } = require('../middleware/auth');
const authController = require('../controllers/authController');
const addressController = require('../controllers/addressController');
const supplierController = require('../controllers/supplierController');
const bookingController = require('../controllers/bookingController');
const trackingController = require('../controllers/trackingController');
const reviewController = require('../controllers/reviewController');
const walletController = require('../controllers/walletController');
const notificationController = require('../controllers/notificationController');
const adminController = require('../controllers/adminController');
const { searchIslamabadLocalities } = require('../utils/islamabadLocalities');

const router = express.Router();

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.NODE_ENV === 'test' ? 500 : 30,
  message: {
    success: false,
    message: 'Too many authentication attempts. Please try again after 15 minutes.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Health check
router.get('/health', (req, res) => {
  res.json({
    success: true,
    service: 'waterfix-backend',
    status: 'ok',
    timestamp: new Date().toISOString(),
  });
});

// Searchable Islamabad Locations (50+ verified sectors/localities including Hostel City)
router.get('/locations/islamabad', (req, res) => {
  const query = req.query.query || req.query.q || '';
  const results = searchIslamabadLocalities(query);
  res.json({
    success: true,
    count: results.length,
    locations: results,
  });
});

// Authentication
router.post('/auth/register', authLimiter, authController.register);
router.post('/auth/login', authLimiter, authController.login);
router.post('/auth/verify-email-otp', authLimiter, authController.verifyEmailOtp);
router.post('/auth/resend-email-otp', authLimiter, authController.resendEmailOtp);
router.get('/auth/status', authenticate, authController.getAccountStatus);
router.post('/auth/refresh', authController.refresh);
router.post('/auth/logout', authController.logout);
router.get('/auth/me', authenticate, authController.getMe);
router.put('/auth/me', authenticate, authController.updateMe);

// Customer Addresses
router.get('/addresses', authenticate, addressController.getAddresses);
router.post('/addresses', authenticate, addressController.createAddress);
router.put('/addresses/:id', authenticate, addressController.updateAddress);
router.delete('/addresses/:id', authenticate, addressController.deleteAddress);

// Supplier Onboarding, Dashboard & Listings (Role-protected for suppliers)
router.get(
  '/suppliers/me',
  authenticate,
  authorizeRoles('supplier'),
  supplierController.getMySupplierDashboard
);
router.put(
  '/suppliers/me',
  authenticate,
  authorizeRoles('supplier'),
  supplierController.updateSupplierProfile
);
router.post(
  '/suppliers/listings',
  authenticate,
  authorizeRoles('supplier'),
  supplierController.createListing
);
router.put(
  '/suppliers/listings/:id',
  authenticate,
  authorizeRoles('supplier'),
  supplierController.updateListing
);
router.delete(
  '/suppliers/listings/:id',
  authenticate,
  authorizeRoles('supplier'),
  supplierController.deleteListing
);

// Public / Customer Supplier Discovery & Profile
router.get('/suppliers/discover', supplierController.discoverSuppliers);
router.get('/suppliers/:supplierId', supplierController.getSupplierPublicProfile);

// Real Groq AI Recommendations (Islamabad Water Tanker Advisor)
router.get('/ai/recommendations', supplierController.getAiRecommendations);
router.post('/ai/recommendations', supplierController.getAiRecommendations);

// Bookings
router.post(
  '/bookings',
  authenticate,
  authorizeRoles('customer'),
  bookingController.createBooking
);
router.get('/bookings', authenticate, bookingController.getBookings);
router.get('/bookings/:id', authenticate, bookingController.getBookingById);
router.post('/bookings/:id/status', authenticate, bookingController.updateBookingStatus);
router.get('/bookings/:id/alternatives', authenticate, bookingController.getAlternativesForBooking);

// Real-Time Order GPS Tracking
router.get('/bookings/:id/tracking', authenticate, trackingController.getOrderTracking);
router.put('/bookings/:id/tracking', authenticate, trackingController.updateOrderTracking);
router.post('/bookings/:id/tracking', authenticate, trackingController.updateOrderTracking);
router.post('/bookings/:id/tracking/stop', authenticate, trackingController.stopOrderTracking);
router.get('/bookings/:id/tracking/stream', trackingController.streamOrderTracking);

// Reviews
router.post(
  '/reviews',
  authenticate,
  authorizeRoles('customer'),
  reviewController.createReview
);

// Commission Wallet, Safepay Test Mode Integration & Manual Settlements
router.get(
  '/wallet',
  authenticate,
  authorizeRoles('supplier', 'admin'),
  walletController.getSupplierWallet
);
router.post(
  '/wallet/safepay/session',
  authenticate,
  authorizeRoles('supplier'),
  walletController.createSafepayPaymentSession
);
router.post(
  '/wallet/safepay/verify',
  authenticate,
  authorizeRoles('supplier', 'admin'),
  walletController.verifySafepayPayment
);
router.post(
  '/wallet/safepay/cancel',
  authenticate,
  authorizeRoles('supplier', 'admin'),
  walletController.cancelSafepayPayment
);
router.get('/wallet/safepay/return', walletController.handleSafepayReturn);
router.get('/wallet/safepay/status', walletController.getSafepayPaymentStatus);
router.get('/wallet/safepay/callback', walletController.handleSafepayCallback);
router.get('/wallet/safepay/cancel', walletController.cancelSafepayPayment);
router.post('/wallet/safepay/webhook', walletController.handleSafepayWebhook);
router.get(
  '/wallet/admin/overview',
  authenticate,
  authorizeRoles('supplier', 'admin'),
  walletController.getAdminCommissionOverview
);
router.post(
  '/wallet/settle',
  authenticate,
  authorizeRoles('supplier', 'admin'),
  walletController.recordManualSettlement
);

// In-app Notifications
router.get('/notifications', authenticate, notificationController.getNotifications);
router.patch('/notifications/:id/read', authenticate, notificationController.markRead);
router.post('/notifications/read-all', authenticate, notificationController.markAllRead);

// Admin Dashboard, Supplier Commission Management, Account Locking & Audit Logs
// Strictly protected on the server by `authenticate` and `authorizeRoles('admin')`
router.get(
  '/admin/dashboard',
  authenticate,
  authorizeRoles('admin'),
  adminController.getDashboardSummary
);
router.get(
  '/admin/suppliers',
  authenticate,
  authorizeRoles('admin'),
  adminController.getSuppliers
);
router.get(
  '/admin/suppliers/:id',
  authenticate,
  authorizeRoles('admin'),
  adminController.getSupplierDetail
);
router.patch(
  '/admin/suppliers/:id/lock',
  authenticate,
  authorizeRoles('admin'),
  adminController.updateSupplierLockStatus
);
router.post(
  '/admin/suppliers/:id/lock',
  authenticate,
  authorizeRoles('admin'),
  adminController.updateSupplierLockStatus
);
router.get(
  '/admin/customers',
  authenticate,
  authorizeRoles('admin'),
  adminController.getCustomers
);
router.get(
  '/admin/customers/:id',
  authenticate,
  authorizeRoles('admin'),
  adminController.getCustomerDetail
);
router.patch(
  '/admin/customers/:id/lock',
  authenticate,
  authorizeRoles('admin'),
  adminController.updateCustomerLockStatus
);
router.post(
  '/admin/customers/:id/lock',
  authenticate,
  authorizeRoles('admin'),
  adminController.updateCustomerLockStatus
);
router.get(
  '/admin/payments',
  authenticate,
  authorizeRoles('admin'),
  adminController.getPayments
);
router.get(
  '/admin/payments/:id',
  authenticate,
  authorizeRoles('admin'),
  adminController.getPaymentDetail
);
router.get(
  '/admin/audit-logs',
  authenticate,
  authorizeRoles('admin'),
  adminController.getAuditLogs
);

// Admin Approval of Pending Registrations
router.get(
  '/admin/pending-suppliers',
  authenticate,
  authorizeRoles('admin'),
  adminController.getPendingSuppliers
);
router.post(
  '/admin/suppliers/:id/approve',
  authenticate,
  authorizeRoles('admin'),
  adminController.approveSupplier
);
router.post(
  '/admin/suppliers/:id/reject',
  authenticate,
  authorizeRoles('admin'),
  adminController.rejectSupplier
);
router.get(
  '/admin/pending-customers',
  authenticate,
  authorizeRoles('admin'),
  adminController.getPendingCustomers
);
router.post(
  '/admin/customers/:id/approve',
  authenticate,
  authorizeRoles('admin'),
  adminController.approveCustomer
);
router.post(
  '/admin/customers/:id/reject',
  authenticate,
  authorizeRoles('admin'),
  adminController.rejectCustomer
);

module.exports = router;
