const mongoose = require('mongoose');
const env = require('../config/env');
const User = require('../models/User');
const SupplierProfile = require('../models/SupplierProfile');
const SupplierListing = require('../models/SupplierListing');
const Booking = require('../models/Booking');
const CommissionLedger = require('../models/CommissionLedger');
const CommissionPayment = require('../models/CommissionPayment');
const SupplierSettlement = require('../models/SupplierSettlement');
const DeliveryAddress = require('../models/DeliveryAddress');
const Notification = require('../models/Notification');
const AdminAuditLog = require('../models/AdminAuditLog');
const emailService = require('../services/emailService');
const { maskCnic } = require('../utils/validators');
const {
  formatPaymentStatus,
  calculateSupplierCommissionMetrics,
} = require('./walletController');

/**
 * Helper to build enriched supplier objects with real commission, overdue,
 * payment, and lock status metrics.
 */
async function buildEnrichedSuppliers(suppliers) {
  if (!suppliers || suppliers.length === 0) return [];

  const supplierIds = suppliers.map((s) => s._id);
  const userIds = suppliers.map((s) => s.userId);

  const [users, allCharges, allPayments, allSettlements] = await Promise.all([
    User.find({ _id: { $in: userIds } }),
    CommissionLedger.find({
      supplierId: { $in: supplierIds },
      type: 'commission_charge',
    }).sort({ createdAt: -1 }),
    CommissionPayment.find({ supplierId: { $in: supplierIds } }).sort({
      createdAt: -1,
    }),
    SupplierSettlement.find({ supplierId: { $in: supplierIds } }).sort({
      createdAt: -1,
    }),
  ]);

  const userMap = new Map(users.map((u) => [String(u._id), u]));
  const chargesBySupplier = new Map();
  const paymentsBySupplier = new Map();
  const settlementsBySupplier = new Map();

  for (const c of allCharges) {
    const key = String(c.supplierId);
    if (!chargesBySupplier.has(key)) chargesBySupplier.set(key, []);
    chargesBySupplier.get(key).push(c);
  }
  for (const p of allPayments) {
    const key = String(p.supplierId);
    if (!paymentsBySupplier.has(key)) paymentsBySupplier.set(key, []);
    paymentsBySupplier.get(key).push(p);
  }
  for (const s of allSettlements) {
    const key = String(s.supplierId);
    if (!settlementsBySupplier.has(key)) settlementsBySupplier.set(key, []);
    settlementsBySupplier.get(key).push(s);
  }

  const now = new Date();

  return suppliers.map((s) => {
    const key = String(s._id);
    const user = userMap.get(String(s.userId));
    const chargeItems = chargesBySupplier.get(key) || [];
    const payments = paymentsBySupplier.get(key) || [];
    const settlements = settlementsBySupplier.get(key) || [];

    const metrics = calculateSupplierCommissionMetrics({
      supplier: s,
      chargeItems,
      payments,
      settlements,
      now,
    });

    const isLocked = Boolean(s.isLocked || (user && user.isLocked));
    const lockReason = s.lockReason || (user && user.lockReason) || '';
    const lockedAt = s.lockedAt || (user && user.lockedAt) || null;
    const lockedByName = s.lockedByName || (user && user.lockedByName) || '';

    return {
      _id: s._id,
      supplierId: s._id,
      userId: s.userId,
      businessName: s.businessName,
      ownerName: s.ownerName || (user ? user.name : ''),
      email: s.email || (user ? user.email : ''),
      phone: s.phone || (user ? user.phone : ''),
      city: s.city || 'Islamabad',
      serviceAreaText: s.serviceAreaText || '',
      isVerified: Boolean(s.isVerified),
      cnicMasked: maskCnic(s.cnicNumber || (user ? user.cnicNumber : '') || ''),
      approvalStatus: s.approvalStatus || (user ? user.approvalStatus : 'approved'),
      isAvailable: Boolean(s.isAvailable && !isLocked),
      accountStatus: isLocked ? 'Locked' : 'Active',
      isLocked,
      lockReason,
      lockedAt,
      lockedByName,
      unlockedAt: s.unlockedAt || null,
      unlockedByName: s.unlockedByName || '',
      totalGrossEarnings: s.totalGrossEarnings || 0,
      totalCommissionCharged: metrics.totalCommissionCharged,
      outstandingCommission: metrics.totalCommissionOwed,
      totalCommissionPaid: metrics.totalCommissionPaid,
      pendingPaymentAmount: metrics.pendingPaymentAmount,
      paymentStatus: metrics.walletPaymentStatus,
      lastCommissionPaymentAt: metrics.lastCommissionPaymentAt,
      oldestOutstandingDueDate: metrics.oldestOutstandingDueDate,
      daysOverdue: metrics.daysOverdue,
      isOverdue: metrics.isOverdue,
      isOverdue7Days: metrics.isOverdue7Days,
      completedDeliveriesCount: s.completedDeliveriesCount || 0,
      cancelledDeliveriesCount: s.cancelledDeliveriesCount || 0,
      ratingAverage: s.ratingAverage || 0,
      reviewCount: s.reviewCount || 0,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    };
  });
}

/**
 * GET /api/admin/dashboard
 * Returns real summary metrics and recent activity for the Admin Dashboard.
 */
