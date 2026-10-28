const crypto = require('crypto');
const env = require('../config/env');
const Booking = require('../models/Booking');
const BookingStatusHistory = require('../models/BookingStatusHistory');
const SupplierProfile = require('../models/SupplierProfile');
const SupplierListing = require('../models/SupplierListing');
const CommissionLedger = require('../models/CommissionLedger');
const Notification = require('../models/Notification');
const OrderTracking = require('../models/OrderTracking');
const trackingHub = require('../services/trackingHub');
const { formatTrackingResponse } = require('./trackingController');
const { haversineDistanceKm } = require('../utils/geo');
const { rankCompanies, rankSupplierListings } = require('../services/recommendationService');

const ALLOWED_TRANSITIONS = {
  requested: ['accepted', 'rejected', 'cancelled', 'expired'],
  accepted: ['dispatched', 'delivered', 'cancelled'],
  dispatched: ['arriving', 'delivered', 'cancelled', 'failed'],
  arriving: ['delivered', 'failed'],
  delivered: [],
  rejected: [],
  cancelled: [],
  expired: [],
  failed: [],
};

function generateBookingCode() {
  const num = Math.floor(1000 + Math.random() * 9000);
  return `#WF-${num}`;
}

function generateDeliveryCode() {
  return String(Math.floor(1000 + Math.random() * 9000));
}

