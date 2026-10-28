process.env.NODE_ENV = 'test';
const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const { connectDB, disconnectDB } = require('../src/config/db');
const User = require('../src/models/User');
const SupplierProfile = require('../src/models/SupplierProfile');
const EmailOtp = require('../src/models/EmailOtp');
const AdminAuditLog = require('../src/models/AdminAuditLog');
const { isValidCnic, normalizeCnic, maskCnic } = require('../src/utils/validators');

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/waterfix_otp_test_db';

beforeAll(async () => {
  await connectDB(TEST_DB_URI);
  await Promise.all([
    User.deleteMany({}),
    SupplierProfile.deleteMany({}),
    EmailOtp.deleteMany({}),
    AdminAuditLog.deleteMany({}),
  ]);
});

afterAll(async () => {
  await disconnectDB();
});

describe('WaterFix Email OTP, CNIC Validation & Admin Approval Suite', () => {
  let adminToken;
  let adminUser;

  beforeAll(async () => {
    // Create admin account
    const res = await request(app).post('/api/auth/register').send({
      name: 'System Admin',
      email: 'admin_test@waterfix.pk',
      phone: '+923000000001',
      password: 'AdminPassword123!',
      cnic: '35201-1111111-1',
      role: 'customer',
    });
    adminUser = await User.findById(res.body.data.user._id);
    adminUser.role = 'admin';
    adminUser.approvalStatus = 'approved';
    adminUser.emailVerified = true;
    await adminUser.save();

    const loginRes = await request(app).post('/api/auth/login').send({
      identifier: 'admin_test@waterfix.pk',
      password: 'AdminPassword123!',
    });
    adminToken = loginRes.body.data.accessToken;
  });

  test('1. CNIC Validators correctly validate, normalize, and mask 13-digit Pakistani CNICs', () => {
    expect(isValidCnic('35201-1234567-1')).toBe(true);
    expect(isValidCnic('3520112345671')).toBe(true);
    expect(isValidCnic('35201-123456-1')).toBe(false); // 12 digits
    expect(isValidCnic('35201-12345678-1')).toBe(false); // 14 digits
    expect(isValidCnic('abcde-1234567-1')).toBe(false);

    expect(normalizeCnic('35201-1234567-1')).toBe('35201-1234567-1');
    expect(maskCnic('3520112345671')).toBe('35201-*******-1');
  });

  test('2. New Customer signs up with CNIC: gets pending_approval and unverified email', async () => {
    const res = await request(app).post('/api/auth/register').send({
      name: 'Bilal Khan',
      email: 'bilal@waterfix.pk',
      phone: '+923019876543',
      password: 'Password123!',
      cnic: '35202-7654321-3',
      role: 'customer',
      testNewApprovalFlow: true,
    });

    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.emailVerified).toBe(false);
    expect(res.body.data.user.approvalStatus).toBe('pending_approval');
    expect(res.body.data.user.cnicMasked).toBe('35202-*******-3');
    // Raw CNIC must not be exposed in user JSON
    expect(res.body.data.user.cnicNumber).toBeUndefined();

    // Verify OTP record was generated in database
    const otpDoc = await EmailOtp.findOne({ email: 'bilal@waterfix.pk' });
    expect(otpDoc).toBeDefined();
    expect(otpDoc.isUsed).toBe(false);
    expect(otpDoc.otpHash).toBeDefined();
  });

  test('3. Verification with invalid OTP fails and increments attempts', async () => {
    const failRes = await request(app).post('/api/auth/verify-email-otp').send({
      email: 'bilal@waterfix.pk',
      otp: '000000',
    });

    expect(failRes.statusCode).toBe(400);
    expect(failRes.body.success).toBe(false);

    const otpDoc = await EmailOtp.findOne({ email: 'bilal@waterfix.pk' });
    expect(otpDoc.attempts).toBe(1);
  });

  test('4. Resend OTP enforces 60-second cooldown', async () => {
    const resendRes = await request(app).post('/api/auth/resend-email-otp').send({
      email: 'bilal@waterfix.pk',
    });

    expect(resendRes.statusCode).toBe(429);
    expect(resendRes.body.cooldownSeconds).toBeGreaterThan(0);
  });

  test('5. Verify with correct OTP marks emailVerified = true', async () => {
    const crypto = require('crypto');
    const knownHash = crypto.createHash('sha256').update('123456').digest('hex');
    await EmailOtp.updateOne({ email: 'bilal@waterfix.pk' }, { $set: { otpHash: knownHash } });

    const okRes = await request(app).post('/api/auth/verify-email-otp').send({
      email: 'bilal@waterfix.pk',
      otp: '123456',
    });

    expect(okRes.statusCode).toBe(200);
    expect(okRes.body.success).toBe(true);
    expect(okRes.body.data.emailVerified).toBe(true);
    expect(okRes.body.data.approvalStatus).toBe('pending_approval');
  });

  test('6. Unapproved customer cannot create booking before admin approval', async () => {
    const loginRes = await request(app).post('/api/auth/login').send({
      identifier: 'bilal@waterfix.pk',
      password: 'Password123!',
    });
    const bilalToken = loginRes.body.data.accessToken;

    const bookRes = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${bilalToken}`)
      .send({
        waterQuantityLiters: 1000,
        deliveryAddress: { addressLine: 'Hostel City' },
      });

    expect(bookRes.statusCode).toBe(403);
    expect(bookRes.body.code).toBe('ACCOUNT_NOT_APPROVED');
  });

  test('7. Admin views pending customers and approves customer Bilal', async () => {
    const pendingRes = await request(app)
      .get('/api/admin/pending-customers')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(pendingRes.statusCode).toBe(200);
    const bilalEntry = pendingRes.body.data.pendingCustomers.find(
      (c) => c.email === 'bilal@waterfix.pk'
    );
    expect(bilalEntry).toBeDefined();
    // Admin review has access to CNIC
    expect(bilalEntry.cnicNumber).toBe('35202-7654321-3');

    // Admin approves Bilal
    const approveRes = await request(app)
      .post(`/api/admin/customers/${bilalEntry._id}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});

    expect(approveRes.statusCode).toBe(200);
    expect(approveRes.body.data.approvalStatus).toBe('approved');

    // Check that Bilal is no longer in pending list
    const pendingAfter = await request(app)
      .get('/api/admin/pending-customers')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(
      pendingAfter.body.data.pendingCustomers.some((c) => c.email === 'bilal@waterfix.pk')
    ).toBe(false);
  });

  test('8. New Supplier registration with CNIC is pending; appears in pending-suppliers', async () => {
    const supRes = await request(app).post('/api/auth/register').send({
      name: 'Tariq Mehmood',
      businessName: 'Tariq Clean Waters',
      email: 'tariq@waterfix.pk',
      phone: '+923021112233',
      password: 'SupplierPassword123!',
      cnic: '37405-9876543-5',
      role: 'supplier',
      testNewApprovalFlow: true,
      serviceRadiusKm: 18,
      tankersOwned: 3,
      pricePer1000Liters: 2200,
      availableWaterLiters: 15000,
    });

    expect(supRes.statusCode).toBe(201);
    expect(supRes.body.data.user.approvalStatus).toBe('pending_approval');

    // Pending supplier should NOT appear in customer discovery
    const discoverRes = await request(app).get('/api/suppliers/discover');
    expect(discoverRes.statusCode).toBe(200);
    const foundInDiscovery = discoverRes.body.data.suppliers.some(
      (s) => s.businessName === 'Tariq Clean Waters'
    );
    expect(foundInDiscovery).toBe(false);

    // Admin views pending suppliers
    const adminSupRes = await request(app)
      .get('/api/admin/pending-suppliers')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(adminSupRes.statusCode).toBe(200);
    const tariqEntry = adminSupRes.body.data.pendingSuppliers.find(
      (s) => s.email === 'tariq@waterfix.pk'
    );
    expect(tariqEntry).toBeDefined();
    expect(tariqEntry.cnicNumber).toBe('37405-9876543-5');

    // Admin approves supplier
    const supApproveRes = await request(app)
      .post(`/api/admin/suppliers/${tariqEntry._id}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});
    expect(supApproveRes.statusCode).toBe(200);
    expect(supApproveRes.body.data.approvalStatus).toBe('approved');

    // Now supplier appears in discovery!
    const discoverAfter = await request(app).get('/api/suppliers/discover');
    const foundAfter = discoverAfter.body.data.suppliers.some(
      (s) => s.businessName === 'Tariq Clean Waters'
    );
    expect(foundAfter).toBe(true);
  });

  test('7. Unverified account is blocked from signing in with 403 EMAIL_NOT_VERIFIED', async () => {
    // Register a new unverified user
    await request(app).post('/api/auth/register').send({
      name: 'Unverified Test User',
      email: 'unverified_pending@waterfix.pk',
      phone: '+923010009988',
      password: 'Password123!',
      cnic: '35201-9876540-1',
      role: 'customer',
      testNewApprovalFlow: true,
    });

    const loginRes = await request(app).post('/api/auth/login').send({
      identifier: 'unverified_pending@waterfix.pk',
      password: 'Password123!',
    });

    expect(loginRes.statusCode).toBe(403);
    expect(loginRes.body.code).toBe('EMAIL_NOT_VERIFIED');
    expect(loginRes.body.data.requiresEmailVerification).toBe(true);
  });

  test('8. Abandoned unverified registration is overwritten cleanly without 409 conflict', async () => {
    // Attempt re-registering with same email 'unverified_pending@waterfix.pk' while still unverified
    const reRegRes = await request(app).post('/api/auth/register').send({
      name: 'Unverified Test User Updated',
      email: 'unverified_pending@waterfix.pk',
      phone: '+923010009988',
      password: 'NewPassword123!',
      cnic: '35201-9876540-1',
      role: 'customer',
      testNewApprovalFlow: true,
    });

    expect(reRegRes.statusCode).toBe(201);
    expect(reRegRes.body.success).toBe(true);
    expect(reRegRes.body.data.user.name).toBe('Unverified Test User Updated');
    expect(reRegRes.body.data.accessToken).toBeUndefined(); // No tokens issued before OTP verification
  });

  test('9. Realistic supplier limits enforce stock (<= 500,000 L), tankers (<= 100), and price (<= 25,000 PKR)', async () => {
    // A. Unrealistic stock (e.g., 999,999,996,000 L as in screenshot) is rejected
    const badStockRes = await request(app).post('/api/auth/register').send({
      name: 'Exorbitant Stock Supplier',
      businessName: 'Unrealistic Waters',
      email: 'unrealistic_stock@waterfix.pk',
      phone: '+923011112222',
      password: 'SupplierPass1!',
      cnic: '35201-9999991-1',
      role: 'supplier',
      availableWaterLiters: 999999996000,
      tankersOwned: 5,
    });
    expect(badStockRes.statusCode).toBe(400);
    expect(badStockRes.body.message).toContain('500,000');

    // B. Unrealistic fleet (e.g., 500,000 tankers as in screenshot) is rejected
    const badFleetRes = await request(app).post('/api/auth/register').send({
      name: 'Exorbitant Fleet Supplier',
      businessName: 'Unrealistic Fleet',
      email: 'unrealistic_fleet@waterfix.pk',
      phone: '+923011112223',
      password: 'SupplierPass1!',
      cnic: '35201-9999992-1',
      role: 'supplier',
      availableWaterLiters: 10000,
      tankersOwned: 500000,
    });
    expect(badFleetRes.statusCode).toBe(400);
    expect(badFleetRes.body.message).toContain('100');

    // C. Exorbitant price is rejected
    const badPriceRes = await request(app).post('/api/auth/register').send({
      name: 'Exorbitant Price Supplier',
      businessName: 'Unrealistic Price',
      email: 'unrealistic_price@waterfix.pk',
      phone: '+923011112224',
      password: 'SupplierPass1!',
      cnic: '35201-9999993-1',
      role: 'supplier',
      pricePer1000Liters: 999999,
    });
    expect(badPriceRes.statusCode).toBe(400);
    expect(badPriceRes.body.message).toContain('25,000');
  });

  test('10. Customer water booking quantity bounds (500 L to 10,000 L) are strictly enforced', async () => {
    // Approve Bilal as customer
    const bilalUser = await User.findOne({ email: 'bilal@waterfix.pk' });
    bilalUser.approvalStatus = 'approved';
    await bilalUser.save();

    const customerLogin = await request(app).post('/api/auth/login').send({
      identifier: 'bilal@waterfix.pk',
      password: 'Password123!',
    });
    const customerToken = customerLogin.body.data.accessToken;

    const suppliers = await SupplierProfile.find({ approvalStatus: 'approved' });
    const sup = suppliers[0];

    // A. Order exceeding 10,000 L (e.g. 9999999999 L as in screenshot) is rejected
    const tooLargeRes = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        supplierId: sup._id.toString(),
        waterQuantityLiters: 9999999999,
        deliveryAddress: {
          addressLine: 'Street 1, F-10, Islamabad',
          lat: 33.6938,
          lng: 73.0169,
        },
      });
    expect(tooLargeRes.statusCode).toBe(400);
    expect(tooLargeRes.body.message).toContain('10,000');

    // B. Order under 500 L is rejected
    const tooSmallRes = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        supplierId: sup._id.toString(),
        waterQuantityLiters: 499,
        deliveryAddress: {
          addressLine: 'Street 1, F-10, Islamabad',
          lat: 33.6938,
          lng: 73.0169,
        },
      });
    expect(tooSmallRes.statusCode).toBe(400);
    expect(tooSmallRes.body.message).toContain('500');
  });
});
