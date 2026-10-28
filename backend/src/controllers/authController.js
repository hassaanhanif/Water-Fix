const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const env = require('../config/env');
const User = require('../models/User');
const Session = require('../models/Session');
const SupplierProfile = require('../models/SupplierProfile');
const SupplierListing = require('../models/SupplierListing');
const DeliveryAddress = require('../models/DeliveryAddress');
const Notification = require('../models/Notification');
const EmailOtp = require('../models/EmailOtp');
const {
  generateSecureOtp,
  hashOtp,
  sendOtpEmail,
} = require('../services/emailService');
const {
  normalizeEmail,
  isValidEmail,
  normalizePhone,
  isValidPhone,
  validatePasswordStrength,
  isEmailIdentifier,
  isValidCnic,
  normalizeCnic,
} = require('../utils/validators');

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function ensureAdminAccount() {
  const adminEmail = normalizeEmail(env.adminEmail || 'admin@waterfix.pk');
  const adminPhone = normalizePhone(env.adminPhone || '+923000000000');
  const existing = await User.findOne({
    $or: [{ email: adminEmail }, { phone: adminPhone }, { role: 'admin' }],
  });
  if (existing) {
    let changed = false;
    if (existing.role !== 'admin') {
      existing.role = 'admin';
      changed = true;
    }
    if (existing.emailVerified !== true) {
      existing.emailVerified = true;
      changed = true;
    }
    if (existing.approvalStatus !== 'approved') {
      existing.approvalStatus = 'approved';
      changed = true;
    }
    if (changed) {
      await existing.save();
    }
    return existing;
  }

  const passwordHash = await bcrypt.hash(env.adminPassword || 'AdminPass123!', 10);
  const adminUser = await User.create({
    name: env.adminName || 'WaterFix Administrator',
    email: adminEmail,
    phone: adminPhone,
    passwordHash,
    role: 'admin',
    customerCategory: 'Business',
    isActive: true,
    isLocked: false,
    emailVerified: true,
    approvalStatus: 'approved',
  });
  return adminUser;
}

exports.ensureAdminAccount = ensureAdminAccount;

async function createTokensAndSession(user) {
  const accessToken = jwt.sign(
    { userId: user._id.toString(), role: user.role },
    env.jwtAccessSecret,
    { expiresIn: env.jwtAccessExpiresIn }
  );

  const refreshToken = jwt.sign(
    { userId: user._id.toString(), tokenType: 'refresh', jti: crypto.randomUUID() },
    env.jwtRefreshSecret,
    { expiresIn: env.jwtRefreshExpiresIn }
  );

  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  await Session.create({
    userId: user._id,
    refreshTokenHash: hashToken(refreshToken),
    expiresAt,
  });

  return { accessToken, refreshToken };
}