exports.createBooking = async (req, res, next) => {
  try {
    if (req.user && req.user.isLocked) {
      return res.status(403).json({
        success: false,
        code: 'ACCOUNT_LOCKED',
        message: `Your customer account is currently locked${
          req.user.lockReason ? ` (${req.user.lockReason})` : ''
        }. Please contact WaterFix Administration.`,
      });
    }

    if (req.user && req.user.approvalStatus && req.user.approvalStatus !== 'approved') {
      return res.status(403).json({
        success: false,
        code: 'ACCOUNT_NOT_APPROVED',
        message:
          req.user.approvalStatus === 'rejected'
            ? `Your customer account was rejected (${req.user.rejectionReason || 'Details could not be verified'}). Please contact WaterFix support.`
            : 'Your customer account is currently awaiting administrative CNIC approval. You can place orders once your account has been approved.',
      });
    }

    const {
      listingId,
      supplierId,
      capacityLiters,
      waterQuantityLiters,
      expectedTotalPrice,
      deliveryAddress,
      customerPhone,
      idempotencyKey,
      replacedFromBookingId,
    } = req.body;

    // 1. Idempotency check to prevent duplicate submissions
    if (idempotencyKey) {
      const existing = await Booking.findOne({
        customerId: req.user._id,
        idempotencyKey: String(idempotencyKey),
      });
      if (existing) {
        return res.status(200).json({
          success: true,
          idempotentReplay: true,
          message: 'Booking already created.',
          data: existing,
        });
      }
    }

    let listing = null;
    if (listingId) {
      listing = await SupplierListing.findById(listingId);
    }

    let supplier = null;
    if (supplierId) {
      supplier = await SupplierProfile.findById(supplierId);
    } else if (listing && listing.supplierId) {
      supplier = await SupplierProfile.findById(listing.supplierId);
    }

    if (!supplier) {
      return res.status(400).json({
        success: false,
        message: 'This water supplier is currently unavailable.',
      });
    }

    if (supplier.isLocked) {
      return res.status(403).json({
        success: false,
        code: 'SUPPLIER_LOCKED',
        message: 'This supplier account is currently locked and cannot accept new bookings.',
      });
    }
    if (supplier.approvalStatus && supplier.approvalStatus !== 'approved') {
      return res.status(400).json({
        success: false,
        message: 'This supplier has not been approved by administration yet.',
      });
    }
    if (!supplier.isAvailable) {
      return res.status(400).json({
        success: false,
        message: 'This supplier is currently unavailable.',
      });
    }

    const qty = Number(
      waterQuantityLiters || capacityLiters || (listing && listing.capacityLiters) || 1000
    );
    if (!Number.isInteger(qty) || qty < 500 || qty > 10000) {
      return res.status(400).json({
        success: false,
        message: 'Water quantity must be a positive whole number of at least 500 litres and at most 10,000 litres.',
      });
    }

    const availableStock =
      typeof supplier.availableWaterLiters === 'number'
        ? supplier.availableWaterLiters
        : 10000;
    if (availableStock < qty) {
      return res.status(400).json({
        success: false,
        message: `Requested quantity (${qty.toLocaleString()} L) exceeds supplier's available inventory (${availableStock.toLocaleString()} L).`,
      });
    }

    const ratePer1000 = supplier.pricePer1000Liters || 1800;
    const deliveryFee = listing && listing.deliveryFee !== undefined ? listing.deliveryFee : 250;
    let waterPrice;
    let calculatedTotalPrice;

    if (listing && !waterQuantityLiters && Number(capacityLiters) === Number(listing.capacityLiters)) {
      waterPrice = listing.waterPrice;
      calculatedTotalPrice = listing.totalPrice;
    } else {
      waterPrice = Math.round((ratePer1000 * qty) / 1000);
      calculatedTotalPrice = waterPrice + deliveryFee;
    }

    // Validate stale price
    if (
      expectedTotalPrice !== undefined &&
      Math.abs(Number(expectedTotalPrice) - calculatedTotalPrice) > 1
    ) {
      return res.status(409).json({
        success: false,
        code: 'STALE_PRICE',
        message: `The supplier updated their rate to Rs ${calculatedTotalPrice}. Please review and confirm the updated price.`,
        currentTotalPrice: calculatedTotalPrice,
      });
    }

    const addrLine =
      deliveryAddress && deliveryAddress.addressLine
        ? deliveryAddress.addressLine.trim()
        : 'Street 7, F-10/3, Islamabad';
    const addrCity = (deliveryAddress && deliveryAddress.city) || 'Islamabad';
    const hasCoords =
      deliveryAddress &&
      typeof deliveryAddress.lat === 'number' &&
      !Number.isNaN(deliveryAddress.lat) &&
      typeof deliveryAddress.lng === 'number' &&
      !Number.isNaN(deliveryAddress.lng);
    const addrLat = hasCoords ? deliveryAddress.lat : null;
    const addrLng = hasCoords ? deliveryAddress.lng : null;
    const hasAccurateCoordinates =
      hasCoords && deliveryAddress.hasAccurateCoordinates !== false;

    const distanceKm = hasCoords
      ? haversineDistanceKm(addrLat, addrLng, supplier.lat, supplier.lng) || 0.1
      : 3.2;

    if (hasCoords && distanceKm > (supplier.serviceRadiusKm || 20)) {
      return res.status(400).json({
        success: false,
        message: `Delivery location is ${distanceKm} km away, outside this supplier's ${supplier.serviceRadiusKm} km service radius.`,
      });
    }

    // Atomic inventory deduction / reservation
    const updatedSupplier = await SupplierProfile.findOneAndUpdate(
      { _id: supplier._id, availableWaterLiters: { $gte: qty } },
      { $inc: { availableWaterLiters: -qty } },
      { new: true }
    );
    if (!updatedSupplier) {
      return res.status(400).json({
        success: false,
        message: 'Insufficient water inventory remaining to fulfill this order.',
      });
    }

    let bookingCode = generateBookingCode();
    // Ensure uniqueness
    while (await Booking.findOne({ bookingCode })) {
      bookingCode = generateBookingCode();
    }

    const deliveryCode = generateDeliveryCode();

    const booking = await Booking.create({
      bookingCode,
      idempotencyKey: idempotencyKey ? String(idempotencyKey) : crypto.randomUUID(),
      customerId: req.user._id,
      supplierId: supplier._id,
      supplierUserId: supplier.userId,
      listingId: listing ? listing._id : null,
      capacityLiters: qty,
      waterQuantityLiters: qty,
      pricePer1000Liters: ratePer1000,
      waterPrice,
      deliveryFee,
      totalPrice: calculatedTotalPrice,
      inventoryRestored: false,
      deliveryAddress: {
        addressLine: addrLine,
        city: addrCity,
        lat: addrLat,
        lng: addrLng,
        hasAccurateCoordinates,
      },
      tracking: {
        latitude: null,
        longitude: null,
        heading: null,
        speed: null,
        accuracy: null,
        updatedAt: null,
        trackingActive: false,
      },
      customerName: req.user.name,
      customerPhone: customerPhone || req.user.phone,
      supplierBusinessName: supplier.businessName,
      supplierPhone: supplier.phone,
      driverName: supplier.driverName || supplier.ownerName,
      estimatedArrivalMinutesMin: (listing && listing.estimatedArrivalMinutesMin) || 35,
      estimatedArrivalMinutesMax: (listing && listing.estimatedArrivalMinutesMax) || 45,
      distanceKm,
      paymentMethod: 'cod',
      status: 'requested',
      deliveryCode,
      replacedFromBookingId: replacedFromBookingId || null,
      requestedAt: new Date(),
    });

    if (replacedFromBookingId) {
      await Booking.findByIdAndUpdate(replacedFromBookingId, {
        $set: { replacedByBookingId: booking._id },
      });
    }

    supplier.totalRequestsCount = (supplier.totalRequestsCount || 0) + 1;
    await supplier.save();

    await BookingStatusHistory.create({
      bookingId: booking._id,
      fromStatus: null,
      toStatus: 'requested',
      changedByUserId: req.user._id,
      changedByRole: req.user.role,
      note: 'Booking requested by customer (Cash on Delivery).',
    });

    // Notify customer & supplier
    await Notification.create([
      {
        userId: req.user._id,
        type: 'booking_requested',
        title: 'Booking confirmed',
        body: `${booking.bookingCode} · ${booking.capacityLiters.toLocaleString()} L · Rs ${booking.totalPrice.toLocaleString()}`,
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
      },
      {
        userId: supplier.userId,
        type: 'booking_requested',
        title: 'New tanker booking request',
        body: `${booking.bookingCode} · ${booking.capacityLiters.toLocaleString()} L to ${addrLine} · Rs ${booking.totalPrice.toLocaleString()}`,
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
      },
    ]);

    res.status(201).json({
      success: true,
      message: 'Booking created successfully.',
      data: booking,
    });
  } catch (err) {
    next(err);
  }
};

