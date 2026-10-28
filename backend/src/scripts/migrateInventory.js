const mongoose = require('mongoose');
const env = require('../config/env');
const SupplierProfile = require('../models/SupplierProfile');
const SupplierListing = require('../models/SupplierListing');
const Booking = require('../models/Booking');

async function runInventoryMigration() {
  const isDirect = require.main === module;
  if (isDirect) {
    await mongoose.connect(env.mongoUri);
    console.log('[Migration] Connected to database:', env.mongoUri);
  }

  const suppliers = await SupplierProfile.find({});
  console.log(`[Migration] Inspecting ${suppliers.length} supplier profile(s)...`);

  for (const supplier of suppliers) {
    let updated = false;

    // Enforce 20 km max radius
    if (!supplier.serviceRadiusKm || supplier.serviceRadiusKm > 20) {
      supplier.serviceRadiusKm = Math.min(20, Math.max(1, supplier.serviceRadiusKm || 15));
      updated = true;
    }

    // Initialize company inventory fields if missing
    if (typeof supplier.tankersOwned !== 'number' || supplier.tankersOwned < 1) {
      supplier.tankersOwned = 1;
      updated = true;
    }
    if (typeof supplier.availableWaterLiters !== 'number') {
      supplier.availableWaterLiters = 10000;
      updated = true;
    }
    if (typeof supplier.pricePer1000Liters !== 'number' || supplier.pricePer1000Liters < 100) {
      supplier.pricePer1000Liters = 1800;
      updated = true;
    }

    // Enforce realistic bounds (0 - 500,000 L stock, 1 - 100 tankers, PKR 100 - PKR 25,000 price)
    if (typeof supplier.availableWaterLiters === 'number' && supplier.availableWaterLiters > 500000) {
      console.log(`[Migration] Sanitizing unrealistic stock for ${supplier.businessName}: ${supplier.availableWaterLiters} -> 15000`);
      supplier.availableWaterLiters = 15000;
      updated = true;
    }
    if (typeof supplier.tankersOwned === 'number' && supplier.tankersOwned > 100) {
      console.log(`[Migration] Sanitizing unrealistic tanker count for ${supplier.businessName}: ${supplier.tankersOwned} -> 4`);
      supplier.tankersOwned = 4;
      updated = true;
    }
    if (typeof supplier.pricePer1000Liters === 'number' && supplier.pricePer1000Liters > 25000) {
      console.log(`[Migration] Sanitizing unrealistic price for ${supplier.businessName}: ${supplier.pricePer1000Liters} -> 2500`);
      supplier.pricePer1000Liters = 2500;
      updated = true;
    }
    const isAshhad =
      (supplier.businessName && supplier.businessName.toLowerCase().includes('ashhad')) ||
      supplier.phone === '+923080332593';

    if (isAshhad) {
      supplier.tankersOwned = 4;
      supplier.availableWaterLiters = 10000;
      supplier.pricePer1000Liters = 1800;
      supplier.serviceRadiusKm = 15;
      supplier.serviceAreaText = 'Hostel City & Islamabad';
      updated = true;
      console.log(`[Migration] Updated Ashhad Water Tanker company profile.`);
    }

    if (updated) {
      await supplier.save();
    }

    // Consolidate duplicate listings for this supplier
    const allListings = await SupplierListing.find({ supplierId: supplier._id }).sort({
      createdAt: 1,
    });
    if (allListings.length > 1) {
      console.log(
        `[Migration] Consolidating ${allListings.length} listings for supplier '${supplier.businessName}'...`
      );
      // Keep the first active listing as the primary representative listing
      const primaryListing = allListings[0];
      primaryListing.isActive = true;
      primaryListing.isAvailable = true;
      primaryListing.capacityLiters = 1000;
      primaryListing.waterPrice = 1550;
      primaryListing.deliveryFee = 250;
      primaryListing.totalPrice = 1800;
      await primaryListing.save();

      // Deactivate obsolete duplicate listings without deleting historical records
      for (let i = 1; i < allListings.length; i++) {
        const dup = allListings[i];
        dup.isActive = false;
        dup.isAvailable = false;
        await dup.save();
        console.log(`[Migration] Marked obsolete duplicate listing ${dup._id} as inactive.`);
      }
    } else if (allListings.length === 0) {
      // Create a default company listing if none exists
      await SupplierListing.create({
        supplierId: supplier._id,
        userId: supplier.userId,
        capacityLiters: 1000,
        waterPrice: 1550,
        deliveryFee: 250,
        totalPrice: 1800,
        isAvailable: true,
        isActive: true,
        label: 'Company Tanker',
      });
      console.log(`[Migration] Created representative listing for supplier '${supplier.businessName}'.`);
    }
  }

  // Ensure historical bookings have waterQuantityLiters & pricePer1000Liters populated
  const bookings = await Booking.find({ waterQuantityLiters: { $exists: false } });
  if (bookings.length > 0) {
    console.log(`[Migration] Populating waterQuantityLiters on ${bookings.length} historical bookings...`);
    for (const b of bookings) {
      b.waterQuantityLiters = b.capacityLiters || 1000;
      b.pricePer1000Liters = b.waterPrice || 1550;
      b.inventoryRestored = b.status === 'cancelled' || b.status === 'rejected';
      await b.save();
    }
  }

  console.log('[Migration] Inventory model migration completed successfully.');
  if (isDirect) {
    await mongoose.disconnect();
  }
}

if (require.main === module) {
  runInventoryMigration()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('[Migration] Failed:', err);
      process.exit(1);
    });
}

module.exports = { runInventoryMigration };
