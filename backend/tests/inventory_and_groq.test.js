process.env.NODE_ENV = 'test';
const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const env = require('../src/config/env');
const { connectDB, disconnectDB } = require('../src/config/db');
const SupplierProfile = require('../src/models/SupplierProfile');
const SupplierListing = require('../src/models/SupplierListing');
const Booking = require('../src/models/Booking');
const { ISLAMABAD_LOCALITIES, searchIslamabadLocalities } = require('../src/utils/islamabadLocalities');

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/waterfix_inventory_test_db';

describe('WaterFix Inventory, Smart Pricing, Islamabad Localities & Groq AI Tests', () => {
  let customerToken;
  let supplierToken;
  let supplierProfileId;

  beforeAll(async () => {
    await connectDB(TEST_DB_URI);
    // Setup test customer
    const custRes = await request(app).post('/api/auth/register').send({
      name: 'Test Customer',
      email: 'test_cust_upgrade@waterfix.pk',
      phone: '0300 1239999',
      password: 'Pass1234Customer!',
      confirmPassword: 'Pass1234Customer!',
      role: 'customer',
    });
    customerToken = custRes.body.data.accessToken;

    // Setup test supplier with company inventory
    const supRes = await request(app).post('/api/auth/register').send({
      name: 'Ashhad Hanif',
      businessName: 'Ashhad Water Tanker Company',
      email: 'ashhad_company_test@waterfix.pk',
      phone: '0308 0332599',
      password: 'Pass1234Supplier!',
      confirmPassword: 'Pass1234Supplier!',
      role: 'supplier',
      city: 'Islamabad',
      serviceAreaText: 'Hostel City & Islamabad',
      lat: 33.6515,
      lng: 73.1566,
      serviceRadiusKm: 15,
      tankersOwned: 4,
      availableWaterLiters: 10000,
      pricePer1000Liters: 1800,
    });
    supplierToken = supRes.body.data.accessToken;
    supplierProfileId = supRes.body.data.supplierProfile._id;
  });

  afterAll(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.dropDatabase();
    }
    await disconnectDB();
  });

  test('1. 50+ genuine Islamabad localities are available and Hostel City is searchable', async () => {
    expect(ISLAMABAD_LOCALITIES.length).toBeGreaterThanOrEqual(50);

    const hostelCity = ISLAMABAD_LOCALITIES.find((l) =>
      l.name.toLowerCase().includes('hostel city')
    );
    expect(hostelCity).toBeDefined();
    expect(hostelCity.lat).toBeCloseTo(33.6515, 2);
    expect(hostelCity.lng).toBeCloseTo(73.1566, 2);

    const res = await request(app).get('/api/locations/islamabad?query=Hostel');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.locations.length).toBeGreaterThanOrEqual(1);
    expect(res.body.locations[0].name).toContain('Hostel City');
  });

  test('2. Supplier delivery radius validation enforces 1 km to 20 km strictly', async () => {
    // Attempt updating radius > 20 km is rejected
    const invalidRes = await request(app)
      .put('/api/suppliers/me')
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ serviceRadiusKm: 25 });
    expect(invalidRes.statusCode).toBe(400);
    expect(invalidRes.body.message).toContain('between 1 km and 20 km');

    // Valid update to 18 km succeeds
    const validRes = await request(app)
      .put('/api/suppliers/me')
      .set('Authorization', `Bearer ${supplierToken}`)
      .send({ serviceRadiusKm: 18, tankersOwned: 5, availableWaterLiters: 12000, pricePer1000Liters: 1750 });
    expect(validRes.statusCode).toBe(200);
    expect(validRes.body.data.serviceRadiusKm).toBe(18);
    expect(validRes.body.data.tankersOwned).toBe(5);
    expect(validRes.body.data.availableWaterLiters).toBe(12000);
  });

  test('3. Custom water quantity ordering: 500 L minimum, accurate price calculation, and atomic inventory deduction', async () => {
    // A. Order below 500 L is rejected
    const tooLowRes = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        supplierId: supplierProfileId,
        waterQuantityLiters: 400,
      });
    expect(tooLowRes.statusCode).toBe(400);
    expect(tooLowRes.body.message).toContain('at least 500');

    // B. Order 2,500 L succeeds with deterministic pricing
    // Rate: 1750 / 1000 L -> 2,500 L water = 4,375. Delivery: 250. Total: 4,625.
    const beforeSupplier = await SupplierProfile.findById(supplierProfileId);
    const stockBefore = beforeSupplier.availableWaterLiters;

    const orderRes = await request(app)
      .post('/api/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        supplierId: supplierProfileId,
        waterQuantityLiters: 2500,
        expectedTotalPrice: 4625,
        deliveryAddress: {
          addressLine: 'Street 4, Hostel City, Islamabad',
          lat: 33.6515,
          lng: 73.1566,
        },
      });

    expect(orderRes.statusCode).toBe(201);
    expect(orderRes.body.data.capacityLiters).toBe(2500);
    expect(orderRes.body.data.waterPrice).toBe(4375);
    expect(orderRes.body.data.deliveryFee).toBe(250);
    expect(orderRes.body.data.totalPrice).toBe(4625);

    // Verify atomic inventory reservation (12,000 - 2,500 = 9,500)
    const afterSupplier = await SupplierProfile.findById(supplierProfileId);
    expect(afterSupplier.availableWaterLiters).toBe(stockBefore - 2500);

    // C. Cancellation atomically restores inventory exactly once
    const cancelRes = await request(app)
      .post(`/api/bookings/${orderRes.body.data._id}/status`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ status: 'cancelled', reason: 'Change of plan' });
    expect(cancelRes.statusCode).toBe(200);

    const restoredSupplier = await SupplierProfile.findById(supplierProfileId);
    expect(restoredSupplier.availableWaterLiters).toBe(stockBefore);
  });

  test('4. Real Groq AI proxy endpoint returns intelligent recommendations for Islamabad', async () => {
    const aiRes = await request(app).get(
      '/api/ai/recommendations?capacityLiters=1000&lat=33.6515&lng=73.1566&sortBy=best_match'
    );
    expect(aiRes.statusCode).toBe(200);
    expect(aiRes.body.success).toBe(true);
    expect(Array.isArray(aiRes.body.data.suppliers)).toBe(true);
    if (aiRes.body.data.suppliers.length > 0) {
      expect(aiRes.body.data.suppliers[0].businessName).toBeDefined();
      expect(aiRes.body.data.suppliers[0].isAiPick).toBe(true);
      expect(aiRes.body.data.suppliers[0].availableWaterLiters).toBeGreaterThanOrEqual(1000);
    }
  });
});