exports.getBookings = async (req, res, next) => {
  try {
    const query =
      req.user.role === 'supplier'
        ? { supplierUserId: req.user._id }
        : { customerId: req.user._id };

    if (req.query.status) {
      query.status = req.query.status;
    }

    const bookings = await Booking.find(query).sort({ createdAt: -1 });
    res.json({
      success: true,
      data: bookings,
    });
  } catch (err) {
    next(err);
  }
};

exports.getBookingById = async (req, res, next) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found.',
      });
    }

    const isCustomer = booking.customerId.toString() === req.user.id;
    const isSupplier = booking.supplierUserId.toString() === req.user.id;

    if (!isCustomer && !isSupplier && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to view this booking.',
      });
    }

    const history = await BookingStatusHistory.find({ bookingId: booking._id }).sort({
      createdAt: 1,
    });

    res.json({
      success: true,
      data: {
        booking,
        history,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.updateBookingStatus = async (req, res, next) => {
  try {
    const { status: nextStatus, reason, deliveryCode, driverName } = req.body;
    const booking = await Booking.findById(req.params.id);

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found.',
      });
    }

    const isCustomer = booking.customerId.toString() === req.user.id;
    const isSupplier = booking.supplierUserId.toString() === req.user.id;

    if (!isCustomer && !isSupplier && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized to modify this booking.',
      });
    }

    // Idempotent duplicate completion handling
    if (booking.status === 'delivered' && nextStatus === 'delivered') {
      return res.status(200).json({
        success: true,
        idempotentReplay: true,
        message: 'Booking is already marked as delivered.',
        data: booking,
      });
    }

    const allowed = ALLOWED_TRANSITIONS[booking.status] || [];
    if (!allowed.includes(nextStatus)) {
      return res.status(400).json({
        success: false,
        message: `Invalid booking transition from '${booking.status}' to '${nextStatus}'.`,
      });
    }

    // Role-specific authorization rules
    if (req.user.role === 'customer') {
      if (nextStatus !== 'cancelled') {
        return res.status(403).json({
          success: false,
          message: 'Customers can only cancel eligible bookings.',
        });
      }
      if (!['requested', 'accepted'].includes(booking.status)) {
        return res.status(400).json({
          success: false,
          message: 'Bookings cannot be cancelled by the customer after the tanker is dispatched.',
        });
      }
    }

    if (req.user.role === 'supplier') {
      if (!isSupplier) {
        return res.status(403).json({
          success: false,
          message: 'Only the assigned supplier can update this booking.',
        });
      }
      if (['accepted', 'dispatched'].includes(nextStatus)) {
        const supplierDoc = await SupplierProfile.findById(booking.supplierId);
        if (req.user.isLocked || (supplierDoc && supplierDoc.isLocked)) {
          const reasonText =
            (supplierDoc && supplierDoc.lockReason) ||
            req.user.lockReason ||
            'Overdue commission balance';
          return res.status(403).json({
            success: false,
            code: 'ACCOUNT_LOCKED',
            message: `Your supplier account is currently locked (${reasonText}). Please pay your outstanding commission in the Wallet tab to unlock your account.`,
          });
        }
      }
    }

    // Validate delivery verification code when completing delivery if provided
    if (nextStatus === 'delivered' && deliveryCode !== undefined && deliveryCode !== '') {
      if (String(deliveryCode).trim() !== String(booking.deliveryCode).trim()) {
        return res.status(400).json({
          success: false,
          message: 'Invalid 4-digit delivery verification code.',
        });
      }
    }

    const prevStatus = booking.status;
    booking.status = nextStatus;

    if (driverName) {
      booking.driverName = driverName.trim();
    }

    const now = new Date();
    if (nextStatus === 'accepted') {
      booking.acceptedAt = now;
    } else if (nextStatus === 'dispatched') {
      booking.dispatchedAt = now;
    } else if (nextStatus === 'arriving') {
      booking.arrivingAt = now;
    } else if (nextStatus === 'cancelled' || nextStatus === 'rejected') {
      booking.cancelledAt = now;
      booking.cancelledBy = req.user.role === 'supplier' ? 'supplier' : 'customer';
      booking.cancellationReason =
        reason ||
        (req.user.role === 'supplier'
          ? 'Their tanker became unavailable.'
          : 'Cancelled by customer.');

      // Atomic restoration of reserved water inventory (once only)
      if (!booking.inventoryRestored) {
        const claimedRestore = await Booking.findOneAndUpdate(
          { _id: booking._id, inventoryRestored: { $ne: true } },
          { $set: { inventoryRestored: true } }
        );
        if (claimedRestore) {
          const qtyToRestore = booking.waterQuantityLiters || booking.capacityLiters || 1000;
          await SupplierProfile.findByIdAndUpdate(booking.supplierId, {
            $inc: { availableWaterLiters: qtyToRestore },
          });
        }
      }
    } else if (nextStatus === 'delivered') {
      booking.deliveredAt = now;
    }

    // Handle supplier metrics and commission ledger on delivery completion
    if (nextStatus === 'delivered') {
      const supplier = await SupplierProfile.findById(booking.supplierId);
      if (supplier && !booking.commissionRecorded) {
        const commissionRate = env.commissionRate;
        const grossAmount = booking.totalPrice;
        const commissionAmount = Math.round(grossAmount * commissionRate);
        const supplierNetAmount = grossAmount - commissionAmount;

        // Atomically claim commission recording on this booking so concurrent updates cannot double-charge
        const claimedBooking = await Booking.findOneAndUpdate(
          { _id: booking._id, commissionRecorded: { $ne: true } },
          {
            $set: {
              commissionRecorded: true,
              commissionAmount,
            },
          },
          { new: true }
        );

        if (claimedBooking) {
          let createdNewLedger = false;
          try {
            const updatedSupplier = await SupplierProfile.findByIdAndUpdate(
              supplier._id,
              {
                $inc: {
                  completedDeliveriesCount: 1,
                  onTimeDeliveriesCount: 1,
                  totalGrossEarnings: grossAmount,
                  totalCommissionCharged: commissionAmount,
                  outstandingCommission: commissionAmount,
                },
              },
              { new: true }
            );

            await CommissionLedger.create({
              bookingId: booking._id,
              bookingCode: booking.bookingCode,
              orderDate: booking.createdAt || now,
              dueDate: booking.deliveredAt || now,
              currency: 'PKR',
              supplierId: supplier._id,
              supplierUserId: supplier.userId,
              type: 'commission_charge',
              grossBookingAmount: grossAmount,
              commissionRate,
              commissionAmount,
              paidAmount: 0,
              reversalAmount: 0,
              supplierNetAmount,
              status: 'accrued',
              outstandingBalanceAfter: updatedSupplier
                ? updatedSupplier.outstandingCommission
                : (supplier.outstandingCommission || 0) + commissionAmount,
              referenceNote: `Commission (${Math.round(commissionRate * 100)}%) on completed booking ${booking.bookingCode}`,
            });
            createdNewLedger = true;
          } catch (err) {
            if (err && err.code === 11000) {
              // Duplicate key on bookingId unique index; revert any duplicate increment
              await SupplierProfile.findByIdAndUpdate(supplier._id, {
                $inc: {
                  completedDeliveriesCount: -1,
                  onTimeDeliveriesCount: -1,
                  totalGrossEarnings: -grossAmount,
                  totalCommissionCharged: -commissionAmount,
                  outstandingCommission: -commissionAmount,
                },
              });
            } else {
              throw err;
            }
          }

          booking.commissionRecorded = true;
          booking.commissionAmount = commissionAmount;

          if (createdNewLedger) {
            await Notification.create({
              userId: supplier.userId,
              type: 'commission_recorded',
              title: 'Delivery completed & commission recorded',
              body: `${booking.bookingCode} completed (Rs ${grossAmount.toLocaleString()}). WaterFix commission: Rs ${commissionAmount.toLocaleString()}.`,
              bookingId: booking._id,
              bookingCode: booking.bookingCode,
            });
          }
        }
      }
    }

    // Handle supplier cancellation stats and alternative discovery notification
    if (
      (nextStatus === 'cancelled' || nextStatus === 'rejected') &&
      req.user.role === 'supplier'
    ) {
      const supplier = await SupplierProfile.findById(booking.supplierId);
      if (supplier) {
        supplier.cancelledDeliveriesCount = (supplier.cancelledDeliveriesCount || 0) + 1;
        await supplier.save();
      }

      // Count available alternatives for customer notification
      const otherSuppliers = await SupplierProfile.find({
        _id: { $ne: booking.supplierId },
        isLocked: false,
        isAvailable: { $ne: false },
        availableWaterLiters: { $gte: booking.capacityLiters || 1000 },
      });

      const rankedAlternatives = rankCompanies({
        suppliers: otherSuppliers,
        customerLat: booking.deliveryAddress.lat,
        customerLng: booking.deliveryAddress.lng,
        requestedCapacity: booking.capacityLiters,
      });

      await Notification.create({
        userId: booking.customerId,
        type: 'supplier_cancelled',
        title: `${booking.supplierBusinessName} cancelled`,
        body:
          rankedAlternatives.length > 0
            ? `AI found ${rankedAlternatives.length} replacement${rankedAlternatives.length === 1 ? '' : 's'} for your ${booking.capacityLiters.toLocaleString()} L booking.`
            : `Your ${booking.capacityLiters.toLocaleString()} L booking ${booking.bookingCode} was cancelled by the supplier.`,
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
      });
    } else if (nextStatus === 'accepted') {
      await Notification.create({
        userId: booking.customerId,
        type: 'booking_accepted',
        title: 'Supplier accepted your booking',
        body: `${booking.supplierBusinessName} confirmed ${booking.bookingCode} (${booking.capacityLiters.toLocaleString()} L).`,
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
      });
    } else if (nextStatus === 'dispatched' || nextStatus === 'arriving') {
      await Notification.create({
        userId: booking.customerId,
        type: 'delivery_dispatched',
        title: `Tanker is ${booking.estimatedArrivalMinutesMin} min away`,
        body: `${booking.supplierBusinessName} is on the way to ${booking.deliveryAddress.addressLine}.`,
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
      });
    } else if (nextStatus === 'delivered') {
      await Notification.create({
        userId: booking.customerId,
        type: 'review_reminder',
        title: 'Rate your last delivery',
        body: `How was ${booking.supplierBusinessName}?`,
        bookingId: booking._id,
        bookingCode: booking.bookingCode,
      });
    }

    await booking.save();

    // Synchronize real-time OrderTracking record on status transitions
    const isNowActiveTracking = ['accepted', 'dispatched', 'arriving'].includes(nextStatus);
    const trackingUpdate = {
      orderId: booking._id,
      supplierId: booking.supplierId,
      supplierUserId: booking.supplierUserId,
      customerId: booking.customerId,
      trackingActive: isNowActiveTracking,
    };

    if (
      isNowActiveTracking &&
      req.user.role === 'supplier' &&
      typeof req.body.latitude === 'number' &&
      typeof req.body.longitude === 'number' &&
      !Number.isNaN(req.body.latitude) &&
      !Number.isNaN(req.body.longitude) &&
      req.body.latitude >= -90 &&
      req.body.latitude <= 90 &&
      req.body.longitude >= -180 &&
      req.body.longitude <= 180
    ) {
      trackingUpdate.latitude = req.body.latitude;
      trackingUpdate.longitude = req.body.longitude;
      trackingUpdate.locationUpdatedAt = now;
      booking.tracking = {
        ...(booking.tracking ? booking.tracking.toObject?.() || booking.tracking : {}),
        latitude: req.body.latitude,
        longitude: req.body.longitude,
        updatedAt: now,
        trackingActive: true,
      };
      await booking.save();
    } else {
      booking.tracking = {
        latitude: booking.tracking?.latitude ?? null,
        longitude: booking.tracking?.longitude ?? null,
        heading: booking.tracking?.heading ?? null,
        speed: booking.tracking?.speed ?? null,
        accuracy: booking.tracking?.accuracy ?? null,
        updatedAt: booking.tracking?.updatedAt ?? null,
        trackingActive: isNowActiveTracking,
      };
      await booking.save();
    }

    const trackingDoc = await OrderTracking.findOneAndUpdate(
      { orderId: booking._id },
      { $set: trackingUpdate },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    const trackingPayload = formatTrackingResponse(booking, trackingDoc);
    trackingHub.broadcast(booking._id.toString(), trackingPayload);

    await BookingStatusHistory.create({
      bookingId: booking._id,
      fromStatus: prevStatus,
      toStatus: nextStatus,
      changedByUserId: req.user._id,
      changedByRole: req.user.role,
      note: booking.cancellationReason || `Status updated to ${nextStatus}`,
    });

    res.json({
      success: true,
      message: `Booking status updated to ${nextStatus}.`,
      data: booking,
    });
  } catch (err) {
    next(err);
  }
};

