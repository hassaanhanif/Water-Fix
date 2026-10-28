const User = require('../models/User');
const SupplierProfile = require('../models/SupplierProfile');
const SupplierListing = require('../models/SupplierListing');
const Review = require('../models/Review');
const Booking = require('../models/Booking');
const {
  rankCompanies,
  rankSupplierListings,
  getSmartRecommendations,
} = require('../services/recommendationService');
const { haversineDistanceKm } = require('../utils/geo');
const { normalizeEmail, isValidEmail, normalizePhone, isValidPhone } = require('../utils/validators');

exports.getMySupplierDashboard = async (req, res, next) => {
  try {
    let profile = await SupplierProfile.findOne({ userId: req.user._id });
    if (!profile) {
      profile = await SupplierProfile.create({
        userId: req.user._id,
        ownerName: req.user.name,
        businessName: `${req.user.name} Water Supply`,
        email: req.user.email,
        phone: req.user.phone,
        isVerified: false,
      });
    }

    const listings = await SupplierListing.find({ supplierId: profile._id }).sort({
      capacityLiters: 1,
    });
    const bookings = await Booking.find({ supplierId: profile._id })
      .sort({ createdAt: -1 })
      .limit(50);
    const reviews = await Review.find({ supplierId: profile._id })
      .sort({ createdAt: -1 })
      .limit(20);

    res.json({
      success: true,
      data: {
        profile,
        listings,
        bookings,
        reviews,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.updateSupplierProfile = async (req, res, next) => {
  try {
    let profile = await SupplierProfile.findOne({ userId: req.user._id });
    if (!profile) {
      profile = new SupplierProfile({
        userId: req.user._id,
        ownerName: req.user.name,
        businessName: `${req.user.name} Water Supply`,
        email: req.user.email,
        phone: req.user.phone,
      });
    }

    const {
      ownerName,
      businessName,
      email,
      phone,
      city,
      serviceAreaText,
      lat,
      lng,
      serviceRadiusKm,
      tankersOwned,
      availableWaterLiters,
      pricePer1000Liters,
      companyLogo,
      isAvailable,
      deliveryInfo,
      driverName,
    } = req.body;

    if (ownerName) profile.ownerName = ownerName.trim();
    if (businessName) profile.businessName = businessName.trim();
    if (city) profile.city = city.trim();
    if (serviceAreaText) profile.serviceAreaText = serviceAreaText.trim();
    if (typeof lat === 'number') profile.lat = lat;
    if (typeof lng === 'number') profile.lng = lng;

    if (serviceRadiusKm !== undefined) {
      const r = Number(serviceRadiusKm);
      if (Number.isNaN(r) || r < 1 || r > 20) {
        return res.status(400).json({
          success: false,
          message: 'Service radius must be between 1 km and 20 km.',
        });
      }
      profile.serviceRadiusKm = r;
    }

    if (tankersOwned !== undefined) {
      const t = parseInt(tankersOwned, 10);
      if (Number.isNaN(t) || t < 1 || t > 100) {
        return res.status(400).json({
          success: false,
          message: 'Tanker fleet size must be between 1 and 100 tankers.',
        });
      }
      profile.tankersOwned = t;
    }

    if (availableWaterLiters !== undefined) {
      const w = Number(availableWaterLiters);
      if (Number.isNaN(w) || w < 0 || w > 500000) {
        return res.status(400).json({
          success: false,
          message: 'Available water inventory must be between 0 and 500,000 litres.',
        });
      }
      profile.availableWaterLiters = Math.round(w);
    }

    if (pricePer1000Liters !== undefined) {
      const p = Number(pricePer1000Liters);
      if (Number.isNaN(p) || p < 100 || p > 25000) {
        return res.status(400).json({
          success: false,
          message: 'Price per 1,000 litres must be between PKR 100 and PKR 25,000.',
        });
      }
      profile.pricePer1000Liters = Math.round(p);
      // Sync primary active listing for backward compatibility
      await SupplierListing.updateMany(
        { supplierId: profile._id, isActive: true },
        {
          $set: {
            waterPrice: Math.max(100, p - 250),
            totalPrice: p,
          },
        }
      );
    }

    if (companyLogo !== undefined) {
      profile.companyLogo = companyLogo ? String(companyLogo).trim() : null;
    }

    if (isAvailable !== undefined) {
      if (Boolean(isAvailable) && (req.user.isLocked || profile.isLocked)) {
        return res.status(403).json({
          success: false,
          code: 'ACCOUNT_LOCKED',
          message: `Your supplier account is locked (${
            profile.lockReason || req.user.lockReason || 'Overdue commission'
          }). You cannot go online until your account is unlocked.`,
        });
      }
      profile.isAvailable = Boolean(isAvailable);
    }

    if (deliveryInfo !== undefined) profile.deliveryInfo = deliveryInfo.trim();
    if (driverName !== undefined) profile.driverName = driverName.trim();

    // Sync User auth account when email or phone changes
    const user = await User.findById(req.user._id);
    if (user) {
      if (email && email !== profile.email) {
        const normEmail = normalizeEmail(email);
        if (!isValidEmail(normEmail)) {
          return res.status(400).json({
            success: false,
            message: 'Please provide a valid email address.',
          });
        }
        const existing = await User.findOne({ email: normEmail, _id: { $ne: user._id } });
        if (existing) {
          return res.status(409).json({
            success: false,
            message: 'Email address is already in use by another account.',
          });
        }
        user.email = normEmail;
        profile.email = normEmail;
      }

      if (phone && phone !== profile.phone) {
        const normPhone = normalizePhone(phone);
        if (!isValidPhone(normPhone)) {
          return res.status(400).json({
            success: false,
            message: 'Please provide a valid phone number (e.g. 03001234567).',
          });
        }
        const existing = await User.findOne({ phone: normPhone, _id: { $ne: user._id } });
        if (existing) {
          return res.status(409).json({
            success: false,
            message: 'Phone number is already in use by another account.',
          });
        }
        user.phone = normPhone;
        profile.phone = normPhone;
      }

      if (ownerName) {
        user.name = ownerName.trim();
      }

      await user.save();
    }

    await profile.save();
    res.json({
      success: true,
      message: 'Supplier profile updated successfully.',
      data: profile,
    });
  } catch (err) {
    next(err);
  }
};

exports.createListing = async (req, res, next) => {
  try {
    const profile = await SupplierProfile.findOne({ userId: req.user._id });
    if (!profile) {
      return res.status(404).json({
        success: false,
        message: 'Supplier profile not found.',
      });
    }

    if (req.user.isLocked || profile.isLocked) {
      return res.status(403).json({
        success: false,
        code: 'ACCOUNT_LOCKED',
        message: `Your supplier account is locked (${
          profile.lockReason || req.user.lockReason || 'Overdue commission'
        }). Please settle your outstanding commission in the Wallet tab.`,
      });
    }

    const {
      capacityLiters,
      isCustomCapacity,
      label,
      waterPrice,
      deliveryFee,
      estimatedArrivalMinutesMin,
      estimatedArrivalMinutesMax,
      isAvailable,
      serviceNotes,
    } = req.body;

    const cap = Number(capacityLiters);
    if (!cap || cap < 500) {
      return res.status(400).json({
        success: false,
        message: 'Valid tanker capacity (at least 500 L) is required.',
      });
    }

    const wPrice = Number(waterPrice);
    if (Number.isNaN(wPrice) || wPrice < 100) {
      return res.status(400).json({
        success: false,
        message: 'Valid water price (at least Rs 100) is required.',
      });
    }

    const dFee = deliveryFee !== undefined ? Number(deliveryFee) : 250;
    if (Number.isNaN(dFee) || dFee < 0) {
      return res.status(400).json({
        success: false,
        message: 'Delivery fee cannot be negative.',
      });
    }

    const totalPrice = wPrice + dFee;

    const defaultLabel =
      cap <= 2000
        ? 'Most homes'
        : cap >= 4000
        ? 'Buildings and sites'
        : 'Standard tanker';

    const listing = await SupplierListing.create({
      supplierId: profile._id,
      userId: req.user._id,
      capacityLiters: cap,
      isCustomCapacity: Boolean(isCustomCapacity),
      label: label ? label.trim() : defaultLabel,
      waterPrice: wPrice,
      deliveryFee: dFee,
      totalPrice,
      estimatedArrivalMinutesMin: Number(estimatedArrivalMinutesMin) || 35,
      estimatedArrivalMinutesMax: Number(estimatedArrivalMinutesMax) || 45,
      isAvailable: isAvailable !== undefined ? Boolean(isAvailable) : true,
      isActive: true,
      serviceNotes: serviceNotes || '',
    });

    // Keep supplier profile rate aligned with newly set price
    profile.pricePer1000Liters = wPrice;
    await profile.save();

    res.status(201).json({
      success: true,
      message: 'Tanker listing published.',
      data: listing,
    });
  } catch (err) {
    next(err);
  }
};

exports.updateListing = async (req, res, next) => {
  try {
    const profile = await SupplierProfile.findOne({ userId: req.user._id });
    if (req.user.isLocked || (profile && profile.isLocked)) {
      return res.status(403).json({
        success: false,
        code: 'ACCOUNT_LOCKED',
        message: `Your supplier account is locked (${
          (profile && profile.lockReason) || req.user.lockReason || 'Overdue commission'
        }). Please settle your outstanding commission in the Wallet tab.`,
      });
    }

    const listing = await SupplierListing.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });
    if (!listing) {
      return res.status(404).json({
        success: false,
        message: 'Listing not found or unauthorized.',
      });
    }

    const {
      capacityLiters,
      label,
      waterPrice,
      deliveryFee,
      estimatedArrivalMinutesMin,
      estimatedArrivalMinutesMax,
      isAvailable,
      isActive,
      serviceNotes,
    } = req.body;

    if (capacityLiters !== undefined) listing.capacityLiters = Number(capacityLiters);
    if (label !== undefined) listing.label = label.trim();
    if (waterPrice !== undefined) listing.waterPrice = Number(waterPrice);
    if (deliveryFee !== undefined) listing.deliveryFee = Number(deliveryFee);
    listing.totalPrice = listing.waterPrice + listing.deliveryFee;

    if (estimatedArrivalMinutesMin !== undefined) {
      listing.estimatedArrivalMinutesMin = Number(estimatedArrivalMinutesMin);
    }
    if (estimatedArrivalMinutesMax !== undefined) {
      listing.estimatedArrivalMinutesMax = Number(estimatedArrivalMinutesMax);
    }
    if (isAvailable !== undefined) listing.isAvailable = Boolean(isAvailable);
    if (isActive !== undefined) listing.isActive = Boolean(isActive);
    if (serviceNotes !== undefined) listing.serviceNotes = serviceNotes;

    await listing.save();
    res.json({
      success: true,
      message: 'Listing updated.',
      data: listing,
    });
  } catch (err) {
    next(err);
  }
};

exports.deleteListing = async (req, res, next) => {
  try {
    const deleted = await SupplierListing.findOneAndDelete({
      _id: req.params.id,
      userId: req.user._id,
    });
    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Listing not found.',
      });
    }
    res.json({
      success: true,
      message: 'Listing deleted.',
    });
  } catch (err) {
    next(err);
  }
};

