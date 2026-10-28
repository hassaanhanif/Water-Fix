const jwt = require('jsonwebtoken');
const env = require('../config/env');
const User = require('../models/User');
const Booking = require('../models/Booking');
const OrderTracking = require('../models/OrderTracking');
const trackingHub = require('../services/trackingHub');
const { haversineDistanceKm } = require('../utils/geo');

const ACTIVE_TRACKING_STATUSES = ['accepted', 'dispatched', 'arriving'];

function formatTrackingResponse(booking, trackingDoc) {
  const isPreAcceptance = booking.status === 'requested';
  const isOrderActiveForTracking = ACTIVE_TRACKING_STATUSES.includes(booking.status);

  const rawLat = trackingDoc?.latitude ?? booking.tracking?.latitude ?? null;
  const rawLng = trackingDoc?.longitude ?? booking.tracking?.longitude ?? null;
  const hasSupplierCoords =
    !isPreAcceptance &&
    typeof rawLat === 'number' &&
    !Number.isNaN(rawLat) &&
    typeof rawLng === 'number' &&
    !Number.isNaN(rawLng);

  const locationUpdatedAt = !isPreAcceptance
    ? trackingDoc?.locationUpdatedAt || booking.tracking?.updatedAt || null
    : null;

  const trackingActive = isOrderActiveForTracking
    ? Boolean(trackingDoc?.trackingActive ?? booking.tracking?.trackingActive ?? true)
    : false;

  return {
    orderId: booking._id.toString(),
    supplierId: booking.supplierId.toString(),
    supplierUserId: booking.supplierUserId.toString(),
    customerId: booking.customerId.toString(),
    latitude: hasSupplierCoords ? rawLat : null,
    longitude: hasSupplierCoords ? rawLng : null,
    heading: hasSupplierCoords ? (trackingDoc?.heading ?? booking.tracking?.heading ?? null) : null,
    speed: hasSupplierCoords ? (trackingDoc?.speed ?? booking.tracking?.speed ?? null) : null,
    accuracy: hasSupplierCoords
      ? (trackingDoc?.accuracy ?? booking.tracking?.accuracy ?? null)
      : null,
    updatedAt: locationUpdatedAt ? new Date(locationUpdatedAt).toISOString() : null,
    trackingActive,
    orderStatus: booking.status,
    deliveryAddress: {
      addressLine: booking.deliveryAddress?.addressLine || '',
      city: booking.deliveryAddress?.city || 'Islamabad',
      lat:
        typeof booking.deliveryAddress?.lat === 'number' &&
        !Number.isNaN(booking.deliveryAddress.lat)
          ? booking.deliveryAddress.lat
          : null,
      lng:
        typeof booking.deliveryAddress?.lng === 'number' &&
        !Number.isNaN(booking.deliveryAddress.lng)
          ? booking.deliveryAddress.lng
          : null,
      hasAccurateCoordinates: booking.deliveryAddress?.hasAccurateCoordinates !== false,
    },
    booking,
  };
}

exports.formatTrackingResponse = formatTrackingResponse;

exports.getOrderTracking = async (req, res, next) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Order not found.',
      });
    }

    const isCustomer = booking.customerId.toString() === req.user.id;
    const isSupplier = booking.supplierUserId.toString() === req.user.id;

    if (!isCustomer && !isSupplier && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Only the assigned customer or supplier can view this order tracking.',
      });
    }

    const trackingDoc = await OrderTracking.findOne({ orderId: booking._id });
    const payload = formatTrackingResponse(booking, trackingDoc);

    res.json({
      success: true,
      data: payload,
    });
  } catch (err) {
    next(err);
  }
};