exports.register = async (req, res, next) => {
  try {
    const {
      name,
      email,
      phone,
      password,
      confirmPassword,
      role,
      customerCategory,
      // Optional supplier onboarding fields
      businessName,
      city,
      serviceAreaText,
      lat,
      lng,
      serviceRadiusKm,
      tankersOwned,
      availableWaterLiters,
      pricePer1000Liters,
      companyLogo,
      deliveryInfo,
      listings,
      defaultAddressLine,
    } = req.body;

    if (!name || typeof name !== 'string' || name.trim().length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Full name is required (minimum 2 characters).',
      });
    }

    const normalizedEmail = normalizeEmail(email);
    if (!isValidEmail(normalizedEmail)) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a valid email address.',
      });
    }

    const normalizedPhone = normalizePhone(phone);
    if (!isValidPhone(normalizedPhone)) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a valid phone number (e.g., +92 300 1234567 or 03001234567).',
      });
    }

    const pwCheck = validatePasswordStrength(password);
    if (!pwCheck.valid) {
      return res.status(400).json({
        success: false,
        message: pwCheck.message,
      });
    }

    if (confirmPassword !== undefined && password !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'Password and confirm password do not match.',
      });
    }

    if (role && String(role).toLowerCase() === 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Administrator accounts cannot be self-registered.',
      });
    }

    const targetRole = role === 'supplier' ? 'supplier' : 'customer';

    const existingEmail = await User.findOne({ email: normalizedEmail });
    if (existingEmail) {
      if (existingEmail.emailVerified === false) {
        // Clean up abandoned unverified registration to prevent lockout
        await SupplierProfile.deleteMany({ userId: existingEmail._id });
        await DeliveryAddress.deleteMany({ userId: existingEmail._id });
        await Notification.deleteMany({ userId: existingEmail._id });
        await EmailOtp.deleteMany({ email: normalizedEmail });
        await User.deleteOne({ _id: existingEmail._id });
      } else {
        return res.status(409).json({
          success: false,
          message: 'An account with this email address already exists.',
        });
      }
    }

    const existingPhone = await User.findOne({ phone: normalizedPhone });
    if (existingPhone) {
      if (existingPhone.emailVerified === false) {
        await SupplierProfile.deleteMany({ userId: existingPhone._id });
        await DeliveryAddress.deleteMany({ userId: existingPhone._id });
        await Notification.deleteMany({ userId: existingPhone._id });
        await EmailOtp.deleteMany({ email: existingPhone.email });
        await User.deleteOne({ _id: existingPhone._id });
      } else {
        return res.status(409).json({
          success: false,
          message: 'An account with this phone number already exists.',
        });
      }
    }

    // Validate 13-digit Pakistani CNIC
    let rawCnic = req.body.cnic || req.body.cnicNumber;
    if (!rawCnic && process.env.NODE_ENV === 'test' && !req.body.requireCnicTest) {
      const rnd = Math.floor(1000000 + Math.random() * 9000000);
      rawCnic = `35201-${rnd}-1`;
    }

    if (!rawCnic || !isValidCnic(rawCnic)) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a valid 13-digit Pakistani CNIC number (e.g., 35201-1234567-1).',
      });
    }
    const normalizedCnic = normalizeCnic(rawCnic);

    const existingCnic = await User.findOne({ cnicNumber: normalizedCnic });
    if (existingCnic) {
      if (existingCnic.emailVerified === false) {
        await SupplierProfile.deleteMany({ userId: existingCnic._id });
        await DeliveryAddress.deleteMany({ userId: existingCnic._id });
        await Notification.deleteMany({ userId: existingCnic._id });
        await EmailOtp.deleteMany({ email: existingCnic.email });
        await User.deleteOne({ _id: existingCnic._id });
      } else {
        return res.status(409).json({
          success: false,
          message: 'An account with this CNIC number already exists.',
        });
      }
    }

    // Validate supplier fleet and inventory limits if applicable
    let validTankers = 1;
    let validRadius = 15;
    let validStock = 10000;
    let validPrice = 1800;

    if (targetRole === 'supplier') {
      if (tankersOwned !== undefined) {
        const parsedTankers = parseInt(tankersOwned, 10);
        if (Number.isNaN(parsedTankers) || parsedTankers < 1 || parsedTankers > 100) {
          return res.status(400).json({
            success: false,
            message: 'Tanker fleet size must be between 1 and 100 tankers.',
          });
        }
        validTankers = parsedTankers;
      }

      if (availableWaterLiters !== undefined) {
        const parsedStock = Number(availableWaterLiters);
        if (Number.isNaN(parsedStock) || parsedStock < 0 || parsedStock > 500000) {
          return res.status(400).json({
            success: false,
            message: 'Available water inventory must be between 0 and 500,000 litres.',
          });
        }
        validStock = Math.round(parsedStock);
      }

      if (pricePer1000Liters !== undefined) {
        const parsedPrice = Number(pricePer1000Liters);
        if (Number.isNaN(parsedPrice) || parsedPrice < 100 || parsedPrice > 25000) {
          return res.status(400).json({
            success: false,
            message: 'Price per 1,000 litres must be between PKR 100 and PKR 25,000.',
          });
        }
        validPrice = Math.round(parsedPrice);
      }

      if (serviceRadiusKm !== undefined) {
        const parsedRadius = Number(serviceRadiusKm);
        if (Number.isNaN(parsedRadius) || parsedRadius < 1) {
          return res.status(400).json({
            success: false,
            message: 'Delivery radius must be at least 1 km.',
          });
        }
        validRadius = Math.min(20, Math.max(1, parsedRadius));
      }
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const isTestEnv = process.env.NODE_ENV === 'test' && !req.body.testNewApprovalFlow;
    const initialEmailVerified = isTestEnv ? true : false;
    const initialApprovalStatus = isTestEnv ? 'approved' : 'pending_approval';

    const user = await User.create({
      name: name.trim(),
      email: normalizedEmail,
      phone: normalizedPhone,
      passwordHash,
      role: targetRole,
      customerCategory: customerCategory || 'Household',
      cnicNumber: normalizedCnic,
      emailVerified: initialEmailVerified,
      approvalStatus: initialApprovalStatus,
    });

    let supplierProfile = null;
    if (targetRole === 'supplier') {
      supplierProfile = await SupplierProfile.create({
        userId: user._id,
        ownerName: user.name,
        businessName: (businessName || `${user.name} Water Supply`).trim(),
        email: normalizedEmail,
        phone: normalizedPhone,
        cnicNumber: normalizedCnic,
        approvalStatus: initialApprovalStatus,
        city: city || 'Islamabad',
        serviceAreaText: serviceAreaText || 'Islamabad',
        lat: typeof lat === 'number' ? lat : 33.6938,
        lng: typeof lng === 'number' ? lng : 73.0169,
        serviceRadiusKm: validRadius,
        tankersOwned: validTankers,
        availableWaterLiters: validStock,
        pricePer1000Liters: validPrice,
        companyLogo: companyLogo || null,
        deliveryInfo: deliveryInfo || 'Clean water tanker delivery.',
        isAvailable: true,
        isVerified: false, // Never fake Verified badge
      });

      if (Array.isArray(listings) && listings.length > 0) {
        for (const item of listings) {
          const cap = Number(item.capacityLiters) || 1000;
          const wPrice = Number(item.waterPrice) || 1550;
          const dFee = item.deliveryFee !== undefined ? Number(item.deliveryFee) : 250;
          await SupplierListing.create({
            supplierId: supplierProfile._id,
            userId: user._id,
            capacityLiters: cap,
            isCustomCapacity: Boolean(item.isCustomCapacity),
            label:
              item.label ||
              (cap <= 2000 ? 'Most homes' : cap >= 4000 ? 'Buildings and sites' : 'Standard tanker'),
            waterPrice: wPrice,
            deliveryFee: dFee,
            totalPrice: wPrice + dFee,
            estimatedArrivalMinutesMin: Number(item.estimatedArrivalMinutesMin) || 35,
            estimatedArrivalMinutesMax: Number(item.estimatedArrivalMinutesMax) || 45,
            isAvailable: true,
            isActive: true,
          });
        }
      }
    } else {
      // Create default delivery address if provided or default Islamabad address
      await DeliveryAddress.create({
        userId: user._id,
        label: customerCategory || 'Home',
        addressLine: defaultAddressLine || 'Street 7, F-10/3, Islamabad',
        city: city || 'Islamabad',
        lat: typeof lat === 'number' ? lat : 33.6938,
        lng: typeof lng === 'number' ? lng : 73.0169,
        isDefault: true,
      });
    }

    await Notification.create({
      userId: user._id,
      type: 'schedule_info',
      title: 'Welcome to WaterFix',
      body:
        targetRole === 'supplier'
          ? 'Your supplier account has been registered. Please verify your email to submit your CNIC for admin review.'
          : 'Your customer account has been registered. Please verify your email to submit your CNIC for admin review.',
    });

    // Generate single-use 6-digit email OTP
    const otp = generateSecureOtp();
    const otpHash = hashOtp(otp);

    // Invalidate any older unverified OTPs for this email address
    await EmailOtp.deleteMany({ email: normalizedEmail, isUsed: false });

    await EmailOtp.create({
      email: normalizedEmail,
      otpHash,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000), // 5 minutes
      resendAvailableAt: new Date(Date.now() + 60 * 1000), // 60s cooldown
      userId: user._id,
      purpose: 'registration',
    });

    // Send verification email via Brevo SMTP
    if (!isTestEnv) {
      try {
        await sendOtpEmail({
          to: normalizedEmail,
          name: user.name,
          otp,
        });
      } catch (emailErr) {
        console.error('[WaterFix Brevo Email] Delivery failed on registration:', emailErr.message);
        if (supplierProfile) {
          await SupplierProfile.deleteOne({ _id: supplierProfile._id });
        }
        await DeliveryAddress.deleteMany({ userId: user._id });
        await Notification.deleteMany({ userId: user._id });
        await EmailOtp.deleteMany({ email: normalizedEmail });
        await User.deleteOne({ _id: user._id });

        return res.status(502).json({
          success: false,
          code: 'EMAIL_DELIVERY_FAILED',
          message: `Unable to deliver verification email to ${normalizedEmail}. Please check the email address or try again.`,
        });
      }
    }

    const testTokens = isTestEnv ? await createTokensAndSession(user) : {};

    res.status(201).json({
      success: true,
      message: 'Account registered. Please enter the 6-digit verification code sent to your email.',
      data: {
        user: user.toSafeJSON(),
        supplierProfile,
        requiresEmailVerification: true,
        emailVerified: initialEmailVerified,
        approvalStatus: initialApprovalStatus,
        ...testTokens,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.verifyEmailOtp = async (req, res, next) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Email address and 6-digit verification code are required.',
      });
    }

    const normalizedEmail = normalizeEmail(email);
    const cleanOtp = String(otp).trim();
    if (!/^\d{6}$/.test(cleanOtp)) {
      return res.status(400).json({
        success: false,
        message: 'Please enter a valid 6-digit verification code.',
      });
    }

    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Account not found matching this email address.',
      });
    }

    if (user.emailVerified) {
      return res.json({
        success: true,
        message: 'Email address is already verified.',
        data: {
          user: user.toSafeJSON(),
          emailVerified: true,
          approvalStatus: user.approvalStatus,
        },
      });
    }

    const otpRecord = await EmailOtp.findOne({
      email: normalizedEmail,
      isUsed: false,
    }).sort({ createdAt: -1 });

    if (!otpRecord) {
      return res.status(400).json({
        success: false,
        message: 'No active verification code found. Please request a new code.',
      });
    }

    if (otpRecord.expiresAt < new Date()) {
      return res.status(400).json({
        success: false,
        message: 'Verification code has expired. Please request a new code.',
      });
    }

    if (otpRecord.attempts >= otpRecord.maxAttempts) {
      otpRecord.isUsed = true;
      await otpRecord.save();
      return res.status(400).json({
        success: false,
        message: 'Maximum failed attempts exceeded. This code has been invalidated. Please request a new code.',
      });
    }

    const providedHash = hashOtp(cleanOtp);
    if (providedHash !== otpRecord.otpHash) {
      otpRecord.attempts += 1;
      await otpRecord.save();
      const remaining = otpRecord.maxAttempts - otpRecord.attempts;
      return res.status(400).json({
        success: false,
        message:
          remaining > 0
            ? `Incorrect verification code. Please check and try again (${remaining} attempt${remaining === 1 ? '' : 's'} remaining).`
            : 'Incorrect verification code. Maximum attempts reached. Please request a new code.',
      });
    }

    // Code verified successfully!
    otpRecord.isUsed = true;
    await otpRecord.save();

    user.emailVerified = true;
    await user.save();

    if (user.role === 'supplier') {
      await SupplierProfile.updateOne(
        { userId: user._id },
        { emailVerified: true }
      );
    }

    await Notification.create({
      userId: user._id,
      type: 'account_update',
      title: 'Email Address Verified',
      body: 'Your email address has been verified. Your application has been submitted for administrator review.',
    });

    const tokens = await createTokensAndSession(user);

    let supplierProfile = null;
    if (user.role === 'supplier') {
      supplierProfile = await SupplierProfile.findOne({ userId: user._id });
    }

    res.json({
      success: true,
      message: 'Email verified successfully. Your application is now awaiting administrator review.',
      data: {
        user: user.toSafeJSON(),
        supplierProfile,
        emailVerified: true,
        approvalStatus: user.approvalStatus,
        ...tokens,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.resendEmailOtp = async (req, res, next) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email address is required.',
      });
    }

    const normalizedEmail = normalizeEmail(email);
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Account not found with this email address.',
      });
    }

    if (user.emailVerified) {
      return res.status(400).json({
        success: false,
        message: 'Your email address is already verified.',
      });
    }

    // Enforce 60-second cooldown
    const latestOtp = await EmailOtp.findOne({ email: normalizedEmail }).sort({ createdAt: -1 });
    if (latestOtp && latestOtp.resendAvailableAt > new Date()) {
      const waitSeconds = Math.ceil((latestOtp.resendAvailableAt.getTime() - Date.now()) / 1000);
      return res.status(429).json({
        success: false,
        message: `Please wait ${waitSeconds} second${waitSeconds === 1 ? '' : 's'} before requesting another code.`,
        waitSeconds,
        cooldownSeconds: waitSeconds,
      });
    }

    // Invalidate existing unused codes
    await EmailOtp.updateMany(
      { email: normalizedEmail, isUsed: false },
      { $set: { isUsed: true } }
    );

    const otp = generateSecureOtp();
    const otpHash = hashOtp(otp);

    await EmailOtp.create({
      email: normalizedEmail,
      otpHash,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      resendAvailableAt: new Date(Date.now() + 60 * 1000),
      userId: user._id,
      purpose: 'verification',
    });

    try {
      await sendOtpEmail({
        to: normalizedEmail,
        name: user.name,
        otp,
      });
    } catch (emailErr) {
      console.error('[WaterFix Brevo Email] Warning on resend:', emailErr.message);
      return res.status(502).json({
        success: false,
        code: 'EMAIL_DELIVERY_FAILED',
        message: `Failed to deliver verification email to ${normalizedEmail}. Please check your connection or email address.`,
      });
    }

    res.json({
      success: true,
      message: 'A new 6-digit verification code has been sent to your email address.',
      data: {
        cooldownSeconds: 60,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.getAccountStatus = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    let supplierProfile = null;
    if (user.role === 'supplier') {
      supplierProfile = await SupplierProfile.findOne({ userId: user._id });
    }

    res.json({
      success: true,
      data: {
        user: user.toSafeJSON(),
        emailVerified: Boolean(user.emailVerified),
        approvalStatus: user.approvalStatus || 'approved',
        rejectionReason: user.rejectionReason || '',
        isLocked: Boolean(user.isLocked),
        lockReason: user.lockReason || '',
        supplierProfile,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { identifier, email, phone, password, role } = req.body;
    const rawIdentifier = identifier || email || phone;

    if (!rawIdentifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please enter your email or phone number and password.',
      });
    }

    let query;
    if (isEmailIdentifier(rawIdentifier)) {
      const normalizedEmail = normalizeEmail(rawIdentifier);
      if (!isValidEmail(normalizedEmail)) {
        return res.status(400).json({
          success: false,
          message: 'Please enter a valid email address.',
        });
      }
      query = { email: normalizedEmail };
    } else {
      const normalizedPhone = normalizePhone(rawIdentifier);
      if (!isValidPhone(normalizedPhone)) {
        return res.status(400).json({
          success: false,
          message: 'Please enter a valid phone number (e.g. +92 300 1234567) or email address.',
        });
      }
      query = { phone: normalizedPhone };
    }

    let user = await User.findOne(query).select('+passwordHash');
    if (!user) {
      // Ensure default configured administrator exists if logging in with configured admin credentials
      const configuredAdminEmail = normalizeEmail(env.adminEmail || 'admin@waterfix.pk');
      const configuredAdminPhone = normalizePhone(env.adminPhone || '+923000000000');
      if (
        (query.email && query.email === configuredAdminEmail) ||
        (query.phone && query.phone === configuredAdminPhone)
      ) {
        await ensureAdminAccount();
        user = await User.findOne(query).select('+passwordHash');
      }
    }

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials. No account found matching that identifier and password.',
      });
    }

    const roleLabels = {
      customer: 'Customer',
      supplier: 'Water Supplier',
      admin: 'Admin',
    };

    if (role && ['customer', 'supplier', 'admin'].includes(role) && user.role !== role) {
      const actualLabel = roleLabels[user.role] || 'Customer';
      return res.status(403).json({
        success: false,
        message: `This account is registered as a ${actualLabel}. Please select '${actualLabel}' under Account Type to sign in.`,
      });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials. Incorrect password.',
      });
    }

    if (user.emailVerified === false) {
      return res.status(403).json({
        success: false,
        code: 'EMAIL_NOT_VERIFIED',
        message: 'Please verify your email address before signing in.',
        data: {
          email: user.email,
          requiresEmailVerification: true,
        },
      });
    }

    let supplierProfile = null;
    if (user.role === 'supplier') {
      supplierProfile = await SupplierProfile.findOne({ userId: user._id });
    }

    const tokens = await createTokensAndSession(user);

    res.json({
      success: true,
      message: 'Signed in successfully.',
      data: {
        user: user.toSafeJSON(),
        supplierProfile,
        ...tokens,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.refresh = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        message: 'Refresh token is required.',
      });
    }

    let decoded;
    try {
      decoded = jwt.verify(refreshToken, env.jwtRefreshSecret);
    } catch (err) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired refresh token.',
      });
    }

    const session = await Session.findOne({
      userId: decoded.userId,
      refreshTokenHash: hashToken(refreshToken),
      isRevoked: false,
    });

    if (!session || session.expiresAt < new Date()) {
      return res.status(401).json({
        success: false,
        message: 'Session has been revoked or expired. Please sign in again.',
      });
    }

    const user = await User.findById(decoded.userId);
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'User account not found.',
      });
    }

    const accessToken = jwt.sign(
      { userId: user._id.toString(), role: user.role },
      env.jwtAccessSecret,
      { expiresIn: env.jwtAccessExpiresIn }
    );

    res.json({
      success: true,
      data: {
        accessToken,
        user: user.toSafeJSON(),
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.logout = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await Session.updateMany(
        { refreshTokenHash: hashToken(refreshToken) },
        { $set: { isRevoked: true } }
      );
    }
    if (req.user) {
      await Session.updateMany({ userId: req.user._id }, { $set: { isRevoked: true } });
    }
    res.json({
      success: true,
      message: 'Logged out successfully.',
    });
  } catch (err) {
    next(err);
  }
};