exports.getDashboardSummary = async (req, res, next) => {
  try {
    const [
      suppliers,
      totalCustomers,
      lockedCustomersCount,
      recentPaymentsRaw,
      recentSettlementsRaw,
      recentAuditLogs,
      pendingSuppliersCount,
      pendingCustomersCount,
    ] = await Promise.all([
      SupplierProfile.find({ approvalStatus: { $ne: 'pending_approval' } }).sort({ createdAt: -1 }),
      User.countDocuments({ role: 'customer', approvalStatus: { $ne: 'pending_approval' } }),
      User.countDocuments({ role: 'customer', isLocked: true }),
      CommissionPayment.find({}).sort({ createdAt: -1 }).limit(30),
      SupplierSettlement.find({}).sort({ createdAt: -1 }).limit(20),
      AdminAuditLog.find({}).sort({ createdAt: -1 }).limit(15),
      SupplierProfile.countDocuments({ approvalStatus: 'pending_approval' }),
      User.countDocuments({ role: 'customer', approvalStatus: 'pending_approval' }),
    ]);

    const enrichedSuppliers = await buildEnrichedSuppliers(suppliers);
    const supplierMap = new Map(
      enrichedSuppliers.map((s) => [String(s._id), s])
    );

    const totalSuppliers = enrichedSuppliers.length;
    const totalOutstandingCommissions = enrichedSuppliers.reduce(
      (sum, s) => sum + (s.outstandingCommission || 0),
      0
    );
    const totalVerifiedPayments = enrichedSuppliers.reduce(
      (sum, s) => sum + (s.totalCommissionPaid || 0),
      0
    );
    const totalCommissionGenerated = enrichedSuppliers.reduce(
      (sum, s) => sum + (s.totalCommissionCharged || 0),
      0
    );
    const overdueSuppliersCount = enrichedSuppliers.filter(
      (s) => s.isOverdue7Days
    ).length;
    const suppliersWithOutstandingCount = enrichedSuppliers.filter(
      (s) => (s.outstandingCommission || 0) > 0
    ).length;
    const lockedSuppliersCount = enrichedSuppliers.filter(
      (s) => s.isLocked
    ).length;

    const [pendingPaymentsCount, failedPaymentsCount] = await Promise.all([
      CommissionPayment.countDocuments({ status: 'pending' }),
      CommissionPayment.countDocuments({
        status: { $in: ['failed', 'cancelled', 'expired'] },
      }),
    ]);

    const formattedSafepay = recentPaymentsRaw.map((p) => {
      const sup = supplierMap.get(String(p.supplierId));
      return {
        _id: p._id,
        recordType: 'safepay_payment',
        paymentReference: p.paymentReference,
        supplierId: p.supplierId,
        supplierName: sup ? sup.businessName : 'Supplier',
        supplierOwnerName: sup ? sup.ownerName : '',
        amount: p.amount,
        currency: p.currency || 'PKR',
        provider: p.provider || 'Safepay',
        environment: p.environment || 'sandbox',
        tracker: p.tracker || null,
        providerReference: p.providerReference || p.tracker || null,
        status: formatPaymentStatus(p.status),
        rawStatus: p.status,
        createdAt: p.createdAt,
        verifiedAt: p.verifiedAt,
        failureReason: p.failureReason || null,
      };
    });

    const formattedManual = recentSettlementsRaw.map((s) => {
      const sup = supplierMap.get(String(s.supplierId));
      return {
        _id: s._id,
        recordType: 'manual_settlement',
        paymentReference: s.settlementReference,
        supplierId: s.supplierId,
        supplierName: sup ? sup.businessName : 'Supplier',
        supplierOwnerName: sup ? sup.ownerName : '',
        amount: s.amountSettled,
        currency: 'PKR',
        provider: 'Manual Admin Settlement',
        environment: 'internal',
        tracker: s.settlementReference,
        providerReference: s.settlementReference,
        status: 'Paid',
        rawStatus: 'paid',
        createdAt: s.createdAt,
        verifiedAt: s.createdAt,
        failureReason: null,
      };
    });

    const recentPayments = [...formattedSafepay, ...formattedManual]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 15);

    const overdueSuppliers = enrichedSuppliers
      .filter((s) => s.outstandingCommission > 0)
      .sort((a, b) => b.daysOverdue - a.daysOverdue)
      .slice(0, 10);

    res.json({
      success: true,
      data: {
        summary: {
          totalSuppliers,
          totalCustomers,
          totalOutstandingCommissions,
          totalVerifiedPayments,
          totalCommissionGenerated,
          overdueSuppliersCount,
          suppliersWithOutstandingCount,
          lockedSuppliersCount,
          lockedCustomersCount,
          pendingSuppliersCount,
          pendingCustomersCount,
          pendingPaymentsCount,
          failedPaymentsCount,
          commissionRate: env.commissionRate,
          commissionPercentage: Math.round(env.commissionRate * 100),
        },
        recentPayments,
        overdueSuppliers,
        recentAuditLogs,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/suppliers
 * Supports `?search=` and `?filter=all|active|locked|outstanding|overdue_7_days`.
 */
exports.getSuppliers = async (req, res, next) => {
  try {
    const search = (req.query.search || '').trim().toLowerCase();
    const filter = (req.query.filter || 'all').trim().toLowerCase();

    const suppliers = await SupplierProfile.find({
      approvalStatus: { $ne: 'pending_approval' },
    }).sort({
      outstandingCommission: -1,
      createdAt: -1,
    });

    let enriched = await buildEnrichedSuppliers(suppliers);

    if (search) {
      enriched = enriched.filter((s) => {
        const idStr = String(s._id).toLowerCase();
        const bName = (s.businessName || '').toLowerCase();
        const oName = (s.ownerName || '').toLowerCase();
        const email = (s.email || '').toLowerCase();
        const phone = (s.phone || '').toLowerCase();
        const city = (s.city || '').toLowerCase();
        return (
          idStr.includes(search) ||
          bName.includes(search) ||
          oName.includes(search) ||
          email.includes(search) ||
          phone.includes(search) ||
          city.includes(search)
        );
      });
    }

    if (filter === 'active') {
      enriched = enriched.filter((s) => !s.isLocked);
    } else if (filter === 'locked') {
      enriched = enriched.filter((s) => s.isLocked);
    } else if (filter === 'outstanding') {
      enriched = enriched.filter((s) => (s.outstandingCommission || 0) > 0);
    } else if (
      filter === 'overdue_7_days' ||
      filter === 'overdue' ||
      filter === 'overdue7'
    ) {
      enriched = enriched.filter((s) => s.isOverdue7Days);
    }

    res.json({
      success: true,
      data: {
        suppliers: enriched,
        totalCount: enriched.length,
        filter,
        search,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/suppliers/:id
 * Detailed supplier inspection view including profile, commission ledger,
 * payment history, overdue breakdown, listings, and audit trail.
 */
exports.getSupplierDetail = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid supplier ID format.',
      });
    }

    let supplier = await SupplierProfile.findById(id);
    if (!supplier) {
      supplier = await SupplierProfile.findOne({ userId: id });
    }
    if (!supplier) {
      return res.status(404).json({
        success: false,
        message: 'Supplier not found.',
      });
    }

    const [
      enrichedList,
      ledger,
      payments,
      settlements,
      listings,
      bookings,
      auditLogs,
    ] = await Promise.all([
      buildEnrichedSuppliers([supplier]),
      CommissionLedger.find({ supplierId: supplier._id })
        .sort({ createdAt: -1 })
        .limit(100),
      CommissionPayment.find({ supplierId: supplier._id })
        .sort({ createdAt: -1 })
        .limit(100),
      SupplierSettlement.find({ supplierId: supplier._id })
        .sort({ createdAt: -1 })
        .limit(50),
      SupplierListing.find({ supplierId: supplier._id }).sort({
        capacityLiters: 1,
      }),
      Booking.find({ supplierId: supplier._id })
        .sort({ createdAt: -1 })
        .limit(30),
      AdminAuditLog.find({
        targetType: 'supplier',
        targetId: supplier._id,
      })
        .sort({ createdAt: -1 })
        .limit(30),
    ]);

    const enrichedSupplier = enrichedList[0];
    const chargeItems = ledger.filter((item) => item.type === 'commission_charge');
    const metrics = calculateSupplierCommissionMetrics({
      supplier,
      chargeItems,
      payments,
      settlements,
    });

    const safepayPaymentsFormatted = payments.map((p) => ({
      _id: p._id,
      recordType: 'safepay_payment',
      paymentReference: p.paymentReference,
      amount: p.amount,
      currency: p.currency || 'PKR',
      createdAt: p.createdAt,
      verifiedAt: p.verifiedAt,
      provider: p.provider || 'Safepay',
      environment: p.environment || 'sandbox',
      status: formatPaymentStatus(p.status),
      rawStatus: p.status,
      tracker: p.tracker || null,
      providerReference: p.providerReference || p.tracker || null,
      allocations: p.allocations || [],
      failureReason: p.failureReason || null,
      notes: p.notes || '',
    }));

    const manualSettlementsFormatted = settlements.map((s) => ({
      _id: s._id,
      recordType: 'manual_settlement',
      paymentReference: s.settlementReference,
      amount: s.amountSettled,
      currency: 'PKR',
      createdAt: s.createdAt,
      verifiedAt: s.createdAt,
      provider: 'Manual Admin Settlement',
      environment: 'internal',
      status: 'Paid',
      rawStatus: 'paid',
      tracker: s.settlementReference,
      providerReference: s.settlementReference,
      allocations: [],
      failureReason: null,
      notes: s.notes || s.method || '',
    }));

    const paymentHistory = [
      ...safepayPaymentsFormatted,
      ...manualSettlementsFormatted,
    ].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json({
      success: true,
      data: {
        supplier: enrichedSupplier,
        commissionHistory: metrics.formattedCommissionItems,
        paymentHistory,
        listings,
        bookings,
        auditLogs,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * PATCH / POST /api/admin/suppliers/:id/lock
 * Locks or unlocks a supplier account with audit logging and idempotent handling.
 */
exports.updateSupplierLockStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { locked, reason } = req.body || {};

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid supplier ID format.',
      });
    }

    if (typeof locked !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'Field `locked` (boolean true or false) is required.',
      });
    }

    let supplier = await SupplierProfile.findById(id);
    if (!supplier) {
      supplier = await SupplierProfile.findOne({ userId: id });
    }
    if (!supplier) {
      return res.status(404).json({
        success: false,
        message: 'Supplier not found.',
      });
    }

    const user = await User.findById(supplier.userId);
    const currentlyLocked = Boolean(
      supplier.isLocked || (user && user.isLocked)
    );

    const trimmedReason =
      typeof reason === 'string' && reason.trim().length > 0
        ? reason.trim()
        : locked
          ? 'Overdue supplier commission (7+ days unpaid)'
          : 'Account unlocked by administrator after commission review';

    // Idempotent handling if already in the requested state
    if (currentlyLocked === locked) {
      const [enriched] = await buildEnrichedSuppliers([supplier]);
      return res.status(200).json({
        success: true,
        alreadyInState: true,
        message: `Supplier account is already ${locked ? 'Locked' : 'Active'}.`,
        data: {
          supplier: enriched,
        },
      });
    }

    const now = new Date();
    if (locked) {
      supplier.isLocked = true;
      supplier.lockReason = trimmedReason;
      supplier.lockedAt = now;
      supplier.lockedBy = req.user._id;
      supplier.lockedByName = req.user.name;
      supplier.isAvailable = false;
    } else {
      supplier.isLocked = false;
      supplier.lockReason = '';
      supplier.unlockedAt = now;
      supplier.unlockedBy = req.user._id;
      supplier.unlockedByName = req.user.name;
      supplier.isAvailable = true;
    }
    await supplier.save();

    if (user) {
      if (locked) {
        user.isLocked = true;
        user.lockReason = trimmedReason;
        user.lockedAt = now;
        user.lockedBy = req.user._id;
        user.lockedByName = req.user.name;
      } else {
        user.isLocked = false;
        user.lockReason = '';
        user.unlockedAt = now;
        user.unlockedBy = req.user._id;
        user.unlockedByName = req.user.name;
      }
      await user.save();
    }

    const [enriched] = await buildEnrichedSuppliers([supplier]);

    const auditLog = await AdminAuditLog.create({
      adminId: req.user._id,
      adminName: req.user.name,
      adminEmail: req.user.email,
      targetType: 'supplier',
      targetId: supplier._id,
      targetUserId: supplier.userId,
      targetName: supplier.businessName,
      action: locked ? 'lock_supplier' : 'unlock_supplier',
      reason: trimmedReason,
      previousState: currentlyLocked ? 'Locked' : 'Active',
      newState: locked ? 'Locked' : 'Active',
      metadata: {
        outstandingCommission: enriched.outstandingCommission,
        daysOverdue: enriched.daysOverdue,
      },
    });

    await Notification.create({
      userId: supplier.userId,
      type: locked ? 'account_locked' : 'account_unlocked',
      title: locked
        ? 'Supplier Account Locked by Admin'
        : 'Supplier Account Unlocked',
      body: locked
        ? `Your supplier account (${supplier.businessName}) has been locked. Reason: ${trimmedReason}. You can still open your Commission Wallet to pay any outstanding balance.`
        : `Your supplier account (${supplier.businessName}) has been unlocked by WaterFix Administration (${trimmedReason}). You can now accept customer bookings again.`,
    });

    res.json({
      success: true,
      alreadyInState: false,
      message: locked
        ? `Supplier "${supplier.businessName}" has been locked.`
        : `Supplier "${supplier.businessName}" has been unlocked.`,
      data: {
        supplier: enriched,
        auditLog,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/customers
 * Lists real customer accounts with order counts, registration dates, and lock status.
 */
exports.getCustomers = async (req, res, next) => {
  try {
    const search = (req.query.search || '').trim().toLowerCase();
    const filter = (req.query.filter || 'all').trim().toLowerCase();

    const customers = await User.find({
      role: 'customer',
      approvalStatus: { $ne: 'pending_approval' },
    }).sort({
      createdAt: -1,
    });

    const customerIds = customers.map((c) => c._id);
    const bookings = await Booking.find({
      customerId: { $in: customerIds },
    }).sort({ createdAt: -1 });

    const statsByCustomer = new Map();
    for (const b of bookings) {
      const key = String(b.customerId);
      if (!statsByCustomer.has(key)) {
        statsByCustomer.set(key, {
          orderCount: 0,
          completedOrderCount: 0,
          cancelledOrderCount: 0,
          totalSpent: 0,
          lastOrderAt: null,
        });
      }
      const st = statsByCustomer.get(key);
      st.orderCount += 1;
      if (b.status === 'delivered') {
        st.completedOrderCount += 1;
        st.totalSpent += b.totalPrice || 0;
      } else if (['cancelled', 'rejected'].includes(b.status)) {
        st.cancelledOrderCount += 1;
      }
      if (!st.lastOrderAt || new Date(b.createdAt) > new Date(st.lastOrderAt)) {
        st.lastOrderAt = b.createdAt;
      }
    }

    let enriched = customers.map((c) => {
      const stats = statsByCustomer.get(String(c._id)) || {
        orderCount: 0,
        completedOrderCount: 0,
        cancelledOrderCount: 0,
        totalSpent: 0,
        lastOrderAt: null,
      };
      const isLocked = Boolean(c.isLocked);
      return {
        _id: c._id,
        customerId: c._id,
        name: c.name,
        email: c.email,
        phone: c.phone,
        customerCategory: c.customerCategory || 'Household',
        cnicMasked: maskCnic(c.cnicNumber || ''),
        approvalStatus: c.approvalStatus || 'approved',
        accountStatus: isLocked ? 'Locked' : 'Active',
        isLocked,
        lockReason: c.lockReason || '',
        lockedAt: c.lockedAt || null,
        lockedByName: c.lockedByName || '',
        unlockedAt: c.unlockedAt || null,
        unlockedByName: c.unlockedByName || '',
        createdAt: c.createdAt,
        orderCount: stats.orderCount,
        completedOrderCount: stats.completedOrderCount,
        cancelledOrderCount: stats.cancelledOrderCount,
        totalSpent: stats.totalSpent,
        lastOrderAt: stats.lastOrderAt,
      };
    });

    if (search) {
      enriched = enriched.filter((c) => {
        const idStr = String(c._id).toLowerCase();
        const name = (c.name || '').toLowerCase();
        const email = (c.email || '').toLowerCase();
        const phone = (c.phone || '').toLowerCase();
        return (
          idStr.includes(search) ||
          name.includes(search) ||
          email.includes(search) ||
          phone.includes(search)
        );
      });
    }

    if (filter === 'active') {
      enriched = enriched.filter((c) => !c.isLocked);
    } else if (filter === 'locked') {
      enriched = enriched.filter((c) => c.isLocked);
    }

    res.json({
      success: true,
      data: {
        customers: enriched,
        totalCount: enriched.length,
        filter,
        search,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/customers/:id
 * Detailed customer inspection view with profile, addresses, order history, and audit logs.
 */
exports.getCustomerDetail = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid customer ID format.',
      });
    }

    const customer = await User.findOne({ _id: id, role: 'customer' });
    if (!customer) {
      return res.status(404).json({
        success: false,
        message: 'Customer not found.',
      });
    }

    const [addresses, bookings, auditLogs] = await Promise.all([
      DeliveryAddress.find({ userId: customer._id }).sort({
        isDefault: -1,
        createdAt: -1,
      }),
      Booking.find({ customerId: customer._id })
        .sort({ createdAt: -1 })
        .limit(50),
      AdminAuditLog.find({
        targetType: 'customer',
        targetId: customer._id,
      })
        .sort({ createdAt: -1 })
        .limit(30),
    ]);

    const completedOrderCount = bookings.filter(
      (b) => b.status === 'delivered'
    ).length;
    const totalSpent = bookings
      .filter((b) => b.status === 'delivered')
      .reduce((sum, b) => sum + (b.totalPrice || 0), 0);

    const isLocked = Boolean(customer.isLocked);

    res.json({
      success: true,
      data: {
        customer: {
          _id: customer._id,
          customerId: customer._id,
          name: customer.name,
          email: customer.email,
          phone: customer.phone,
          customerCategory: customer.customerCategory || 'Household',
          accountStatus: isLocked ? 'Locked' : 'Active',
          isLocked,
          lockReason: customer.lockReason || '',
          lockedAt: customer.lockedAt || null,
          lockedByName: customer.lockedByName || '',
          unlockedAt: customer.unlockedAt || null,
          unlockedByName: customer.unlockedByName || '',
          createdAt: customer.createdAt,
          orderCount: bookings.length,
          completedOrderCount,
          totalSpent,
        },
        addresses,
        bookings,
        auditLogs,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * PATCH / POST /api/admin/customers/:id/lock
 * Locks or unlocks a customer account with audit trail and notification.
 */
exports.updateCustomerLockStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { locked, reason } = req.body || {};

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid customer ID format.',
      });
    }

    if (typeof locked !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'Field `locked` (boolean true or false) is required.',
      });
    }

    const customer = await User.findOne({ _id: id, role: 'customer' });
    if (!customer) {
      return res.status(404).json({
        success: false,
        message: 'Customer not found.',
      });
    }

    const currentlyLocked = Boolean(customer.isLocked);
    const trimmedReason =
      typeof reason === 'string' && reason.trim().length > 0
        ? reason.trim()
        : locked
          ? 'Locked by WaterFix Administrator'
          : 'Account unlocked by WaterFix Administrator';

    if (currentlyLocked === locked) {
      return res.status(200).json({
        success: true,
        alreadyInState: true,
        message: `Customer account is already ${locked ? 'Locked' : 'Active'}.`,
        data: {
          customer: {
            ...customer.toSafeJSON(),
            accountStatus: locked ? 'Locked' : 'Active',
          },
        },
      });
    }

    const now = new Date();
    if (locked) {
      customer.isLocked = true;
      customer.lockReason = trimmedReason;
      customer.lockedAt = now;
      customer.lockedBy = req.user._id;
      customer.lockedByName = req.user.name;
    } else {
      customer.isLocked = false;
      customer.lockReason = '';
      customer.unlockedAt = now;
      customer.unlockedBy = req.user._id;
      customer.unlockedByName = req.user.name;
    }
    await customer.save();

    const auditLog = await AdminAuditLog.create({
      adminId: req.user._id,
      adminName: req.user.name,
      adminEmail: req.user.email,
      targetType: 'customer',
      targetId: customer._id,
      targetUserId: customer._id,
      targetName: customer.name,
      action: locked ? 'lock_customer' : 'unlock_customer',
      reason: trimmedReason,
      previousState: currentlyLocked ? 'Locked' : 'Active',
      newState: locked ? 'Locked' : 'Active',
    });

    await Notification.create({
      userId: customer._id,
      type: locked ? 'account_locked' : 'account_unlocked',
      title: locked
        ? 'Customer Account Locked by Admin'
        : 'Customer Account Unlocked',
      body: locked
        ? `Your WaterFix customer account has been locked. Reason: ${trimmedReason}.`
        : `Your WaterFix customer account has been unlocked (${trimmedReason}). You can place water tanker bookings again.`,
    });

    res.json({
      success: true,
      alreadyInState: false,
      message: locked
        ? `Customer "${customer.name}" has been locked.`
        : `Customer "${customer.name}" has been unlocked.`,
      data: {
        customer: {
          ...customer.toSafeJSON(),
          accountStatus: locked ? 'Locked' : 'Active',
        },
        auditLog,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/payments
 * Supports `?filter=all|pending|paid|failed|outstanding_commissions` and `?search=`.
 */
exports.getPayments = async (req, res, next) => {
  try {
    const filter = (req.query.filter || 'all').trim().toLowerCase();
    const search = (req.query.search || '').trim().toLowerCase();

    const [suppliers, payments, settlements, charges] = await Promise.all([
      SupplierProfile.find({}),
      CommissionPayment.find({}).sort({ createdAt: -1 }).limit(200),
      SupplierSettlement.find({}).sort({ createdAt: -1 }).limit(100),
      CommissionLedger.find({ type: 'commission_charge' })
        .sort({ createdAt: -1 })
        .limit(300),
    ]);

    const enrichedSuppliers = await buildEnrichedSuppliers(suppliers);
    const supplierMap = new Map(
      enrichedSuppliers.map((s) => [String(s._id), s])
    );

    const safepayItems = payments.map((p) => {
      const sup = supplierMap.get(String(p.supplierId));
      return {
        _id: p._id,
        recordType: 'safepay_payment',
        paymentReference: p.paymentReference,
        supplierId: p.supplierId,
        supplierName: sup ? sup.businessName : 'Supplier',
        supplierOwnerName: sup ? sup.ownerName : '',
        supplierPhone: sup ? sup.phone : '',
        supplierAccountStatus: sup ? sup.accountStatus : 'Active',
        amount: p.amount,
        currency: p.currency || 'PKR',
        provider: p.provider || 'Safepay',
        environment: p.environment || 'sandbox',
        tracker: p.tracker || null,
        providerReference: p.providerReference || p.tracker || null,
        status: formatPaymentStatus(p.status),
        rawStatus: p.status,
        outstandingBefore: p.outstandingBefore,
        outstandingAfter: p.outstandingAfter,
        allocations: p.allocations || [],
        verifiedVia: p.verifiedVia || null,
        createdAt: p.createdAt,
        verifiedAt: p.verifiedAt,
        failureReason: p.failureReason || null,
        notes: p.notes || '',
      };
    });

    const manualItems = settlements.map((s) => {
      const sup = supplierMap.get(String(s.supplierId));
      return {
        _id: s._id,
        recordType: 'manual_settlement',
        paymentReference: s.settlementReference,
        supplierId: s.supplierId,
        supplierName: sup ? sup.businessName : 'Supplier',
        supplierOwnerName: sup ? sup.ownerName : '',
        supplierPhone: sup ? sup.phone : '',
        supplierAccountStatus: sup ? sup.accountStatus : 'Active',
        amount: s.amountSettled,
        currency: 'PKR',
        provider: 'Manual Admin Settlement',
        environment: 'internal',
        tracker: s.settlementReference,
        providerReference: s.settlementReference,
        status: 'Paid',
        rawStatus: 'paid',
        outstandingBefore: s.previousOutstanding,
        outstandingAfter: s.newOutstanding,
        allocations: [],
        verifiedVia: 'admin_manual',
        createdAt: s.createdAt,
        verifiedAt: s.createdAt,
        failureReason: null,
        notes: s.notes || s.method || '',
      };
    });

    let allTransactions = [...safepayItems, ...manualItems].sort(
      (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
    );

    const now = new Date();
    const MS_PER_DAY = 1000 * 60 * 60 * 24;

    let outstandingCases = [];
    for (const item of charges) {
      if (item.status === 'reversed') continue;
      const sup = supplierMap.get(String(item.supplierId));
      const supOwed = sup ? sup.outstandingCommission : 0;
      if (supOwed <= 0) continue;

      const netCharge = Math.max(
        0,
        (item.commissionAmount || 0) - (item.reversalAmount || 0)
      );
      const paidAmt = item.paidAmount || 0;
      const remainingAmt = Math.max(0, netCharge - paidAmt);
      if (remainingAmt <= 0) continue;

      const dueDate = new Date(
        item.dueDate || item.orderDate || item.createdAt || now
      );
      const daysOverdue =
        now.getTime() > dueDate.getTime()
          ? Math.max(0, Math.floor((now.getTime() - dueDate.getTime()) / MS_PER_DAY))
          : 0;

      outstandingCases.push({
        _id: item._id,
        recordType: 'outstanding_commission',
        paymentReference: item.bookingCode || `COMM-${String(item._id).slice(-6)}`,
        bookingId: item.bookingId,
        bookingCode: item.bookingCode || 'N/A',
        supplierId: item.supplierId,
        supplierName: sup ? sup.businessName : 'Supplier',
        supplierOwnerName: sup ? sup.ownerName : '',
        supplierPhone: sup ? sup.phone : '',
        supplierAccountStatus: sup ? sup.accountStatus : 'Active',
        supplierIsLocked: sup ? sup.isLocked : false,
        grossBookingAmount: item.grossBookingAmount || 0,
        commissionRate: item.commissionRate || env.commissionRate,
        commissionAmount: item.commissionAmount || 0,
        paidAmount: paidAmt,
        remainingAmount: remainingAmt,
        amount: remainingAmt,
        currency: 'PKR',
        provider: 'Commission Ledger',
        status: paidAmt > 0 ? 'Partially Paid' : 'Outstanding',
        rawStatus: paidAmt > 0 ? 'partially_paid' : 'outstanding',
        orderDate: item.orderDate || item.createdAt,
        dueDate,
        daysOverdue,
        isOverdue: daysOverdue > 0,
        isOverdue7Days: daysOverdue >= 7,
        createdAt: item.createdAt,
        verifiedAt: null,
        notes: item.referenceNote || '',
      });
    }

    if (search) {
      const matchPayment = (p) => {
        const ref = (p.paymentReference || '').toLowerCase();
        const trk = (p.tracker || '').toLowerCase();
        const sName = (p.supplierName || '').toLowerCase();
        const sId = String(p.supplierId || '').toLowerCase();
        return (
          ref.includes(search) ||
          trk.includes(search) ||
          sName.includes(search) ||
          sId.includes(search)
        );
      };
      allTransactions = allTransactions.filter(matchPayment);
      outstandingCases = outstandingCases.filter(matchPayment);
    }

    let filteredItems = allTransactions;
    if (filter === 'pending') {
      filteredItems = allTransactions.filter((p) => p.rawStatus === 'pending');
    } else if (filter === 'paid' || filter === 'successful') {
      filteredItems = allTransactions.filter((p) => p.rawStatus === 'paid');
    } else if (filter === 'failed') {
      filteredItems = allTransactions.filter((p) =>
        ['failed', 'cancelled', 'expired', 'refunded'].includes(p.rawStatus)
      );
    } else if (filter === 'outstanding_commissions' || filter === 'outstanding') {
      filteredItems = outstandingCases;
    }

    res.json({
      success: true,
      data: {
        items: filteredItems,
        payments: allTransactions,
        outstandingCommissions: outstandingCases,
        counts: {
          allPayments: allTransactions.length,
          pending: allTransactions.filter((p) => p.rawStatus === 'pending')
            .length,
          paid: allTransactions.filter((p) => p.rawStatus === 'paid').length,
          failed: allTransactions.filter((p) =>
            ['failed', 'cancelled', 'expired', 'refunded'].includes(p.rawStatus)
          ).length,
          outstandingCommissions: outstandingCases.length,
        },
        filter,
        search,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/payments/:id
 * Detailed payment inspection with supplier summary and related commission ledger entries.
 */
exports.getPaymentDetail = async (req, res, next) => {
  try {
    const { id } = req.params;

    let payment = null;
    let settlement = null;
    let commissionCharge = null;

    if (mongoose.Types.ObjectId.isValid(id)) {
      payment = await CommissionPayment.findById(id);
      if (!payment) {
        settlement = await SupplierSettlement.findById(id);
      }
      if (!payment && !settlement) {
        commissionCharge = await CommissionLedger.findById(id);
      }
    }

    if (!payment && !settlement && !commissionCharge) {
      payment = await CommissionPayment.findOne({ paymentReference: id });
    }
    if (!payment && !settlement && !commissionCharge) {
      settlement = await SupplierSettlement.findOne({ settlementReference: id });
    }

    if (!payment && !settlement && !commissionCharge) {
      return res.status(404).json({
        success: false,
        message: 'Payment or commission record not found.',
      });
    }

    const supplierId = payment
      ? payment.supplierId
      : settlement
        ? settlement.supplierId
        : commissionCharge.supplierId;

    const supplierDoc = await SupplierProfile.findById(supplierId);
    const [enrichedSupplier] = supplierDoc
      ? await buildEnrichedSuppliers([supplierDoc])
      : [null];

    let relatedCommissions = [];
    if (payment && Array.isArray(payment.allocations) && payment.allocations.length > 0) {
      const ledgerIds = payment.allocations.map((a) => a.ledgerId);
      relatedCommissions = await CommissionLedger.find({
        _id: { $in: ledgerIds },
      }).sort({ createdAt: 1 });
    } else if (supplierId) {
      relatedCommissions = await CommissionLedger.find({
        supplierId,
        type: 'commission_charge',
      })
        .sort({ createdAt: -1 })
        .limit(20);
    }

    const record = payment
      ? {
          _id: payment._id,
          recordType: 'safepay_payment',
          paymentReference: payment.paymentReference,
          supplierId: payment.supplierId,
          supplierName: enrichedSupplier ? enrichedSupplier.businessName : 'Supplier',
          amount: payment.amount,
          currency: payment.currency || 'PKR',
          provider: payment.provider || 'Safepay',
          environment: payment.environment || 'sandbox',
          tracker: payment.tracker,
          providerReference: payment.providerReference || payment.tracker,
          status: formatPaymentStatus(payment.status),
          rawStatus: payment.status,
          outstandingBefore: payment.outstandingBefore,
          outstandingAfter: payment.outstandingAfter,
          allocations: payment.allocations || [],
          verifiedVia: payment.verifiedVia,
          createdAt: payment.createdAt,
          verifiedAt: payment.verifiedAt,
          failureReason: payment.failureReason,
          notes: payment.notes,
        }
      : settlement
        ? {
            _id: settlement._id,
            recordType: 'manual_settlement',
            paymentReference: settlement.settlementReference,
            supplierId: settlement.supplierId,
            supplierName: enrichedSupplier
              ? enrichedSupplier.businessName
              : 'Supplier',
            amount: settlement.amountSettled,
            currency: 'PKR',
            provider: 'Manual Admin Settlement',
            environment: 'internal',
            tracker: settlement.settlementReference,
            providerReference: settlement.settlementReference,
            status: 'Paid',
            rawStatus: 'paid',
            outstandingBefore: settlement.previousOutstanding,
            outstandingAfter: settlement.newOutstanding,
            allocations: [],
            verifiedVia: 'admin_manual',
            createdAt: settlement.createdAt,
            verifiedAt: settlement.createdAt,
            failureReason: null,
            notes: settlement.notes || settlement.method,
          }
        : {
            _id: commissionCharge._id,
            recordType: 'outstanding_commission',
            paymentReference:
              commissionCharge.bookingCode ||
              `COMM-${String(commissionCharge._id).slice(-6)}`,
            bookingId: commissionCharge.bookingId,
            bookingCode: commissionCharge.bookingCode,
            supplierId: commissionCharge.supplierId,
            supplierName: enrichedSupplier
              ? enrichedSupplier.businessName
              : 'Supplier',
            grossBookingAmount: commissionCharge.grossBookingAmount,
            commissionRate: commissionCharge.commissionRate,
            commissionAmount: commissionCharge.commissionAmount,
            paidAmount: commissionCharge.paidAmount || 0,
            amount: Math.max(
              0,
              (commissionCharge.commissionAmount || 0) -
                (commissionCharge.reversalAmount || 0) -
                (commissionCharge.paidAmount || 0)
            ),
            currency: 'PKR',
            provider: 'Commission Ledger',
            status:
              (commissionCharge.paidAmount || 0) > 0
                ? 'Partially Paid'
                : 'Outstanding',
            rawStatus: commissionCharge.status,
            orderDate: commissionCharge.orderDate || commissionCharge.createdAt,
            dueDate:
              commissionCharge.dueDate ||
              commissionCharge.orderDate ||
              commissionCharge.createdAt,
            createdAt: commissionCharge.createdAt,
            notes: commissionCharge.referenceNote,
          };

    res.json({
      success: true,
      data: {
        payment: record,
        supplier: enrichedSupplier,
        relatedCommissions,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/audit-logs
 * Returns administrative action audit logs.
 */
exports.getAuditLogs = async (req, res, next) => {
  try {
    const targetType = req.query.targetType;
    const query = {};
    if (targetType) query.targetType = targetType;

    const logs = await AdminAuditLog.find(query)
      .sort({ createdAt: -1 })
      .limit(100);

    res.json({
      success: true,
      data: {
        auditLogs: logs,
        totalCount: logs.length,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/pending-suppliers
 * Retrieves suppliers waiting for admin approval (with verified email).
 * Strictly admin-only; returns full CNIC for official verification.
 */
exports.getPendingSuppliers = async (req, res, next) => {
  try {
    const search = (req.query.search || '').trim().toLowerCase();

    // Query suppliers where approvalStatus is pending_approval
    const pendingProfiles = await SupplierProfile.find({
      approvalStatus: 'pending_approval',
    }).sort({ createdAt: -1 });

    const userIds = pendingProfiles.map((p) => p.userId);
    const users = await User.find({ _id: { $in: userIds } });
    const userMap = new Map(users.map((u) => [String(u._id), u]));

    let results = pendingProfiles.map((p) => {
      const u = userMap.get(String(p.userId));
      const cnicRaw = p.cnicNumber || (u ? u.cnicNumber : '') || '';
      return {
        _id: p._id,
        supplierId: p._id,
        userId: p.userId,
        businessName: p.businessName,
        ownerName: p.ownerName || (u ? u.name : ''),
        email: p.email || (u ? u.email : ''),
        phone: p.phone || (u ? u.phone : ''),
        cnicNumber: cnicRaw, // Admin review can view CNIC
        cnicMasked: maskCnic(cnicRaw),
        city: p.city || 'Islamabad',
        serviceAreaText: p.serviceAreaText || '',
        stockLiters: p.stockLiters || 0,
        pricePer1000Liters: p.pricePer1000Liters || 0,
        tankerFleetSize: p.tankerFleetSize || 0,
        deliveryRadiusKm: p.deliveryRadiusKm || 0,
        emailVerified: u ? Boolean(u.emailVerified) : false,
        approvalStatus: p.approvalStatus || 'pending_approval',
        rejectionReason: p.rejectionReason || '',
        createdAt: p.createdAt,
      };
    });

    if (search) {
      results = results.filter((s) => {
        return (
          s.businessName.toLowerCase().includes(search) ||
          s.ownerName.toLowerCase().includes(search) ||
          s.email.toLowerCase().includes(search) ||
          s.phone.toLowerCase().includes(search) ||
          s.cnicNumber.toLowerCase().includes(search)
        );
      });
    }

    res.json({
      success: true,
      data: {
        pendingSuppliers: results,
        totalCount: results.length,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/pending-customers
 * Retrieves customers waiting for admin approval (with verified email).
 * Strictly admin-only; returns full CNIC for official verification.
 */
exports.getPendingCustomers = async (req, res, next) => {
  try {
    const search = (req.query.search || '').trim().toLowerCase();

    const pendingUsers = await User.find({
      role: 'customer',
      approvalStatus: 'pending_approval',
    }).sort({ createdAt: -1 });

    let results = pendingUsers.map((u) => {
      const cnicRaw = u.cnicNumber || '';
      return {
        _id: u._id,
        customerId: u._id,
        name: u.name,
        email: u.email,
        phone: u.phone,
        customerCategory: u.customerCategory || 'Household',
        cnicNumber: cnicRaw,
        cnicMasked: maskCnic(cnicRaw),
        emailVerified: Boolean(u.emailVerified),
        approvalStatus: u.approvalStatus || 'pending_approval',
        rejectionReason: u.rejectionReason || '',
        createdAt: u.createdAt,
      };
    });

    if (search) {
      results = results.filter((c) => {
        return (
          c.name.toLowerCase().includes(search) ||
          c.email.toLowerCase().includes(search) ||
          c.phone.toLowerCase().includes(search) ||
          c.cnicNumber.toLowerCase().includes(search)
        );
      });
    }

    res.json({
      success: true,
      data: {
        pendingCustomers: results,
        totalCount: results.length,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/admin/suppliers/:id/approve
 */
exports.approveSupplier = async (req, res, next) => {
  try {
    const { id } = req.params;
    let supplier = await SupplierProfile.findById(id);
    if (!supplier) {
      supplier = await SupplierProfile.findOne({ userId: id });
    }
    if (!supplier) {
      return res.status(404).json({ success: false, message: 'Supplier profile not found.' });
    }

    const user = await User.findById(supplier.userId);
    const now = new Date();

    supplier.approvalStatus = 'approved';
    supplier.approvedAt = now;
    supplier.approvedBy = req.user._id;
    supplier.approvedByName = req.user.name;
    supplier.rejectionReason = '';
    supplier.isAvailable = true;
    await supplier.save();

    if (user) {
      user.approvalStatus = 'approved';
      user.approvedAt = now;
      user.approvedBy = req.user._id;
      user.approvedByName = req.user.name;
      user.rejectionReason = '';
      await user.save();
    }

    await AdminAuditLog.create({
      adminId: req.user._id,
      adminName: req.user.name,
      adminEmail: req.user.email,
      targetType: 'supplier',
      targetId: supplier._id,
      targetUserId: supplier.userId,
      targetName: supplier.businessName,
      action: 'approve_supplier',
      reason: 'CNIC and supplier credentials approved by admin',
      previousState: 'pending_approval',
      newState: 'approved',
    });

    const recipientEmail = supplier.email || (user ? user.email : '');
    const recipientName = supplier.ownerName || (user ? user.name : 'Supplier');
    if (recipientEmail) {
      emailService.sendDecisionEmail(recipientEmail, recipientName, true, '').catch((err) => {
        console.error('[Admin] Failed to send approval email:', err.message);
      });
    }

    res.json({
      success: true,
      message: `Supplier "${supplier.businessName}" has been approved successfully.`,
      data: {
        supplierId: supplier._id,
        approvalStatus: 'approved',
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/admin/suppliers/:id/reject
 */
exports.rejectSupplier = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const rejectionReason = (reason || 'Application details could not be verified').trim();

    let supplier = await SupplierProfile.findById(id);
    if (!supplier) {
      supplier = await SupplierProfile.findOne({ userId: id });
    }
    if (!supplier) {
      return res.status(404).json({ success: false, message: 'Supplier profile not found.' });
    }

    const user = await User.findById(supplier.userId);
    const now = new Date();

    supplier.approvalStatus = 'rejected';
    supplier.rejectedAt = now;
    supplier.rejectedBy = req.user._id;
    supplier.rejectedByName = req.user.name;
    supplier.rejectionReason = rejectionReason;
    supplier.isAvailable = false;
    await supplier.save();

    if (user) {
      user.approvalStatus = 'rejected';
      user.rejectedAt = now;
      user.rejectedBy = req.user._id;
      user.rejectedByName = req.user.name;
      user.rejectionReason = rejectionReason;
      await user.save();
    }

    await AdminAuditLog.create({
      adminId: req.user._id,
      adminName: req.user.name,
      adminEmail: req.user.email,
      targetType: 'supplier',
      targetId: supplier._id,
      targetUserId: supplier.userId,
      targetName: supplier.businessName,
      action: 'reject_supplier',
      reason: rejectionReason,
      previousState: 'pending_approval',
      newState: 'rejected',
    });

    const recipientEmail = supplier.email || (user ? user.email : '');
    const recipientName = supplier.ownerName || (user ? user.name : 'Supplier');
    if (recipientEmail) {
      emailService.sendDecisionEmail(recipientEmail, recipientName, false, rejectionReason).catch((err) => {
        console.error('[Admin] Failed to send rejection email:', err.message);
      });
    }

    res.json({
      success: true,
      message: `Supplier "${supplier.businessName}" registration was rejected.`,
      data: {
        supplierId: supplier._id,
        approvalStatus: 'rejected',
        rejectionReason,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/admin/customers/:id/approve
 */
exports.approveCustomer = async (req, res, next) => {
  try {
    const { id } = req.params;
    const user = await User.findOne({ _id: id, role: 'customer' });
    if (!user) {
      return res.status(404).json({ success: false, message: 'Customer not found.' });
    }

    const now = new Date();
    user.approvalStatus = 'approved';
    user.approvedAt = now;
    user.approvedBy = req.user._id;
    user.approvedByName = req.user.name;
    user.rejectionReason = '';
    await user.save();

    await AdminAuditLog.create({
      adminId: req.user._id,
      adminName: req.user.name,
      adminEmail: req.user.email,
      targetType: 'customer',
      targetId: user._id,
      targetUserId: user._id,
      targetName: user.name,
      action: 'approve_customer',
      reason: 'CNIC verified and approved by admin',
      previousState: 'pending_approval',
      newState: 'approved',
    });

    if (user.email) {
      emailService.sendDecisionEmail(user.email, user.name, true, '').catch((err) => {
        console.error('[Admin] Failed to send approval email:', err.message);
      });
    }

    res.json({
      success: true,
      message: `Customer "${user.name}" has been approved successfully.`,
      data: {
        customerId: user._id,
        approvalStatus: 'approved',
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/admin/customers/:id/reject
 */
exports.rejectCustomer = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const rejectionReason = (reason || 'Application details could not be verified').trim();

    const user = await User.findOne({ _id: id, role: 'customer' });
    if (!user) {
      return res.status(404).json({ success: false, message: 'Customer not found.' });
    }

    const now = new Date();
    user.approvalStatus = 'rejected';
    user.rejectedAt = now;
    user.rejectedBy = req.user._id;
    user.rejectedByName = req.user.name;
    user.rejectionReason = rejectionReason;
    await user.save();

    await AdminAuditLog.create({
      adminId: req.user._id,
      adminName: req.user.name,
      adminEmail: req.user.email,
      targetType: 'customer',
      targetId: user._id,
      targetUserId: user._id,
      targetName: user.name,
      action: 'reject_customer',
      reason: rejectionReason,
      previousState: 'pending_approval',
      newState: 'rejected',
    });

    if (user.email) {
      emailService.sendDecisionEmail(user.email, user.name, false, rejectionReason).catch((err) => {
        console.error('[Admin] Failed to send rejection email:', err.message);
      });
    }

    res.json({
      success: true,
      message: `Customer "${user.name}" registration was rejected.`,
      data: {
        customerId: user._id,
        approvalStatus: 'rejected',
        rejectionReason,
      },
    });
  } catch (err) {
    next(err);
  }
};