exports.updateOrderTracking = async (req, res, next) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Order not found.',
      });
    }

    const isAssignedSupplier =
      req.user.role === 'supplier' && booking.supplierUserId.toString() === req.user.id;

    if (!isAssignedSupplier) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Only the assigned supplier for this order can publish GPS coordinates.',
      });
    }

    if (!ACTIVE_TRACKING_STATUSES.includes(booking.status)) {
      return res.status(400).json({
        success: false,
        message: `Cannot publish live GPS location when order status is '${booking.status}'. Order must be accepted or dispatched.`,
      });
    }

    const { latitude, longitude, heading, speed, accuracy } = req.body;
    const latNum = Number(latitude);
    const lngNum = Number(longitude);

    if (
      latitude === undefined ||
      longitude === undefined ||
      latitude === null ||
      longitude === null ||
      Number.isNaN(latNum) ||
      Number.isNaN(lngNum) ||
      !Number.isFinite(latNum) ||
      !Number.isFinite(lngNum) ||
      latNum < -90 ||
      latNum > 90 ||
      lngNum < -180 ||
      lngNum > 180
    ) {
      return res.status(400).json({
        success: false,
        message: 'Valid GPS latitude (-90 to 90) and longitude (-180 to 180) are required.',
      });
    }

    const now = new Date();
    const headingNum =
      heading !== undefined && heading !== null && Number.isFinite(Number(heading))
        ? Number(heading)
        : null;
    const speedNum =
      speed !== undefined && speed !== null && Number.isFinite(Number(speed))
        ? Number(speed)
        : null;
    const accuracyNum =
      accuracy !== undefined && accuracy !== null && Number.isFinite(Number(accuracy))
        ? Number(accuracy)
        : null;

    const trackingDoc = await OrderTracking.findOneAndUpdate(
      { orderId: booking._id },
      {
        $set: {
          orderId: booking._id,
          supplierId: booking.supplierId,
          supplierUserId: booking.supplierUserId,
          customerId: booking.customerId,
          latitude: latNum,
          longitude: lngNum,
          heading: headingNum,
          speed: speedNum,
          accuracy: accuracyNum,
          trackingActive: true,
          locationUpdatedAt: now,
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    booking.tracking = {
      latitude: latNum,
      longitude: lngNum,
      heading: headingNum,
      speed: speedNum,
      accuracy: accuracyNum,
      updatedAt: now,
      trackingActive: true,
    };

    // Dynamically update live distance if customer has delivery coordinates
    if (
      typeof booking.deliveryAddress?.lat === 'number' &&
      typeof booking.deliveryAddress?.lng === 'number'
    ) {
      const liveDist = haversineDistanceKm(
        latNum,
        lngNum,
        booking.deliveryAddress.lat,
        booking.deliveryAddress.lng
      );
      if (typeof liveDist === 'number' && !Number.isNaN(liveDist)) {
        booking.distanceKm = liveDist;
      }
    }

    await booking.save();

    const payload = formatTrackingResponse(booking, trackingDoc);
    trackingHub.broadcast(booking._id.toString(), payload);

    res.json({
      success: true,
      message: 'Supplier live GPS location updated.',
      data: payload,
    });
  } catch (err) {
    next(err);
  }
};

exports.stopOrderTracking = async (req, res, next) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Order not found.',
      });
    }

    const isAssignedSupplier =
      req.user.role === 'supplier' && booking.supplierUserId.toString() === req.user.id;

    if (!isAssignedSupplier && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Only the assigned supplier can stop tracking for this order.',
      });
    }

    const trackingDoc = await OrderTracking.findOneAndUpdate(
      { orderId: booking._id },
      {
        $set: {
          orderId: booking._id,
          supplierId: booking.supplierId,
          supplierUserId: booking.supplierUserId,
          customerId: booking.customerId,
          trackingActive: false,
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    if (booking.tracking) {
      booking.tracking.trackingActive = false;
      await booking.save();
    }

    const payload = formatTrackingResponse(booking, trackingDoc);
    trackingHub.broadcast(booking._id.toString(), payload);

    res.json({
      success: true,
      message: 'Live GPS tracking stopped for this order.',
      data: payload,
    });
  } catch (err) {
    next(err);
  }
};

exports.streamOrderTracking = async (req, res, next) => {
  try {
    // Support token via Authorization header or query string for SSE clients
    let token = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.split(' ')[1];
    } else if (req.query.token) {
      token = String(req.query.token);
    }

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required to subscribe to order tracking stream.',
      });
    }

    let decoded;
    try {
      decoded = jwt.verify(token, env.jwtAccessSecret);
    } catch (_) {
      return res.status(401).json({
        success: false,
        code: 'TOKEN_EXPIRED',
        message: 'Invalid or expired access token.',
      });
    }

    const user = await User.findById(decoded.userId);
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'User account not found or inactive.',
      });
    }

    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Order not found.',
      });
    }

    const userIdStr = user._id.toString();
    const isCustomer = booking.customerId.toString() === userIdStr;
    const isSupplier = booking.supplierUserId.toString() === userIdStr;

    if (!isCustomer && !isSupplier && user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You are not a participant of this order.',
      });
    }

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });

    const trackingDoc = await OrderTracking.findOne({ orderId: booking._id });
    const initialPayload = formatTrackingResponse(booking, trackingDoc);
    res.write(`data: ${JSON.stringify(initialPayload)}\n\n`);

    const unsubscribe = trackingHub.subscribe(booking._id.toString(), (updatePayload) => {
      try {
        res.write(`data: ${JSON.stringify(updatePayload)}\n\n`);
      } catch (_) {}
    });

    const keepAliveTimer = setInterval(() => {
      try {
        res.write(': keep-alive\n\n');
      } catch (_) {}
    }, 15000);

    req.on('close', () => {
      clearInterval(keepAliveTimer);
      unsubscribe();
    });
  } catch (err) {
    next(err);
  }
};
