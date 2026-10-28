process.env.NODE_ENV = 'test';
const crypto = require('crypto');
const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const { connectDB, disconnectDB } = require('../src/config/db');
const User = require('../src/models/User');
const Session = require('../src/models/Session');
const DeliveryAddress = require('../src/models/DeliveryAddress');
const SupplierProfile = require('../src/models/SupplierProfile');
const SupplierListing = require('../src/models/SupplierListing');
const Booking = require('../src/models/Booking');
const BookingStatusHistory = require('../src/models/BookingStatusHistory');
const Review = require('../src/models/Review');
const Notification = require('../src/models/Notification');
const CommissionLedger = require('../src/models/CommissionLedger');
const SupplierSettlement = require('../src/models/SupplierSettlement');
const CommissionPayment = require('../src/models/CommissionPayment');
const OrderTracking = require('../src/models/OrderTracking');
const AdminAuditLog = require('../src/models/AdminAuditLog');
const safepayService = require('../src/services/safepayService');
const env = require('../src/config/env');

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/waterfix_test_db';

beforeAll(async () => {
  await connectDB(TEST_DB_URI);
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
});

afterAll(async () => {
  if (mongoose.connection.readyState === 1) {
    await mongoose.connection.dropDatabase();
  }
  await disconnectDB();
});

