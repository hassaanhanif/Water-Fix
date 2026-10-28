const jwt = require('jsonwebtoken');
const env = require('../config/env');
const User = require('../models/User');

async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required. Please sign in.',
      });
    }

    const token = authHeader.split(' ')[1];
    let decoded;
    try {
      decoded = jwt.verify(token, env.jwtAccessSecret);
    } catch (err) {
      return res.status(401).json({
        success: false,
        code: 'TOKEN_EXPIRED',
        message: 'Your session has expired or is invalid. Please refresh or sign in again.',
      });
    }

    const user = await User.findById(decoded.userId);
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'User account not found or inactive.',
      });
    }

    if (user.emailVerified === false) {
      return res.status(403).json({
        success: false,
        code: 'EMAIL_NOT_VERIFIED',
        message: 'Please verify your email address to access this service.',
      });
    }

    // Role is always loaded from the database User document, never trusted from client request body
    req.user = {
      id: user._id.toString(),
      _id: user._id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      customerCategory: user.customerCategory,
      emailVerified: Boolean(user.emailVerified),
      approvalStatus: user.approvalStatus || 'approved',
      rejectionReason: user.rejectionReason || '',
      cnicNumber: user.cnicNumber || '',
      isLocked: Boolean(user.isLocked),
      lockReason: user.lockReason || '',
      lockedAt: user.lockedAt || null,
    };
    next();
  } catch (err) {
    next(err);
  }
}

function authorizeRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required.',
      });
    }
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. This operation requires role: ${allowedRoles.join(' or ')}.`,
      });
    }
    next();
  };
}

module.exports = { authenticate, authorizeRoles };