exports.getAlternativesForBooking = async (req, res, next) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found.',
      });
    }

    const otherSuppliers = await SupplierProfile.find({
      _id: { $ne: booking.supplierId },
      isLocked: false,
      isAvailable: { $ne: false },
      availableWaterLiters: { $gte: booking.capacityLiters || 1000 },
    });

    const alternatives = rankCompanies({
      suppliers: otherSuppliers,
      customerLat: booking.deliveryAddress.lat,
      customerLng: booking.deliveryAddress.lng,
      requestedCapacity: booking.capacityLiters,
      sortBy: 'best_match',
    }).map((alt, idx) => {
      const priceDiff = alt.totalPrice - booking.totalPrice;
      let priceComparisonText = 'Same price as your original booking';
      if (priceDiff < 0) {
        priceComparisonText = `Rs ${Math.abs(priceDiff)} cheaper than your original booking`;
      } else if (priceDiff > 0) {
        priceComparisonText = `Rs ${priceDiff} more than your original booking`;
      }
      return {
        ...alt,
        isBestReplacement: idx === 0,
        priceComparisonText,
      };
    });

    res.json({
      success: true,
      data: {
        originalBooking: booking,
        alternatives,
        totalAlternatives: alternatives.length,
      },
    });
  } catch (err) {
    next(err);
  }
};