describe('WaterFix Complete End-to-End Backend API Suite', () => {
  let customerToken;
  let customerUser;
  let supplierToken;
  let supplierId;
  let supplier2Token;
  let supplier2Id;
  let listing1000Id;
  let supplier2Listing1000Id;
  let completedBookingId;
  let completedBookingDeliveryCode;
  let cancelledBookingId;

  test('1. Fresh database contains zero suppliers and returns honest empty state', async () => {
    const res = await request(app).get('/api/suppliers/discover?capacityLiters=1000&lat=33.6938&lng=73.0169');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.suppliers).toHaveLength(0);
    expect(res.body.data.emptyMessage).toBe('No water suppliers available near you yet.');
  });

  test('2. Customer signs up with email & phone (+92 normalization), password hashed, and logs in via email and phone', async () => {
    const regRes = await request(app).post('/api/auth/register').send({
      name: 'Ayesha Khan',
      email: 'Ayesha@Example.com',
      phone: '0300 1234567',
      password: 'Password123',
      confirmPassword: 'Password123',
      role: 'customer',
      customerCategory: 'Household',
    });

    expect(regRes.statusCode).toBe(201);
    expect(regRes.body.success).toBe(true);
    expect(regRes.body.data.user.email).toBe('ayesha@example.com');
    expect(regRes.body.data.user.phone).toBe('+923001234567');
    expect(regRes.body.data.user.role).toBe('customer');
    expect(regRes.body.data.user.passwordHash).toBeUndefined();

    // Verify password is hashed in MongoDB
    const dbUser = await User.findById(regRes.body.data.user._id).select('+passwordHash');
    expect(dbUser.passwordHash).toBeDefined();
    expect(dbUser.passwordHash).not.toBe('Password123');
    expect(dbUser.passwordHash.startsWith('$2')).toBe(true);

    // Login with Email
    const emailLogin = await request(app).post('/api/auth/login').send({
      identifier: 'ayesha@example.com',
      password: 'Password123',
    });
    expect(emailLogin.statusCode).toBe(200);
    expect(emailLogin.body.data.accessToken).toBeDefined();

    // Login with Phone
    const phoneLogin = await request(app).post('/api/auth/login').send({
      identifier: '0300-1234567',
      password: 'Password123',
      role: 'customer',
    });
    expect(phoneLogin.statusCode).toBe(200);
    expect(phoneLogin.body.data.user.phone).toBe('+923001234567');

    // Login with mismatched role (trying to sign in as Water Supplier with a Customer account) fails with 403
    const mismatchRoleLogin = await request(app).post('/api/auth/login').send({
      identifier: '0300-1234567',
      password: 'Password123',
      role: 'supplier',
    });
    expect(mismatchRoleLogin.statusCode).toBe(403);
    expect(mismatchRoleLogin.body.message).toContain('registered as a Customer');

    customerToken = phoneLogin.body.data.accessToken;
    customerUser = phoneLogin.body.data.user;
  });

  test('3. Duplicate email or phone registration is rejected & invalid password fails login', async () => {
    const dupEmail = await request(app).post('/api/auth/register').send({
      name: 'Another User',
      email: 'ayesha@example.com',
      phone: '03009999999',
      password: 'Password123',
      confirmPassword: 'Password123',
      role: 'customer',
    });
    expect(dupEmail.statusCode).toBe(409);

    const dupPhone = await request(app).post('/api/auth/register').send({
      name: 'Another User',
      email: 'unique@example.com',
      phone: '+923001234567',
      password: 'Password123',
      confirmPassword: 'Password123',
      role: 'customer',
    });
    expect(dupPhone.statusCode).toBe(409);

    const badPass = await request(app).post('/api/auth/login').send({
      identifier: 'ayesha@example.com',
      password: 'WrongPassword999',
    });
    expect(badPass.statusCode).toBe(401);
  });

  test('4. Customer attempting a supplier-only operation is rejected with 403 Forbidden', async () => {
    const res = await request(app)
      .post('/api/suppliers/listings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        capacityLiters: 1000,
        waterPrice: 1200,
        deliveryFee: 200,
      });
    expect(res.statusCode).toBe(403);
  });

  test('5. Supplier signs up, logs in, and publishes a 1,000 L listing with a real price', async () => {
    const supReg = await request(app).post('/api/auth/register').send({
      name: 'Imran Khan',
      businessName: 'Al-Noor Water Supply',
      email: 'alnoor@waterfix.pk',
      phone: '0301 5556677',
      password: 'SupplierPass1',
      confirmPassword: 'SupplierPass1',
      role: 'supplier',
      city: 'Islamabad',
      serviceAreaText: 'F-10, F-11, G-10, G-11 Islamabad',
      lat: 33.6844,
      lng: 73.0479,
      serviceRadiusKm: 25,
    });

    expect(supReg.statusCode).toBe(201);
    expect(supReg.body.data.user.role).toBe('supplier');
    expect(supReg.body.data.supplierProfile.isVerified).toBe(false);

    supplierToken = supReg.body.data.accessToken;
    supplierId = supReg.body.data.supplierProfile._id;

    // Publish 1,000 L listing
    const listRes = await request(app)
      .post('/api/suppliers/listings')
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({
        capacityLiters: 1000,
        waterPrice: 1550,
        deliveryFee: 250,
        estimatedArrivalMinutesMin: 30,
        estimatedArrivalMinutesMax: 40,
      });

    expect(listRes.statusCode).toBe(201);
    expect(listRes.body.data.totalPrice).toBe(1800);
    listing1000Id = listRes.body.data._id;

    // Also register a second supplier for comparison & alternative supplier tests
    const sup2Reg = await request(app).post('/api/auth/register').send({
      name: 'Rana Tariq',
      businessName: 'Rana Tankers',
      email: 'rana@waterfix.pk',
      phone: '0302 7778899',
      password: 'SupplierPass2',
      confirmPassword: 'SupplierPass2',
      role: 'supplier',
      city: 'Islamabad',
      lat: 33.7000,
      lng: 73.0300,
      serviceRadiusKm: 25,
    });
    supplier2Token = sup2Reg.body.data.accessToken;
    supplier2Id = sup2Reg.body.data.supplierProfile._id;

    const list2Res = await request(app)
      .post('/api/suppliers/listings')
      .set('Authorization', `Bearer ${supplier2Token}`)
      .send({
        capacityLiters: 1000,
        waterPrice: 1400,
        deliveryFee: 250,
        estimatedArrivalMinutesMin: 45,
        estimatedArrivalMinutesMax: 55,
      });
    expect(list2Res.statusCode).toBe(201);
    supplier2Listing1000Id = list2Res.body.data._id;
  });

  test('6. Customer discovers the listing with explainable AI Pick ranking and sorting modes', async () => {
    const discRes = await request(app).get(
      '/api/suppliers/discover?capacityLiters=1000&lat=33.6938&lng=73.0169&sortBy=best_match'
    );
    expect(discRes.statusCode).toBe(200);
    expect(discRes.body.data.suppliers.length).toBe(2);
    expect(discRes.body.data.suppliers[0].isAiPick).toBe(true);
    expect(discRes.body.data.suppliers[0].recommendationExplanation).toContain('Recommended because');
    expect(discRes.body.data.suppliers[0].reliabilityText).toBe('Not enough delivery history');

    // Cheapest sort
    const cheapRes = await request(app).get(
      '/api/suppliers/discover?capacityLiters=1000&lat=33.6938&lng=73.0169&sortBy=cheapest'
    );
    expect(cheapRes.body.data.suppliers[0].totalPrice).toBe(1650);
  });

  test('7. Customer books the supplier and duplicate booking submissions with same idempotencyKey are handled safely', async () => {
    const idemKey = 'idem-booking-test-001';
    const bookRes1 = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        listingId: listing1000Id,
        supplierId,
        capacityLiters: 1000,
        expectedTotalPrice: 1800,
        idempotencyKey: idemKey,
        deliveryAddress: {
          addressLine: 'Street 7, F-10/3, Islamabad',
          city: 'Islamabad',
          lat: 33.6938,
          lng: 73.0169,
        },
      });

    expect(bookRes1.statusCode).toBe(201);
    expect(bookRes1.body.data.status).toBe('requested');
    expect(bookRes1.body.data.deliveryCode).toHaveLength(4);
    completedBookingId = bookRes1.body.data._id;
    completedBookingDeliveryCode = bookRes1.body.data.deliveryCode;

    // Duplicate submission with same idempotencyKey
    const bookRes2 = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        listingId: listing1000Id,
        supplierId,
        capacityLiters: 1000,
        expectedTotalPrice: 1800,
        idempotencyKey: idemKey,
        deliveryAddress: {
          addressLine: 'Street 7, F-10/3, Islamabad',
          city: 'Islamabad',
          lat: 33.6938,
          lng: 73.0169,
        },
      });

    expect(bookRes2.statusCode).toBe(200);
    expect(bookRes2.body.idempotentReplay).toBe(true);
    expect(bookRes2.body.data._id).toBe(completedBookingId);
  });

  test('8. Supplier accepts, dispatches, and completes the booking; commission is calculated exactly once', async () => {
    // Accept
    const acceptRes = await request(app)
      .post(`/api/bookings/${completedBookingId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'accepted' });
    expect(acceptRes.statusCode).toBe(200);
    expect(acceptRes.body.data.status).toBe('accepted');

    // Dispatch
    const dispRes = await request(app)
      .post(`/api/bookings/${completedBookingId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'dispatched' });
    expect(dispRes.statusCode).toBe(200);
    expect(dispRes.body.data.status).toBe('dispatched');

    // Invalid delivery verification code is rejected
    const badCodeRes = await request(app)
      .post(`/api/bookings/${completedBookingId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'delivered', deliveryCode: '0000' });
    if (completedBookingDeliveryCode !== '0000') {
      expect(badCodeRes.statusCode).toBe(400);
    }

    // Complete delivery with valid deliveryCode
    const delivRes = await request(app)
      .post(`/api/bookings/${completedBookingId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'delivered', deliveryCode: completedBookingDeliveryCode });
    expect(delivRes.statusCode).toBe(200);
    expect(delivRes.body.data.status).toBe('delivered');
    expect(delivRes.body.data.commissionRecorded).toBe(true);
    expect(delivRes.body.data.commissionAmount).toBe(180); // 10% of Rs 1,800

    // Duplicate completion request does NOT double-charge commission
    const dupDelivRes = await request(app)
      .post(`/api/bookings/${completedBookingId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'delivered', deliveryCode: completedBookingDeliveryCode });
    expect(dupDelivRes.statusCode).toBe(200);
    expect(dupDelivRes.body.idempotentReplay).toBe(true);

    // Check wallet ledger has exactly 1 commission entry of Rs 180
    const walletRes = await request(app)
      .get('/api/wallet')
      .set('Authorization', `Bearer ${supplierToken}`);
    expect(walletRes.statusCode).toBe(200);
    expect(walletRes.body.data.summary.totalGrossEarnings).toBe(1800);
    expect(walletRes.body.data.summary.totalCommissionCharged).toBe(180);
    expect(walletRes.body.data.summary.outstandingCommission).toBe(180);
    expect(walletRes.body.data.ledger).toHaveLength(1);
  });

  test('9. Customer submits a review for completed booking and duplicate review is prevented', async () => {
    const revRes = await request(app)
      .post('/api/reviews')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        bookingId: completedBookingId,
        rating: 5,
        tags: ['On time', 'Full quantity', 'Clean water'],
        comment: 'Arrived early and the tank was full. Driver was polite.',
      });

    expect(revRes.statusCode).toBe(201);
    expect(revRes.body.data.rating).toBe(5);

    // Duplicate review attempt fails with 409
    const dupRev = await request(app)
      .post('/api/reviews')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        bookingId: completedBookingId,
        rating: 4,
      });
    expect(dupRev.statusCode).toBe(409);

    // Verify supplier rating updated
    const profRes = await request(app).get(`/api/suppliers/${supplierId}`);
    expect(profRes.body.data.supplier.ratingAverage).toBe(5);
    expect(profRes.body.data.supplier.reviewCount).toBe(1);
  });

  test('10. Supplier cancels a booking and real alternative suppliers are offered', async () => {
    // Create a new booking with Supplier 1
    const bookRes = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        listingId: listing1000Id,
        supplierId,
        capacityLiters: 1000,
        expectedTotalPrice: 1800,
        deliveryAddress: {
          addressLine: 'Street 7, F-10/3, Islamabad',
          city: 'Islamabad',
          lat: 33.6938,
          lng: 73.0169,
        },
      });
    expect(bookRes.statusCode).toBe(201);
    cancelledBookingId = bookRes.body.data._id;

    // Supplier 1 cancels the booking
    const cancelRes = await request(app)
      .post(`/api/bookings/${cancelledBookingId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({
        status: 'cancelled',
        reason: 'Their tanker became unavailable.',
      });
    expect(cancelRes.statusCode).toBe(200);
    expect(cancelRes.body.data.status).toBe('cancelled');
    expect(cancelRes.body.data.cancelledBy).toBe('supplier');

    // Fetch alternatives for the cancelled booking
    const altRes = await request(app)
      .get(`/api/bookings/${cancelledBookingId}/alternatives`)
      .set('Authorization', `Bearer ${customerToken}`);
    expect(altRes.statusCode).toBe(200);
    expect(altRes.body.data.alternatives.length).toBeGreaterThanOrEqual(1);
    expect(altRes.body.data.alternatives[0].supplierId).toBe(supplier2Id);
    expect(altRes.body.data.alternatives[0].businessName).toBe('Rana Tankers');
    expect(altRes.body.data.alternatives[0].totalPrice).toBe(1650);
  });

  test('11. Settlement authorization: supplier cannot self-settle without admin key; authorized settlement succeeds', async () => {
    // Unauthorized attempt without adminAuthorizationKey
    const unauthSettle = await request(app)
      .post('/api/wallet/settle')
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({
        amount: 100,
      });
    expect(unauthSettle.statusCode).toBe(403);

    // Authorized manual settlement with valid adminSettlementKey
    const authSettle = await request(app)
      .post('/api/wallet/settle')
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({
        amount: 100,
        adminAuthorizationKey: env.adminSettlementKey,
        notes: 'Cash settlement verified at Islamabad office',
      });
    expect(authSettle.statusCode).toBe(201);
    expect(authSettle.body.data.outstandingCommission).toBe(80);
  });

  test('12. Real-time GPS tracking lifecycle: pre-acceptance, ownership security, live updates, and completion stop', async () => {
    // 1. Customer creates a new order
    const bookRes = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        listingId: listing1000Id,
        supplierId,
        capacityLiters: 1000,
        expectedTotalPrice: 1800,
        deliveryAddress: {
          addressLine: 'House 12, Street 4, F-10/2, Islamabad',
          city: 'Islamabad',
          lat: 33.6915,
          lng: 73.0142,
        },
      });
    expect(bookRes.statusCode).toBe(201);
    const trackingOrderId = bookRes.body.data._id;

    // 2. Before acceptance: no supplier coordinates or active tracking
    const preTrackRes = await request(app)
      .get(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${customerToken}`);
    expect(preTrackRes.statusCode).toBe(200);
    expect(preTrackRes.body.data.orderId).toBe(trackingOrderId);
    expect(preTrackRes.body.data.orderStatus).toBe('requested');
    expect(preTrackRes.body.data.trackingActive).toBe(false);
    expect(preTrackRes.body.data.latitude).toBeNull();
    expect(preTrackRes.body.data.longitude).toBeNull();
    expect(preTrackRes.body.data.deliveryAddress.lat).toBe(33.6915);
    expect(preTrackRes.body.data.deliveryAddress.lng).toBe(73.0142);

    // Supplier cannot publish GPS coordinates before accepting the order
    const prematureGps = await request(app)
      .put(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ latitude: 33.6844, longitude: 73.0479 });
    expect(prematureGps.statusCode).toBe(400);

    // 3. Unauthorized access checks
    // Unauthenticated read fails with 401
    const unauthRead = await request(app).get(`/api/bookings/${trackingOrderId}/tracking`);
    expect(unauthRead.statusCode).toBe(401);

    // Different supplier (supplier2) cannot read or write tracking for supplier1's order
    const wrongSupRead = await request(app)
      .get(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${supplier2Token}`);
    expect(wrongSupRead.statusCode).toBe(403);

    const wrongSupWrite = await request(app)
      .put(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${supplier2Token}`)
      .send({ latitude: 33.685, longitude: 73.048 });
    expect(wrongSupWrite.statusCode).toBe(403);

    // Customer cannot write supplier GPS coordinates
    const customerWrite = await request(app)
      .put(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ latitude: 33.685, longitude: 73.048 });
    expect(customerWrite.statusCode).toBe(403);

    // 4. Supplier accepts order -> tracking becomes active
    const acceptRes = await request(app)
      .post(`/api/bookings/${trackingOrderId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'accepted' });
    expect(acceptRes.statusCode).toBe(200);

    // Invalid coordinates rejected
    const badCoords = await request(app)
      .put(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ latitude: 125.0, longitude: 73.0479 });
    expect(badCoords.statusCode).toBe(400);

    // 5. Supplier publishes initial real GPS location
    const gps1 = await request(app)
      .put(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({
        latitude: 33.6844,
        longitude: 73.0479,
        heading: 285.0,
        speed: 9.2,
        accuracy: 4.5,
      });
    expect(gps1.statusCode).toBe(200);
    expect(gps1.body.data.trackingActive).toBe(true);
    expect(gps1.body.data.latitude).toBe(33.6844);
    expect(gps1.body.data.longitude).toBe(73.0479);
    expect(gps1.body.data.updatedAt).toBeTruthy();

    // 6. Supplier dispatches order and moves closer to customer
    await request(app)
      .post(`/api/bookings/${trackingOrderId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'dispatched' });

    const gps2 = await request(app)
      .put(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({
        latitude: 33.6895,
        longitude: 73.0215,
        heading: 290.0,
        speed: 11.4,
        accuracy: 3.8,
      });
    expect(gps2.statusCode).toBe(200);

    // Both customer and supplier read the exact same shared tracking record
    const custTrack = await request(app)
      .get(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${customerToken}`);
    const supTrack = await request(app)
      .get(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${supplierToken}`);

    expect(custTrack.statusCode).toBe(200);
    expect(supTrack.statusCode).toBe(200);
    expect(custTrack.body.data.orderId).toBe(supTrack.body.data.orderId);
    expect(custTrack.body.data.latitude).toBe(33.6895);
    expect(custTrack.body.data.longitude).toBe(73.0215);
    expect(supTrack.body.data.latitude).toBe(33.6895);
    expect(supTrack.body.data.longitude).toBe(73.0215);
    expect(custTrack.body.data.orderStatus).toBe('dispatched');
    expect(custTrack.body.data.trackingActive).toBe(true);

    // 7. Supplier completes delivery -> trackingActive automatically stops
    const completeRes = await request(app)
      .post(`/api/bookings/${trackingOrderId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'delivered' });
    expect(completeRes.statusCode).toBe(200);

    const postCompleteTrack = await request(app)
      .get(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${customerToken}`);
    expect(postCompleteTrack.statusCode).toBe(200);
    expect(postCompleteTrack.body.data.orderStatus).toBe('delivered');
    expect(postCompleteTrack.body.data.trackingActive).toBe(false);

    // Supplier cannot continue broadcasting GPS after order is completed
    const postCompleteGps = await request(app)
      .put(`/api/bookings/${trackingOrderId}/tracking`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ latitude: 33.6915, longitude: 73.0142 });
    expect(postCompleteGps.statusCode).toBe(400);
  });

  test('13. Commission calculation integrity: duplicate completion & cancelled/rejected orders do not charge commission', async () => {
    // At this point:
    // - Order #1 (Rs 1800 -> comm Rs 180, settled Rs 100 in Test 11 -> Rs 80 remaining)
    // - Order #2 (cancelledBookingId) was cancelled -> 0 commission
    // - Order #3 (trackingOrderId in Test 12, Rs 1800 -> comm Rs 180)
    // Total owed right now = 80 + 180 = 260, settled = 100.
    const cancelledLedger = await CommissionLedger.findOne({
      bookingId: cancelledBookingId,
    });
    expect(cancelledLedger).toBeNull();

    // Create a rejected order and verify it generates 0 commission
    const rejectedOrderRes = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        listingId: listing1000Id,
        supplierId,
        capacityLiters: 1000,
        expectedTotalPrice: 1800,
        deliveryAddress: {
          addressLine: 'House 99, Street 2, F-10/3, Islamabad',
          city: 'Islamabad',
          lat: 33.6915,
          lng: 73.0142,
        },
      });
    expect(rejectedOrderRes.statusCode).toBe(201);
    const rejectedOrderId = rejectedOrderRes.body.data._id;

    const rejectRes = await request(app)
      .post(`/api/bookings/${rejectedOrderId}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'rejected', reason: 'No tanker available right now' });
    expect(rejectRes.statusCode).toBe(200);

    const rejectedLedger = await CommissionLedger.findOne({
      bookingId: rejectedOrderId,
    });
    expect(rejectedLedger).toBeNull();

    // Create another completed order (Order #4, Rs 1800 -> comm Rs 180) so supplier owes 260 + 180 = Rs 440
    const order4Res = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        listingId: listing1000Id,
        supplierId,
        capacityLiters: 1000,
        expectedTotalPrice: 1800,
        deliveryAddress: {
          addressLine: 'House 44, Street 9, F-10/2, Islamabad',
          city: 'Islamabad',
          lat: 33.692,
          lng: 73.015,
        },
      });
    expect(order4Res.statusCode).toBe(201);
    const order4Id = order4Res.body.data._id;
    await request(app)
      .post(`/api/bookings/${order4Id}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'accepted' });
    await request(app)
      .post(`/api/bookings/${order4Id}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'dispatched' });
    await request(app)
      .post(`/api/bookings/${order4Id}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'arriving' });
    const complete4Res = await request(app)
      .post(`/api/bookings/${order4Id}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'delivered' });
    expect(complete4Res.statusCode).toBe(200);

    // Attempt repeated delivery completion call on already-delivered order -> idempotent 200 and MUST NOT duplicate commission
    const duplicateCompleteRes = await request(app)
      .post(`/api/bookings/${order4Id}/status`)
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ status: 'delivered' });
    expect(duplicateCompleteRes.statusCode).toBe(200);

    const chargesForOrder4 = await CommissionLedger.find({
      bookingId: order4Id,
      type: 'commission_charge',
    });
    expect(chargesForOrder4.length).toBe(1);

    // Verify wallet summary reflects Rs 440 owed (80 + 180 + 180) and Rs 100 already paid
    const walletRes = await request(app)
      .get('/api/wallet')
      .set('Authorization', `Bearer ${supplierToken}`);
    expect(walletRes.statusCode).toBe(200);
    expect(walletRes.body.data.summary.totalCommissionOwed).toBe(440);
    expect(walletRes.body.data.summary.amountCurrentlyPayable).toBe(440);
    expect(walletRes.body.data.summary.totalCommissionPaid).toBe(100);
    expect(walletRes.body.data.summary.paymentStatus).toBe('Partially Paid');
    expect(walletRes.body.data.commissionHistory.length).toBe(3);
  });

  test('14. Safepay Test Mode: missing credentials, validation, session creation, cancellation, verification, webhook idempotency & refund', async () => {
    const origApiKey = process.env.SAFEPAY_API_KEY;
    const origSecretKey = process.env.SAFEPAY_SECRET_KEY;
    const origWebhookSecret = process.env.SAFEPAY_WEBHOOK_SECRET;

    try {
      // A. When Safepay keys are still placeholder values, session creation returns 503 SAFEPAY_CREDENTIALS_MISSING
      process.env.SAFEPAY_API_KEY = 'sec_sandbox_replace_with_your_safepay_api_key';
      process.env.SAFEPAY_SECRET_KEY = 'replace_with_your_safepay_secret_key';

      const missingCredsRes = await request(app)
        .post('/api/wallet/safepay/session')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({ amount: 200 });
      expect(missingCredsRes.statusCode).toBe(503);
      expect(missingCredsRes.body.code).toBe('SAFEPAY_CREDENTIALS_MISSING');

      // B. Configure test secrets for mocked Safepay Sandbox testing
      const testApiKey = 'sec_sandbox_test_key_waterfix_123';
      const testSecretKey = 'sfpy_sandbox_secret_key_waterfix_456';
      const testWebhookSecret = 'sfpy_sandbox_webhook_secret_waterfix_789';
      process.env.SAFEPAY_API_KEY = testApiKey;
      process.env.SAFEPAY_SECRET_KEY = testSecretKey;
      process.env.SAFEPAY_WEBHOOK_SECRET = testWebhookSecret;

      let trackerCounter = 100;
      safepayService.setHttpClient(async (url, options) => {
        if (url.endsWith('/order/v1/init')) {
          const parsed = JSON.parse(options.body);
          expect(parsed.client).toBe(testApiKey);
          expect(parsed.currency).toBe('PKR');
          expect(parsed.environment).toBe('sandbox');
          trackerCounter += 1;
          return {
            ok: true,
            status: 200,
            data: {
              data: { token: `track_sandbox_wf_${trackerCounter}` },
              status: { message: 'success', errors: [] },
            },
          };
        }
        return { ok: false, status: 404, data: null };
      });

      // C. Customer or another supplier cannot initiate payment for Supplier 1
      const custSessionAttempt = await request(app)
        .post('/api/wallet/safepay/session')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({ amount: 200 });
      expect(custSessionAttempt.statusCode).toBe(403);

      const crossSupplierAttempt = await request(app)
        .post('/api/wallet/safepay/session')
        .set('Authorization', `Bearer ${supplier2Token}`)
        .send({ supplierId, amount: 200 });
      expect(crossSupplierAttempt.statusCode).toBe(403);

      // D. Supplier 2 has 0 outstanding commission -> session creation rejected with 400
      const zeroDueAttempt = await request(app)
        .post('/api/wallet/safepay/session')
        .set('Authorization', `Bearer ${supplier2Token}`)
        .send({});
      expect(zeroDueAttempt.statusCode).toBe(400);

      // E. Invalid amounts (<= 0 or > outstanding Rs 440) rejected with 400
      const negativeAmt = await request(app)
        .post('/api/wallet/safepay/session')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({ amount: -100 });
      expect(negativeAmt.statusCode).toBe(400);

      const excessiveAmt = await request(app)
        .post('/api/wallet/safepay/session')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({ amount: 1500 });
      expect(excessiveAmt.statusCode).toBe(400);

      // F. Create Session #1 (Rs 200) and CANCEL it -> does NOT reduce commission debt (remains Rs 440)
      const session1Res = await request(app)
        .post('/api/wallet/safepay/session')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({ amount: 200 });
      expect(session1Res.statusCode).toBe(201);
      expect(session1Res.body.data.checkoutUrl).toContain(
        'https://sandbox.api.getsafepay.com/checkout/pay'
      );
      expect(session1Res.body.data.checkoutUrl).toContain('env=sandbox');
      const ref1 = session1Res.body.data.paymentReference;

      const cancel1Res = await request(app)
        .post('/api/wallet/safepay/cancel')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({ paymentReference: ref1, reason: 'User closed checkout window' });
      expect(cancel1Res.statusCode).toBe(200);
      expect(cancel1Res.body.data.status).toBe('Cancelled');
      expect(cancel1Res.body.data.outstandingCommission).toBe(440);

      // G. Create Session #2 (Partial payment Rs 260 out of Rs 440 owed)
      const session2Res = await request(app)
        .post('/api/wallet/safepay/session')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({ amount: 260 });
      expect(session2Res.statusCode).toBe(201);
      const ref2 = session2Res.body.data.paymentReference;
      const tracker2 = session2Res.body.data.tracker;

      // Wallet shows Pending payment amount = Rs 260 while session is pending, and debt is still Rs 440
      const pendingWallet = await request(app)
        .get('/api/wallet')
        .set('Authorization', `Bearer ${supplierToken}`);
      expect(pendingWallet.body.data.summary.totalCommissionOwed).toBe(440);
      expect(pendingWallet.body.data.summary.pendingPaymentAmount).toBe(260);
      expect(pendingWallet.body.data.summary.paymentStatus).toBe('Pending');

      // Forged/invalid callback signature is rejected and does NOT deduct debt
      const badSigRes = await request(app)
        .post('/api/wallet/safepay/verify')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({
          paymentReference: ref2,
          tracker: tracker2,
          sig: '0000000000000000000000000000000000000000000000000000000000000000',
        });
      expect(badSigRes.statusCode).toBe(400);
      expect(badSigRes.body.code).toBe('INVALID_SAFEPAY_SIGNATURE');

      // Valid HMAC-SHA256 signature verifies Session #2 and allocates Rs 260 FIFO (Rs 80 to Order #1 -> Paid, Rs 180 to Order #3 -> Paid)
      const validSig2 = safepayService.signTracker(tracker2, testSecretKey);
      const verify2Res = await request(app)
        .post('/api/wallet/safepay/verify')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({
          paymentReference: ref2,
          tracker: tracker2,
          sig: validSig2,
        });
      expect(verify2Res.statusCode).toBe(200);
      expect(verify2Res.body.data.status).toBe('Paid');
      expect(verify2Res.body.data.outstandingCommission).toBe(180);
      expect(verify2Res.body.data.totalSettledCommission).toBe(360);

      // Duplicate verification call is idempotent and does NOT deduct Rs 260 a second time
      const dupVerify2Res = await request(app)
        .post('/api/wallet/safepay/verify')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({
          paymentReference: ref2,
          tracker: tracker2,
          sig: validSig2,
        });
      expect(dupVerify2Res.statusCode).toBe(200);
      expect(dupVerify2Res.body.alreadyProcessed).toBe(true);
      expect(dupVerify2Res.body.data.outstandingCommission).toBe(180);

      // H. Create Session #3 for remaining Rs 180 and verify via Safepay Webhook (`POST /api/wallet/safepay/webhook`)
      const session3Res = await request(app)
        .post('/api/wallet/safepay/session')
        .set('Authorization', `Bearer ${supplierToken}`)
        .send({ amount: 180 });
      expect(session3Res.statusCode).toBe(201);
      const ref3 = session3Res.body.data.paymentReference;
      const tracker3 = session3Res.body.data.tracker;

      const webhookPayload = {
        id: 'evt_sfpy_test_180_paid',
        type: 'payment.succeeded',
        data: {
          tracker: tracker3,
          order_id: ref3,
          amount: 180,
          currency: 'PKR',
          state: 'TRACKER_ENDED',
          reference: 'SFPY-TXN-998877',
        },
      };

      // Invalid webhook signature is rejected with 401
      const badWebhookRes = await request(app)
        .post('/api/wallet/safepay/webhook')
        .set('X-SFPY-SIGNATURE', 'invalid_hmac_signature')
        .set('X-SFPY-EVENT-ID', 'evt_sfpy_test_180_paid')
        .send(webhookPayload);
      expect(badWebhookRes.statusCode).toBe(401);

      // Valid webhook signature marks Session #3 as Paid and reduces outstanding commission to 0
      const validWebhookSig = crypto
        .createHmac('sha256', testWebhookSecret)
        .update(JSON.stringify(webhookPayload.data), 'utf8')
        .digest('hex');

      const goodWebhookRes = await request(app)
        .post('/api/wallet/safepay/webhook')
        .set('X-SFPY-SIGNATURE', validWebhookSig)
        .set('X-SFPY-EVENT-ID', 'evt_sfpy_test_180_paid')
        .send(webhookPayload);
      expect(goodWebhookRes.statusCode).toBe(200);
      expect(goodWebhookRes.body.data.outstandingCommission).toBe(0);

      // Duplicate webhook event is idempotent and does NOT deduct again
      const dupWebhookRes = await request(app)
        .post('/api/wallet/safepay/webhook')
        .set('X-SFPY-SIGNATURE', validWebhookSig)
        .set('X-SFPY-EVENT-ID', 'evt_sfpy_test_180_paid')
        .send(webhookPayload);
      expect(dupWebhookRes.statusCode).toBe(200);
      expect(dupWebhookRes.body.alreadyProcessed).toBe(true);

      // Verify wallet is now 100% Paid (Rs 0 owed)
      const paidWalletRes = await request(app)
        .get('/api/wallet')
        .set('Authorization', `Bearer ${supplierToken}`);
      expect(paidWalletRes.body.data.summary.totalCommissionOwed).toBe(0);
      expect(paidWalletRes.body.data.summary.paymentStatus).toBe('Paid');

      // I. Refund webhook reverses Session #3 (Rs 180) and restores Rs 180 outstanding debt
      const refundPayload = {
        id: 'evt_sfpy_test_180_refunded',
        type: 'payment.refunded',
        data: {
          tracker: tracker3,
          order_id: ref3,
          amount: 180,
          currency: 'PKR',
          state: 'REFUNDED',
        },
      };
      const refundSig = crypto
        .createHmac('sha256', testWebhookSecret)
        .update(JSON.stringify(refundPayload.data), 'utf8')
        .digest('hex');

      const refundWebhookRes = await request(app)
        .post('/api/wallet/safepay/webhook')
        .set('X-SFPY-SIGNATURE', refundSig)
        .set('X-SFPY-EVENT-ID', 'evt_sfpy_test_180_refunded')
        .send(refundPayload);
      expect(refundWebhookRes.statusCode).toBe(200);
      expect(refundWebhookRes.body.data.status).toBe('Refunded');
      expect(refundWebhookRes.body.data.outstandingCommission).toBe(180);

      // J. Admin Commission Overview endpoint works with valid admin key and rejects invalid key
      const unauthAdminRes = await request(app)
        .get('/api/wallet/admin/overview?adminKey=wrong_key')
        .set('Authorization', `Bearer ${supplierToken}`);
      expect(unauthAdminRes.statusCode).toBe(403);

      const validAdminRes = await request(app)
        .get(`/api/wallet/admin/overview?adminKey=${env.adminSettlementKey}`)
        .set('Authorization', `Bearer ${supplierToken}`);
      expect(validAdminRes.statusCode).toBe(200);
      expect(validAdminRes.body.data.totals.totalOutstandingCommissions).toBe(180);
      expect(validAdminRes.body.data.totals.totalVerifiedPayments).toBe(360);
    } finally {
      safepayService.resetHttpClient();
      process.env.SAFEPAY_API_KEY = origApiKey;
      process.env.SAFEPAY_SECRET_KEY = origSecretKey;
      process.env.SAFEPAY_WEBHOOK_SECRET = origWebhookSecret;
    }
  });

  test('15. Live Safepay Sandbox API test: creates a real sandbox tracker token & checkout URL using configured .env keys', async () => {
    expect(env.isSafepayConfigured()).toBe(true);

    // Supplier currently owes Rs 180 from Test 14. Create a REAL Safepay Sandbox session (no HTTP mock)
    const liveSessionRes = await request(app)
      .post('/api/wallet/safepay/session')
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ amount: 180 });

    expect(liveSessionRes.statusCode).toBe(201);
    expect(liveSessionRes.body.data.tracker).toMatch(/^track_/);
    expect(liveSessionRes.body.data.checkoutUrl).toContain(
      'https://sandbox.api.getsafepay.com/checkout/pay'
    );
    expect(liveSessionRes.body.data.checkoutUrl).toContain(
      liveSessionRes.body.data.tracker
    );
    expect(liveSessionRes.body.data.status).toBe('Pending');

    // Verify callback signature using the configured SAFEPAY_SECRET_KEY
    const liveTracker = liveSessionRes.body.data.tracker;
    const liveRef = liveSessionRes.body.data.paymentReference;
    const liveSig = safepayService.signTracker(liveTracker);

    const liveCallbackRes = await request(app)
      .get(
        `/api/wallet/safepay/callback?paymentReference=${encodeURIComponent(liveRef)}&tracker=${encodeURIComponent(liveTracker)}&sig=${encodeURIComponent(liveSig)}`
      )
      .set('Accept', 'application/json');

    expect(liveCallbackRes.statusCode).toBe(200);
    expect(liveCallbackRes.body.data.status).toBe('Paid');
    expect(liveCallbackRes.body.data.outstandingCommission).toBe(0);

    // Verify GET /api/wallet/safepay/return renders branded WaterFix HTML page with 5s countdown
    const htmlReturnRes = await request(app).get(
      `/api/wallet/safepay/return?paymentReference=${encodeURIComponent(liveRef)}&tracker=${encodeURIComponent(liveTracker)}`
    );
    expect(htmlReturnRes.statusCode).toBe(200);
    expect(htmlReturnRes.text).toContain('WaterFix');
    expect(htmlReturnRes.text).toContain('Payment successful');
    expect(htmlReturnRes.text).toContain('Returning to WaterFix in');
    expect(htmlReturnRes.text).toContain('Return to WaterFix');
    expect(htmlReturnRes.text).toContain('waterfix://payment/return');

    // Verify public authoritative status endpoint for return page polling
    const statusRes = await request(app).get(
      `/api/wallet/safepay/status?paymentReference=${encodeURIComponent(liveRef)}`
    );
    expect(statusRes.statusCode).toBe(200);
    expect(statusRes.body.data.isPaid).toBe(true);
    expect(statusRes.body.data.status).toBe('Paid');
    expect(statusRes.body.data.paymentReference).toBe(liveRef);
  });

  test('16. Admin Dashboard, Role Protection, Overdue Commission Calculation (7+ days vs <7 days vs future due date), Supplier/Customer Account Locking & Audit Logs', async () => {
    // A. Self-registering as admin is strictly forbidden (403)
    const selfAdminReg = await request(app).post('/api/auth/register').send({
      name: 'Fake Admin',
      email: 'fakeadmin@waterfix.pk',
      phone: '+923007778899',
      password: 'Password123!',
      role: 'admin',
    });
    expect(selfAdminReg.statusCode).toBe(403);

    // B. Regular customers and suppliers cannot access any /api/admin/* endpoints (403)
    for (const token of [customerToken, supplierToken]) {
      const dashAttempt = await request(app)
        .get('/api/admin/dashboard')
        .set('Authorization', `Bearer ${token}`);
      expect(dashAttempt.statusCode).toBe(403);

      const supListAttempt = await request(app)
        .get('/api/admin/suppliers')
        .set('Authorization', `Bearer ${token}`);
      expect(supListAttempt.statusCode).toBe(403);

      const lockAttempt = await request(app)
        .patch(`/api/admin/suppliers/${supplierId}/lock`)
        .set('Authorization', `Bearer ${token}`)
        .send({ locked: true, reason: 'Unauthorized lock attempt' });
      expect(lockAttempt.statusCode).toBe(403);
    }

    // C. Configured Admin Account Login (`env.adminEmail` / `env.adminPassword`)
    const wrongRoleAdminLogin = await request(app)
      .post('/api/auth/login')
      .send({
        identifier: env.adminEmail,
        password: env.adminPassword,
        role: 'customer',
      });
    expect(wrongRoleAdminLogin.statusCode).toBe(403);

    const adminLoginRes = await request(app).post('/api/auth/login').send({
      identifier: env.adminEmail,
      password: env.adminPassword,
      role: 'admin',
    });
    expect(adminLoginRes.statusCode).toBe(200);
    expect(adminLoginRes.body.data.user.role).toBe('admin');
    const adminToken = adminLoginRes.body.data.accessToken;

    // D. Overdue Commission Calculation Verification:
    // Clear existing charge entries and insert controlled due dates:
    // - Supplier 1 Entry A: due 8 days ago (Rs 300 charge, Rs 100 paid -> Rs 200 remaining -> 8 days overdue, >= 7 days)
    // - Supplier 1 Entry B: due 3 days in the future (Rs 200 charge, Rs 0 paid -> 0 days overdue because before due date)
    // - Supplier 2 Entry C: due 3 days ago (Rs 150 charge, Rs 0 paid -> 3 days overdue, < 7 days)
    await CommissionLedger.deleteMany({ type: 'commission_charge' });
    const now = new Date();
    const eightDaysAgo = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000 - 60000);
    const threeDaysAgo = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000 - 60000);
    const threeDaysFuture = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

    const sup1Doc = await SupplierProfile.findById(supplierId);
    const sup2Doc = await SupplierProfile.findById(supplier2Id);

    await CommissionLedger.create([
      {
        bookingCode: '#WF-8001',
        orderDate: eightDaysAgo,
        dueDate: eightDaysAgo,
        supplierId: sup1Doc._id,
        supplierUserId: sup1Doc.userId,
        type: 'commission_charge',
        grossBookingAmount: 3000,
        commissionRate: 0.1,
        commissionAmount: 300,
        paidAmount: 100,
        reversalAmount: 0,
        supplierNetAmount: 2700,
        status: 'partially_paid',
        outstandingBalanceAfter: 200,
      },
      {
        bookingCode: '#WF-8002',
        orderDate: now,
        dueDate: threeDaysFuture,
        supplierId: sup1Doc._id,
        supplierUserId: sup1Doc.userId,
        type: 'commission_charge',
        grossBookingAmount: 2000,
        commissionRate: 0.1,
        commissionAmount: 200,
        paidAmount: 0,
        reversalAmount: 0,
        supplierNetAmount: 1800,
        status: 'accrued',
        outstandingBalanceAfter: 400,
      },
      {
        bookingCode: '#WF-8003',
        orderDate: threeDaysAgo,
        dueDate: threeDaysAgo,
        supplierId: sup2Doc._id,
        supplierUserId: sup2Doc.userId,
        type: 'commission_charge',
        grossBookingAmount: 1500,
        commissionRate: 0.1,
        commissionAmount: 150,
        paidAmount: 0,
        reversalAmount: 0,
        supplierNetAmount: 1350,
        status: 'accrued',
        outstandingBalanceAfter: 150,
      },
    ]);

    sup1Doc.outstandingCommission = 400;
    sup1Doc.totalCommissionCharged = 500;
    sup1Doc.totalSettledCommission = 100;
    await sup1Doc.save();

    sup2Doc.outstandingCommission = 150;
    sup2Doc.totalCommissionCharged = 150;
    sup2Doc.totalSettledCommission = 0;
    await sup2Doc.save();

    // E. Verify Admin Dashboard Summary (`GET /api/admin/dashboard`)
    const dashRes = await request(app)
      .get('/api/admin/dashboard')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(dashRes.statusCode).toBe(200);
    const dashSummary = dashRes.body.data.summary;
    expect(dashSummary.totalSuppliers).toBe(2);
    expect(dashSummary.totalCustomers).toBe(1);
    expect(dashSummary.totalOutstandingCommissions).toBe(550);
    expect(dashSummary.overdueSuppliersCount).toBe(1); // Only Supplier 1 is >= 7 days overdue
    expect(dashSummary.lockedSuppliersCount).toBe(0);

    // F. Verify Supplier Filters (`all`, `outstanding`, `overdue_7_days`) & Detail Overdue Breakdown
    const overdue7Res = await request(app)
      .get('/api/admin/suppliers?filter=overdue_7_days')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(overdue7Res.statusCode).toBe(200);
    expect(overdue7Res.body.data.suppliers.length).toBe(1);
    expect(String(overdue7Res.body.data.suppliers[0]._id)).toBe(String(supplierId));
    expect(overdue7Res.body.data.suppliers[0].daysOverdue).toBe(8);
    expect(overdue7Res.body.data.suppliers[0].isOverdue7Days).toBe(true);
    expect(overdue7Res.body.data.suppliers[0].paymentStatus).toBe('Partially Paid');

    const sup1DetailRes = await request(app)
      .get(`/api/admin/suppliers/${supplierId}`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(sup1DetailRes.statusCode).toBe(200);
    const commItems = sup1DetailRes.body.data.commissionHistory;
    const item8001 = commItems.find((i) => i.bookingCode === '#WF-8001');
    const item8002 = commItems.find((i) => i.bookingCode === '#WF-8002');
    expect(item8001.daysOverdue).toBe(8);
    expect(item8001.isOverdue7Days).toBe(true);
    expect(item8002.daysOverdue).toBe(0); // Future dueDate is NOT overdue
    expect(item8002.isOverdue).toBe(false);

    // G. Lock Supplier 1 & Verify Audit Log + Backend Lock Enforcement
    const lockSupRes = await request(app)
      .patch(`/api/admin/suppliers/${supplierId}/lock`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        locked: true,
        reason: 'Commission overdue by 8 days (Rs 400 unpaid)',
      });
    expect(lockSupRes.statusCode).toBe(200);
    expect(lockSupRes.body.data.supplier.accountStatus).toBe('Locked');
    expect(lockSupRes.body.data.supplier.isLocked).toBe(true);
    expect(lockSupRes.body.data.auditLog.action).toBe('lock_supplier');

    // Duplicate lock request is idempotent
    const dupLockSupRes = await request(app)
      .patch(`/api/admin/suppliers/${supplierId}/lock`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ locked: true });
    expect(dupLockSupRes.statusCode).toBe(200);
    expect(dupLockSupRes.body.alreadyInState).toBe(true);

    // Locked supplier is excluded from customer discovery
    const discoverWhileLocked = await request(app).get(
      '/api/suppliers/discover?capacityLiters=1000'
    );
    const foundLockedSup = discoverWhileLocked.body.data.suppliers.find(
      (s) => String(s.supplierId) === String(supplierId)
    );
    expect(foundLockedSup).toBeUndefined();

    // Locked supplier is blocked from creating listings or going online
    const blockedListingRes = await request(app)
      .post('/api/suppliers/listings')
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ capacityLiters: 3000, waterPrice: 2000, deliveryFee: 300 });
    expect(blockedListingRes.statusCode).toBe(403);
    expect(blockedListingRes.body.code).toBe('ACCOUNT_LOCKED');

    const blockedOnlineRes = await request(app)
      .put('/api/suppliers/me')
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ isAvailable: true });
    expect(blockedOnlineRes.statusCode).toBe(403);
    expect(blockedOnlineRes.body.code).toBe('ACCOUNT_LOCKED');

    // Customer cannot book a locked supplier
    const blockedBookLockedSup = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        listingId: listing1000Id,
        supplierId,
        capacityLiters: 1000,
      });
    expect(blockedBookLockedSup.statusCode).toBe(403);

    // Locked supplier CAN still view their wallet (`GET /api/wallet`)
    const lockedSupplierWallet = await request(app)
      .get('/api/wallet')
      .set('Authorization', `Bearer ${supplierToken}`);
    expect(lockedSupplierWallet.statusCode).toBe(200);
    expect(lockedSupplierWallet.body.data.summary.accountStatus).toBe('Locked');
    expect(lockedSupplierWallet.body.data.summary.isLocked).toBe(true);
    expect(lockedSupplierWallet.body.data.summary.totalCommissionOwed).toBe(400);

    // Unlock Supplier 1 & verify restoration
    const unlockSupRes = await request(app)
      .patch(`/api/admin/suppliers/${supplierId}/lock`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        locked: false,
        reason: 'Supplier contacted finance and scheduled payment',
      });
    expect(unlockSupRes.statusCode).toBe(200);
    expect(unlockSupRes.body.data.supplier.accountStatus).toBe('Active');
    expect(unlockSupRes.body.data.supplier.isLocked).toBe(false);
    expect(unlockSupRes.body.data.auditLog.action).toBe('unlock_supplier');

    // H. Customer Management & Customer Lock/Unlock Enforcement
    const custListRes = await request(app)
      .get('/api/admin/customers')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(custListRes.statusCode).toBe(200);
    expect(custListRes.body.data.customers.length).toBe(1);
    const custId = custListRes.body.data.customers[0]._id;
    expect(custListRes.body.data.customers[0].orderCount).toBeGreaterThanOrEqual(4);

    const lockCustRes = await request(app)
      .patch(`/api/admin/customers/${custId}/lock`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ locked: true, reason: 'Suspicious booking activity' });
    expect(lockCustRes.statusCode).toBe(200);
    expect(lockCustRes.body.data.customer.accountStatus).toBe('Locked');

    // Locked customer is blocked from placing new bookings
    const lockedCustBookRes = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        listingId: supplier2Listing1000Id,
        supplierId: supplier2Id,
        capacityLiters: 1000,
      });
    expect(lockedCustBookRes.statusCode).toBe(403);
    expect(lockedCustBookRes.body.code).toBe('ACCOUNT_LOCKED');

    // Unlock customer
    const unlockCustRes = await request(app)
      .patch(`/api/admin/customers/${custId}/lock`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ locked: false, reason: 'Account verified' });
    expect(unlockCustRes.statusCode).toBe(200);
    expect(unlockCustRes.body.data.customer.accountStatus).toBe('Active');

    // I. Payments Management & Filters (`all`, `paid`, `failed`, `outstanding_commissions`)
    const paymentsAllRes = await request(app)
      .get('/api/admin/payments?filter=all')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(paymentsAllRes.statusCode).toBe(200);
    expect(paymentsAllRes.body.data.counts.allPayments).toBeGreaterThan(0);

    const paymentsOutstandingRes = await request(app)
      .get('/api/admin/payments?filter=outstanding_commissions')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(paymentsOutstandingRes.statusCode).toBe(200);
    expect(paymentsOutstandingRes.body.data.items.length).toBe(3);

    const firstPaymentId = paymentsAllRes.body.data.items[0]._id;
    const paymentDetailRes = await request(app)
      .get(`/api/admin/payments/${firstPaymentId}`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(paymentDetailRes.statusCode).toBe(200);
    expect(paymentDetailRes.body.data.payment).toBeDefined();

    // J. Audit Logs endpoint returns recorded supplier & customer lock/unlock events
    const auditRes = await request(app)
      .get('/api/admin/audit-logs')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(auditRes.statusCode).toBe(200);
    expect(auditRes.body.data.auditLogs.length).toBeGreaterThanOrEqual(4);
  });
});