exports.discoverSuppliers = async (req, res, next) => {
  try {
    const { capacityLiters, lat, lng, sortBy } = req.query;
    const customerLat = lat !== undefined && lat !== '' ? parseFloat(lat) : null;
    const customerLng = lng !== undefined && lng !== '' ? parseFloat(lng) : null;
    const requestedCapacity =
      capacityLiters !== undefined && capacityLiters !== '' ? parseInt(capacityLiters, 10) : null;

    const suppliers = await SupplierProfile.find({
      isLocked: false,
      isAvailable: { $ne: false },
      approvalStatus: { $nin: ['pending_approval', 'rejected'] },
    }).sort({ createdAt: -1 });

    const ranked = rankCompanies({
      suppliers,
      customerLat,
      customerLng,
      requestedCapacity,
      sortBy: sortBy || 'best_match',
    });

    res.json({
      success: true,
      data: {
        suppliers: ranked,
        totalCount: ranked.length,
        emptyMessage:
          ranked.length === 0 ? 'No water suppliers available near you yet.' : null,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.getAiRecommendations = async (req, res, next) => {
  try {
    const customerLat = req.query.lat || (req.body && req.body.lat);
    const customerLng = req.query.lng || (req.body && req.body.lng);
    const capacityLiters = req.query.capacityLiters || (req.body && req.body.capacityLiters);
    const sortBy = req.query.sortBy || (req.body && req.body.sortBy) || 'best_match';

    const latNum = customerLat !== undefined && customerLat !== '' ? parseFloat(customerLat) : null;
    const lngNum = customerLng !== undefined && customerLng !== '' ? parseFloat(customerLng) : null;
    const requestedCap =
      capacityLiters !== undefined && capacityLiters !== '' ? parseInt(capacityLiters, 10) : 1000;

    const suppliers = await SupplierProfile.find({
      isLocked: false,
      isAvailable: { $ne: false },
      approvalStatus: { $nin: ['pending_approval', 'rejected'] },
    }).sort({ createdAt: -1 });

    const { suppliers: recSuppliers, isAiGenerated, aiModel } = await getSmartRecommendations({
      suppliers,
      customerLat: latNum,
      customerLng: lngNum,
      requestedCapacity: requestedCap,
      sortBy,
      useGroq: true,
    });

    res.json({
      success: true,
      isAiGenerated,
      aiModel,
      data: {
        suppliers: recSuppliers,
        totalCount: recSuppliers.length,
        emptyMessage:
          recSuppliers.length === 0 ? 'No water suppliers available near you for this capacity.' : null,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.getSupplierPublicProfile = async (req, res, next) => {
  try {
    const supplier = await SupplierProfile.findById(req.params.supplierId);
    if (!supplier) {
      return res.status(404).json({
        success: false,
        message: 'Supplier not found.',
      });
    }

    const { lat, lng } = req.query;
    let distanceKm = null;
    if (lat !== undefined && lng !== undefined) {
      distanceKm = haversineDistanceKm(
        parseFloat(lat),
        parseFloat(lng),
        supplier.lat,
        supplier.lng
      );
    }

    const reviews = await Review.find({ supplierId: supplier._id })
      .sort({ createdAt: -1 })
      .limit(25);

    const hasSufficientHistory = (supplier.completedDeliveriesCount || 0) >= 3;
    const onTimePercentage = hasSufficientHistory
      ? Math.round(((supplier.onTimeDeliveriesCount || 0) / supplier.completedDeliveriesCount) * 100)
      : null;

    res.json({
      success: true,
      data: {
        supplier: {
          ...supplier.toObject(),
          tankersOwned: supplier.tankersOwned || 1,
          availableWaterLiters:
            typeof supplier.availableWaterLiters === 'number'
              ? supplier.availableWaterLiters
              : 10000,
          pricePer1000Liters: supplier.pricePer1000Liters || 1800,
          deliveryFee: 250,
          companyLogo: supplier.companyLogo || null,
          serviceRadiusKm: supplier.serviceRadiusKm || 15,
          distanceKm,
          hasSufficientHistory,
          onTimePercentage,
          reliabilityText: hasSufficientHistory
            ? `${onTimePercentage}%`
            : 'Not enough delivery history',
        },
        listings: [],
        reviews,
      },
    });
  } catch (err) {
    next(err);
  }
};