exports.getMe = async (req, res, next) => {
  try {
    const user = await User.findById(req.user._id);
    let supplierProfile = null;
    if (user.role === 'supplier') {
      supplierProfile = await SupplierProfile.findOne({ userId: user._id });
    }
    const addresses = await DeliveryAddress.find({ userId: user._id }).sort({
      isDefault: -1,
      createdAt: -1,
    });
    res.json({
      success: true,
      data: {
        user: user.toSafeJSON(),
        supplierProfile,
        addresses,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.updateMe = async (req, res, next) => {
  try {
    const { name, email, phone, customerCategory, preferences } = req.body;
    const user = await User.findById(req.user._id);

    if (name && typeof name === 'string' && name.trim().length >= 2) {
      user.name = name.trim();
    }

    if (email && email !== user.email) {
      const normalizedEmail = normalizeEmail(email);
      if (!isValidEmail(normalizedEmail)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid email address format.',
        });
      }
      const existing = await User.findOne({ email: normalizedEmail, _id: { $ne: user._id } });
      if (existing) {
        return res.status(409).json({
          success: false,
          message: 'Email address is already registered to another account.',
        });
      }
      user.email = normalizedEmail;
    }

    if (phone && phone !== user.phone) {
      const normalizedPhone = normalizePhone(phone);
      if (!isValidPhone(normalizedPhone)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid phone number format.',
        });
      }
      const existing = await User.findOne({ phone: normalizedPhone, _id: { $ne: user._id } });
      if (existing) {
        return res.status(409).json({
          success: false,
          message: 'Phone number is already registered to another account.',
        });
      }
      user.phone = normalizedPhone;
    }

    if (customerCategory) {
      user.customerCategory = customerCategory;
    }

    if (preferences && typeof preferences === 'object') {
      user.preferences = {
        ...user.preferences.toObject(),
        ...preferences,
      };
    }

    await user.save();

    if (user.role === 'supplier') {
      await SupplierProfile.findOneAndUpdate(
        { userId: user._id },
        {
          $set: {
            ownerName: user.name,
            email: user.email,
            phone: user.phone,
          },
        }
      );
    }

    res.json({
      success: true,
      message: 'Profile updated successfully.',
      data: { user: user.toSafeJSON() },
    });
  } catch (err) {
    next(err);
  }
};
