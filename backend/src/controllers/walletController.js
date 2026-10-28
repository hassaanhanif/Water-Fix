const env = require('../config/env');
const SupplierProfile = require('../models/SupplierProfile');
const CommissionLedger = require('../models/CommissionLedger');
const SupplierSettlement = require('../models/SupplierSettlement');
const CommissionPayment = require('../models/CommissionPayment');
const Notification = require('../models/Notification');
const safepayService = require('../services/safepayService');

function formatCommissionStatus(item) {
  if (!item) return 'Outstanding';
  if (item.status === 'reversed') return 'Reversed';
  const netCharge = Math.max(0, (item.commissionAmount || 0) - (item.reversalAmount || 0));
  const paid = item.paidAmount || 0;
  if (netCharge === 0 && (item.reversalAmount || 0) > 0) return 'Reversed';
  if (item.status === 'paid' || item.status === 'settled' || paid >= netCharge) {
    return 'Paid';
  }
  if (item.status === 'partially_paid' || (paid > 0 && paid < netCharge)) {
    return 'Partially Paid';
  }
  return 'Outstanding';
}

function formatPaymentStatus(rawStatus) {
  switch ((rawStatus || '').toLowerCase()) {
    case 'paid':
    case 'settled':
      return 'Paid';
    case 'pending':
      return 'Pending';
    case 'failed':
      return 'Failed';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    case 'expired':
      return 'Expired';
    case 'refunded':
      return 'Refunded';
    default:
      return 'Pending';
  }
}

const MS_PER_DAY = 1000 * 60 * 60 * 24;

/**
 * Shared business rule to calculate per-entry and supplier-level commission,
 * overdue days, oldest outstanding due date, and most recent verified payment date.
 * - Never counts a commission as overdue before its `dueDate`.
 * - Calculates overdue days as `Math.max(0, Math.floor((now - oldestDueDate) / MS_PER_DAY))`
 *   when `now > oldestDueDate` and unpaid balance > 0.
 * - `isOverdue7Days` is true when `daysOverdue >= 7`.
 */
function calculateSupplierCommissionMetrics({
  supplier,
  chargeItems = [],
  payments = [],
  settlements = [],
  now = new Date(),
}) {
  const totalCommissionCharged = supplier.totalCommissionCharged || 0;
  const totalCommissionPaid = supplier.totalSettledCommission || 0;
  const totalCommissionOwed = supplier.outstandingCommission || 0;
  const amountCurrentlyPayable = Math.max(0, totalCommissionOwed);

  const pendingPaymentAmount = payments
    .filter((p) => p.status === 'pending')
    .reduce((sum, p) => sum + (p.amount || 0), 0);

  let walletPaymentStatus = 'Paid';
  if (totalCommissionOwed > 0) {
    if (pendingPaymentAmount > 0) {
      walletPaymentStatus = 'Pending';
    } else if (totalCommissionPaid > 0) {
      walletPaymentStatus = 'Partially Paid';
    } else {
      walletPaymentStatus = 'Outstanding';
    }
  } else if (pendingPaymentAmount > 0) {
    walletPaymentStatus = 'Pending';
  } else {
    walletPaymentStatus = 'Paid';
  }

  let oldestOutstandingDueDate = null;

  const formattedCommissionItems = chargeItems.map((item) => {
    const netCharge = Math.max(
      0,
      (item.commissionAmount || 0) - (item.reversalAmount || 0)
    );
    const paidAmt =
      totalCommissionOwed === 0 && (item.paidAmount || 0) === 0 && item.status !== 'reversed'
        ? netCharge
        : item.paidAmount || 0;
    const remainingAmt = item.status === 'reversed' ? 0 : Math.max(0, netCharge - paidAmt);
    const statusLabel =
      totalCommissionOwed === 0 && item.status !== 'reversed'
        ? 'Paid'
        : formatCommissionStatus(item);

    const rawDue = item.dueDate || item.orderDate || item.createdAt || now;
    const dueDate = new Date(rawDue);

    let entryDaysOverdue = 0;
    if (remainingAmt > 0 && now.getTime() > dueDate.getTime()) {
      entryDaysOverdue = Math.max(
        0,
        Math.floor((now.getTime() - dueDate.getTime()) / MS_PER_DAY)
      );
    }

    if (remainingAmt > 0 && totalCommissionOwed > 0) {
      if (
        !oldestOutstandingDueDate ||
        dueDate.getTime() < oldestOutstandingDueDate.getTime()
      ) {
        oldestOutstandingDueDate = dueDate;
      }
    }

    return {
      _id: item._id,
      bookingId: item.bookingId,
      bookingCode: item.bookingCode || 'N/A',
      orderDate: item.orderDate || item.createdAt,
      dueDate,
      createdAt: item.createdAt,
      grossBookingAmount: item.grossBookingAmount || 0,
      commissionRate: item.commissionRate || env.commissionRate,
      commissionPercentage: Math.round(
        (item.commissionRate || env.commissionRate) * 100
      ),
      commissionAmount: item.commissionAmount || 0,
      paidAmount: paidAmt,
      reversalAmount: item.reversalAmount || 0,
      remainingAmount: remainingAmt,
      commissionStatus: statusLabel,
      daysOverdue: entryDaysOverdue,
      isOverdue: remainingAmt > 0 && entryDaysOverdue > 0,
      isOverdue7Days: remainingAmt > 0 && entryDaysOverdue >= 7,
      outstandingBalanceAfter: item.outstandingBalanceAfter,
      referenceNote: item.referenceNote || '',
    };
  });

  // Fallback if supplier has outstandingCommission > 0 but no charge ledger rows exist
  if (totalCommissionOwed > 0 && !oldestOutstandingDueDate && supplier.createdAt) {
    oldestOutstandingDueDate = new Date(supplier.createdAt);
  }

  let daysOverdue = 0;
  if (
    totalCommissionOwed > 0 &&
    oldestOutstandingDueDate &&
    now.getTime() > oldestOutstandingDueDate.getTime()
  ) {
    daysOverdue = Math.max(
      0,
      Math.floor((now.getTime() - oldestOutstandingDueDate.getTime()) / MS_PER_DAY)
    );
  }

  const isOverdue = totalCommissionOwed > 0 && daysOverdue > 0;
  const isOverdue7Days = totalCommissionOwed > 0 && daysOverdue >= 7;

  // Determine most recent successful payment date across SupplierProfile, CommissionPayment, and SupplierSettlement
  let lastCommissionPaymentAt = supplier.lastCommissionPaymentAt
    ? new Date(supplier.lastCommissionPaymentAt)
    : null;

  for (const p of payments) {
    if (p.status === 'paid') {
      const paidDate = new Date(p.verifiedAt || p.updatedAt || p.createdAt);
      if (!lastCommissionPaymentAt || paidDate > lastCommissionPaymentAt) {
        lastCommissionPaymentAt = paidDate;
      }
    }
  }
  for (const s of settlements) {
    const settledDate = new Date(s.createdAt);
    if (!lastCommissionPaymentAt || settledDate > lastCommissionPaymentAt) {
      lastCommissionPaymentAt = settledDate;
    }
  }

  return {
    totalCommissionCharged,
    totalCommissionPaid,
    totalCommissionOwed,
    amountCurrentlyPayable,
    pendingPaymentAmount,
    walletPaymentStatus,
    oldestOutstandingDueDate,
    daysOverdue,
    isOverdue,
    isOverdue7Days,
    lastCommissionPaymentAt,
    formattedCommissionItems,
  };
}

exports.formatCommissionStatus = formatCommissionStatus;
exports.formatPaymentStatus = formatPaymentStatus;
exports.calculateSupplierCommissionMetrics = calculateSupplierCommissionMetrics;

/**
 * Allocates a verified payment amount FIFO across the supplier's oldest unpaid
 * `commission_charge` ledger entries.
 */
async function allocatePaymentAcrossCommissions(supplierId, amountToAllocate) {
  let remaining = Number(amountToAllocate) || 0;
  const allocations = [];
  if (remaining <= 0) return allocations;

  const charges = await CommissionLedger.find({
    supplierId,
    type: 'commission_charge',
    status: { $ne: 'reversed' },
  }).sort({ createdAt: 1 });

  for (const charge of charges) {
    if (remaining <= 0) break;
    const netCharge = Math.max(
      0,
      (charge.commissionAmount || 0) - (charge.reversalAmount || 0)
    );
    const alreadyPaid = charge.paidAmount || 0;
    const unpaid = Math.max(0, netCharge - alreadyPaid);
    if (unpaid <= 0) {
      if (charge.status !== 'paid') {
        charge.status = 'paid';
        await charge.save();
      }
      continue;
    }

    const allocated = Math.min(unpaid, remaining);
    charge.paidAmount = alreadyPaid + allocated;
    remaining -= allocated;

    if (charge.paidAmount >= netCharge) {
      charge.status = 'paid';
    } else if (charge.paidAmount > 0) {
      charge.status = 'partially_paid';
    } else {
      charge.status = 'accrued';
    }

    await charge.save();
    allocations.push({
      ledgerId: charge._id,
      bookingId: charge.bookingId || null,
      bookingCode: charge.bookingCode || '',
      amountAllocated: allocated,
    });
  }

  return allocations;
}

/**
 * Reverses a previously paid CommissionPayment's allocations if a payment is refunded.
 */
async function reversePaymentAllocations(supplier, payment, reason) {
  if (Array.isArray(payment.allocations) && payment.allocations.length > 0) {
    for (const alloc of payment.allocations) {
      const ledgerItem = await CommissionLedger.findById(alloc.ledgerId);
      if (ledgerItem) {
        const netCharge = Math.max(
          0,
          (ledgerItem.commissionAmount || 0) - (ledgerItem.reversalAmount || 0)
        );
        ledgerItem.paidAmount = Math.max(
          0,
          (ledgerItem.paidAmount || 0) - (alloc.amountAllocated || 0)
        );
        if (ledgerItem.paidAmount <= 0) {
          ledgerItem.status = 'accrued';
        } else if (ledgerItem.paidAmount < netCharge) {
          ledgerItem.status = 'partially_paid';
        } else {
          ledgerItem.status = 'paid';
        }
        await ledgerItem.save();
      }
    }
  }

  const updatedSupplier = await SupplierProfile.findByIdAndUpdate(
    supplier._id,
    {
      $inc: {
        outstandingCommission: payment.amount,
        totalSettledCommission: -payment.amount,
      },
    },
    { new: true }
  );

  if (updatedSupplier && updatedSupplier.totalSettledCommission < 0) {
    updatedSupplier.totalSettledCommission = 0;
    await updatedSupplier.save();
  }

  const newOutstanding = updatedSupplier
    ? updatedSupplier.outstandingCommission
    : (supplier.outstandingCommission || 0) + payment.amount;

  await CommissionLedger.create({
    supplierId: supplier._id,
    supplierUserId: supplier.userId,
    type: 'commission_reversal',
    grossBookingAmount: 0,
    commissionRate: env.commissionRate,
    commissionAmount: payment.amount,
    supplierNetAmount: 0,
    status: 'reversed',
    outstandingBalanceAfter: newOutstanding,
    settlementReference: payment.paymentReference,
    providerTransactionId: payment.tracker,
    referenceNote:
      reason ||
      `Safepay payment ${payment.paymentReference} refunded/reversed (Rs ${payment.amount.toLocaleString()}).`,
  });

  return newOutstanding;
}

/**
 * Atomically transitions a pending CommissionPayment to `paid` and reconciles
 * the supplier's commission ledger and profile balances. Safe against duplicate calls.
 */
async function finalizeVerifiedSafepayPayment({
  payment,
  tracker,
  providerReference,
  verifiedVia = 'callback_signature',
  webhookEventId = null,
}) {
  const updateOps = {
    $set: {
      status: 'paid',
      verifiedAt: new Date(),
      verifiedVia,
      providerReference: providerReference || tracker || payment.tracker,
    },
  };
  if (webhookEventId) {
    updateOps.$addToSet = { webhookEventIds: webhookEventId };
  }

  const claimedPayment = await CommissionPayment.findOneAndUpdate(
    { _id: payment._id, status: 'pending' },
    updateOps,
    { new: true }
  );

  const supplier = await SupplierProfile.findById(payment.supplierId);
  if (!claimedPayment) {
    const latestPayment = await CommissionPayment.findById(payment._id);
    if (webhookEventId && latestPayment && !latestPayment.webhookEventIds.includes(webhookEventId)) {
      latestPayment.webhookEventIds.push(webhookEventId);
      await latestPayment.save();
    }
    return {
      alreadyProcessed: true,
      payment: latestPayment || payment,
      supplier,
    };
  }

  const allocations = await allocatePaymentAcrossCommissions(
    supplier._id,
    claimedPayment.amount
  );

  const previousOutstanding = supplier.outstandingCommission || 0;
  const newOutstanding = Math.max(0, previousOutstanding - claimedPayment.amount);

  supplier.outstandingCommission = newOutstanding;
  supplier.totalSettledCommission =
    (supplier.totalSettledCommission || 0) + claimedPayment.amount;
  supplier.lastCommissionPaymentAt = new Date();
  await supplier.save();

  claimedPayment.allocations = allocations;
  claimedPayment.outstandingBefore = previousOutstanding;
  claimedPayment.outstandingAfter = newOutstanding;
  await claimedPayment.save();

  const ledgerEntry = await CommissionLedger.create({
    supplierId: supplier._id,
    supplierUserId: supplier.userId,
    type: 'safepay_payment',
    grossBookingAmount: 0,
    commissionRate: env.commissionRate,
    commissionAmount: -claimedPayment.amount,
    paidAmount: claimedPayment.amount,
    supplierNetAmount: 0,
    status: 'settled',
    outstandingBalanceAfter: newOutstanding,
    settlementReference: claimedPayment.paymentReference,
    providerTransactionId: claimedPayment.tracker,
    referenceNote: `Safepay Test Payment (${claimedPayment.paymentReference}) verified [Tracker: ${claimedPayment.tracker || 'N/A'}].`,
  });

  await Notification.create({
    userId: supplier.userId,
    type: 'settlement_recorded',
    title: 'Commission payment verified via Safepay',
    body: `Your commission payment of Rs ${claimedPayment.amount.toLocaleString()} (${claimedPayment.paymentReference}) was verified. Remaining commission owed: Rs ${newOutstanding.toLocaleString()}.`,
  });

  return {
    alreadyProcessed: false,
    payment: claimedPayment,
    ledgerEntry,
    supplier,
  };
}

exports.getSupplierWallet = async (req, res, next) => {
  try {
    const supplier = await SupplierProfile.findOne({ userId: req.user._id });
    if (!supplier) {
      return res.status(404).json({
        success: false,
        message: 'Supplier profile not found.',
      });
    }

    const [ledger, settlements, payments] = await Promise.all([
      CommissionLedger.find({ supplierId: supplier._id })
        .sort({ createdAt: -1 })
        .limit(100),
      SupplierSettlement.find({ supplierId: supplier._id })
        .sort({ createdAt: -1 })
        .limit(50),
      CommissionPayment.find({ supplierId: supplier._id })
        .sort({ createdAt: -1 })
        .limit(100),
    ]);

    const chargeItems = ledger.filter((item) => item.type === 'commission_charge');

    const metrics = calculateSupplierCommissionMetrics({
      supplier,
      chargeItems,
      payments,
      settlements,
    });

    const {
      totalCommissionCharged,
      totalCommissionPaid,
      totalCommissionOwed,
      amountCurrentlyPayable,
      pendingPaymentAmount,
      walletPaymentStatus,
      oldestOutstandingDueDate,
      daysOverdue,
      isOverdue,
      isOverdue7Days,
      lastCommissionPaymentAt,
      formattedCommissionItems: commissionHistory,
    } = metrics;

    const netEarningsBeforeExpenses =
      (supplier.totalGrossEarnings || 0) - totalCommissionCharged;

    const safepayPaymentsFormatted = payments.map((p) => ({
      _id: p._id,
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
      checkoutUrl: p.status === 'pending' ? p.checkoutUrl : null,
      failureReason: p.failureReason || null,
      notes: p.notes || '',
    }));

    const manualSettlementsFormatted = settlements.map((s) => ({
      _id: s._id,
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
      checkoutUrl: null,
      failureReason: null,
      notes: s.notes || s.method || '',
    }));

    const paymentHistory = [
      ...safepayPaymentsFormatted,
      ...manualSettlementsFormatted,
    ].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    const safepayConfig = safepayService.getSafepayConfig();

    res.json({
      success: true,
      data: {
        summary: {
          supplierId: supplier._id,
          businessName: supplier.businessName,
          commissionRate: env.commissionRate,
          commissionPercentage: Math.round(env.commissionRate * 100),
          totalGrossEarnings: supplier.totalGrossEarnings || 0,
          totalCommissionCharged,
          netEarningsBeforeExpenses,
          // Required Supplier Wallet Overview fields:
          totalCommissionOwed,
          amountCurrentlyPayable,
          totalCommissionPaid,
          pendingPaymentAmount,
          paymentStatus: walletPaymentStatus,
          // Backward-compatible fields:
          outstandingCommission: totalCommissionOwed,
          totalSettledCommission: totalCommissionPaid,
          // Overdue & account status fields:
          oldestOutstandingDueDate,
          daysOverdue,
          isOverdue,
          isOverdue7Days,
          lastCommissionPaymentAt,
          accountStatus: supplier.isLocked ? 'Locked' : 'Active',
          isLocked: Boolean(supplier.isLocked),
          lockReason: supplier.lockReason || '',
          // Safepay test mode configuration info (no secrets exposed):
          safepayConfigured: safepayConfig.configured,
          safepayEnvironment: safepayConfig.environment,
        },
        commissionHistory,
        paymentHistory,
        ledger,
        settlements,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * Initiates a Safepay TEST MODE hosted checkout session for the authenticated supplier's
 * outstanding commission debt.
 * Route: POST /api/wallet/safepay/session
 */
exports.createSafepayPaymentSession = async (req, res, next) => {
  try {
    if (!req.user || req.user.role !== 'supplier') {
      return res.status(403).json({
        success: false,
        message: 'Only authenticated supplier accounts can initiate commission payments.',
      });
    }

    const supplier = await SupplierProfile.findOne({ userId: req.user._id });
    if (!supplier) {
      return res.status(404).json({
        success: false,
        message: 'Supplier profile not found.',
      });
    }

    // Prevent cross-supplier tampering if supplierId was passed in request body
    if (
      req.body.supplierId &&
      String(req.body.supplierId) !== String(supplier._id)
    ) {
      return res.status(403).json({
        success: false,
        message: 'Cannot create a commission payment session for another supplier.',
      });
    }

    const outstanding = Math.round(supplier.outstandingCommission || 0);
    if (outstanding <= 0) {
      return res.status(400).json({
        success: false,
        message: 'You have no outstanding commission due at this time (Rs 0).',
      });
    }

    const requestedAmount =
      req.body.amount !== undefined && req.body.amount !== null && req.body.amount !== ''
        ? Number(req.body.amount)
        : outstanding;

    if (!Number.isFinite(requestedAmount) || requestedAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Payment amount must be a positive amount in PKR.',
      });
    }

    const payAmount = Math.round(requestedAmount);
    if (payAmount > outstanding) {
      return res.status(400).json({
        success: false,
        message: `Payment amount (Rs ${payAmount.toLocaleString()}) cannot exceed your outstanding commission owed (Rs ${outstanding.toLocaleString()}).`,
      });
    }

    const currency = req.body.currency
      ? String(req.body.currency).trim().toUpperCase()
      : 'PKR';
    if (currency !== 'PKR') {
      return res.status(400).json({
        success: false,
        message: 'Only PKR currency is supported for WaterFix commission payments.',
      });
    }

    const paymentReference = `SFPY-${Date.now()}-${Math.floor(1000 + Math.random() * 9000)}`;

    // Whitelist supported internal return destinations (defaults to 'wallet')
    const validReturnTargets = ['wallet', 'orders', 'listings', 'account'];
    const requestedTarget = (req.body.returnTarget || req.body.target || 'wallet')
      .toString()
      .trim()
      .toLowerCase();
    const returnTarget = validReturnTargets.includes(requestedTarget)
      ? requestedTarget
      : 'wallet';

    // Dynamically resolve reachable server base URL to eliminate "No connection"
    // on physical Android phones, emulators, and local web browsers.
    let serverBase = null;
    if (req.body.clientBaseUrl && typeof req.body.clientBaseUrl === 'string') {
      serverBase = req.body.clientBaseUrl.trim().replace(/\/api\/?$/, '');
    } else if (
      process.env.SAFEPAY_REDIRECT_URL &&
      !process.env.SAFEPAY_REDIRECT_URL.includes('localhost:5000') &&
      !process.env.SAFEPAY_REDIRECT_URL.includes('127.0.0.1:5000')
    ) {
      try {
        const parsed = new URL(process.env.SAFEPAY_REDIRECT_URL);
        serverBase = parsed.origin;
      } catch (_) {}
    }

    if (!serverBase) {
      const proto = req.headers['x-forwarded-proto'] || req.protocol || 'http';
      serverBase = `${proto}://${req.get('host')}`;
    }

    const redirectUrl = `${serverBase}/api/wallet/safepay/return`;
    const cancelUrl = `${serverBase}/api/wallet/safepay/return?status=cancelled`;

    let checkoutSession;
    try {
      checkoutSession = await safepayService.createCheckoutSession({
        amount: payAmount,
        currency: 'PKR',
        paymentReference,
        redirectUrl,
        cancelUrl,
        returnTarget,
      });
    } catch (err) {
      if (err.code === 'SAFEPAY_CREDENTIALS_MISSING') {
        return res.status(503).json({
          success: false,
          code: 'SAFEPAY_CREDENTIALS_MISSING',
          message: err.message,
        });
      }
      return res.status(err.statusCode || 502).json({
        success: false,
        code: err.code || 'SAFEPAY_GATEWAY_ERROR',
        message:
          err.message && !err.message.toLowerCase().includes('fetch failed')
            ? err.message
            : 'Unable to connect to Safepay sandbox gateway. Please check your internet connection and try again.',
      });
    }

    const payment = await CommissionPayment.create({
      paymentReference,
      supplierId: supplier._id,
      supplierUserId: supplier.userId,
      amount: payAmount,
      currency: 'PKR',
      provider: 'Safepay',
      environment: 'sandbox',
      tracker: checkoutSession.tracker,
      checkoutUrl: checkoutSession.checkoutUrl,
      status: 'pending',
      returnTarget,
      clientOrigin: req.body.clientOrigin || null,
      clientRedirectUrl: redirectUrl,
      outstandingBefore: outstanding,
      notes: `Safepay Sandbox commission checkout initiated for Rs ${payAmount.toLocaleString()}`,
    });

    return res.status(201).json({
      success: true,
      message: 'Safepay Test Mode checkout session created.',
      data: {
        paymentId: payment._id,
        paymentReference: payment.paymentReference,
        tracker: payment.tracker,
        checkoutUrl: payment.checkoutUrl,
        amount: payment.amount,
        currency: payment.currency,
        environment: payment.environment,
        status: 'Pending',
        rawStatus: payment.status,
        outstandingCommission: outstanding,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * Verifies a Safepay payment session using cryptographic HMAC-SHA256 signature (`sig`)
 * or server-to-server Safepay Reporter API verification.
 * Route: POST /api/wallet/safepay/verify
 */
exports.verifySafepayPayment = async (req, res, next) => {
  try {
    const {
      paymentReference,
      order_id: orderIdFromBody,
      tracker: trackerFromBody,
      beacon,
      sig,
      reference,
    } = req.body || {};

    const resolvedRef = paymentReference || orderIdFromBody;
    const resolvedTracker = trackerFromBody || beacon;

    if (!resolvedRef && !resolvedTracker) {
      return res.status(400).json({
        success: false,
        message: 'paymentReference or tracker is required to verify a Safepay payment.',
      });
    }

    const query = resolvedRef
      ? { paymentReference: resolvedRef }
      : { tracker: resolvedTracker };
    const payment = await CommissionPayment.findOne(query);

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Commission payment session not found.',
      });
    }

    // Ensure a supplier can only verify their own payment session
    if (
      req.user &&
      req.user.role === 'supplier' &&
      String(payment.supplierUserId) !== String(req.user._id)
    ) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to access this payment session.',
      });
    }

    if (resolvedTracker && payment.tracker && resolvedTracker !== payment.tracker) {
      return res.status(400).json({
        success: false,
        message: 'Tracker mismatch: provided tracker does not match this payment session.',
      });
    }

    if (payment.status === 'paid') {
      const supplier = await SupplierProfile.findById(payment.supplierId);
      return res.json({
        success: true,
        alreadyProcessed: true,
        message: 'This commission payment has already been verified and applied.',
        data: {
          paymentReference: payment.paymentReference,
          tracker: payment.tracker,
          amount: payment.amount,
          status: 'Paid',
          rawStatus: payment.status,
          outstandingCommission: supplier ? supplier.outstandingCommission : 0,
          totalSettledCommission: supplier ? supplier.totalSettledCommission : 0,
        },
      });
    }

    if (payment.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: `Payment session ${payment.paymentReference} is currently ${payment.status} and cannot be verified as paid.`,
        data: {
          paymentReference: payment.paymentReference,
          status: formatPaymentStatus(payment.status),
          rawStatus: payment.status,
        },
      });
    }

    const trackerToVerify = payment.tracker || resolvedTracker;
    let verifiedVia = null;
    let providerReference = reference || trackerToVerify;

    if (sig) {
      const isSigValid = safepayService.verifyCallbackSignature({
        tracker: trackerToVerify,
        sig,
      });
      if (!isSigValid) {
        return res.status(400).json({
          success: false,
          code: 'INVALID_SAFEPAY_SIGNATURE',
          message:
            'Invalid Safepay cryptographic signature (sig). Payment cannot be marked as paid without valid verification.',
        });
      }
      verifiedVia = 'callback_signature';
    } else {
      // Fallback: check Safepay Reporter API directly from backend
      let trackerInfo = null;
      try {
        trackerInfo = await safepayService.fetchTrackerStatus(trackerToVerify);
      } catch (_err) {
        trackerInfo = null;
      }

      const paidStates = ['TRACKER_ENDED', 'PAID', 'COMPLETED', 'SUCCEEDED'];
      const reportedState =
        trackerInfo && trackerInfo.state ? String(trackerInfo.state).toUpperCase() : '';

      if (!trackerInfo || !paidStates.includes(reportedState)) {
        return res.status(400).json({
          success: false,
          code: 'PAYMENT_NOT_VERIFIED',
          message:
            'Safepay has not confirmed completion of this payment yet. Complete the hosted checkout or wait for webhook confirmation.',
          data: {
            paymentReference: payment.paymentReference,
            tracker: payment.tracker,
            status: formatPaymentStatus(payment.status),
            rawStatus: payment.status,
          },
        });
      }

      if (
        trackerInfo.amount !== null &&
        Math.round(Number(trackerInfo.amount)) !== Math.round(payment.amount)
      ) {
        return res.status(400).json({
          success: false,
          code: 'PAYMENT_AMOUNT_MISMATCH',
          message: 'Verified Safepay amount does not match the payment session amount.',
        });
      }

      if (
        trackerInfo.currency &&
        String(trackerInfo.currency).toUpperCase() !== payment.currency
      ) {
        return res.status(400).json({
          success: false,
          code: 'PAYMENT_CURRENCY_MISMATCH',
          message: 'Verified Safepay currency does not match PKR.',
        });
      }

      verifiedVia = 'reporter_api';
      providerReference = trackerInfo.reference || trackerToVerify;
    }

    const result = await finalizeVerifiedSafepayPayment({
      payment,
      tracker: trackerToVerify,
      providerReference,
      verifiedVia,
    });

    return res.json({
      success: true,
      alreadyProcessed: result.alreadyProcessed,
      message: 'Safepay commission payment verified and applied to your wallet.',
      data: {
        paymentReference: result.payment.paymentReference,
        tracker: result.payment.tracker,
        providerReference: result.payment.providerReference,
        amount: result.payment.amount,
        currency: result.payment.currency,
        status: 'Paid',
        rawStatus: result.payment.status,
        allocations: result.payment.allocations,
        outstandingCommission: result.supplier
          ? result.supplier.outstandingCommission
          : 0,
        totalSettledCommission: result.supplier
          ? result.supplier.totalSettledCommission
          : 0,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * Generates the clean, unique WaterFix-branded payment return HTML page.
 * Follows WaterFix theme (Deep Brand Blue #0F4C81, Aqua Glow #00A896, Slate #F4F8FB),
 * displays authoritative payment states, executes an uninterrupted 5-4-3-2-1 countdown,
 * and provides working redirect and close window actions.
 */
function renderWaterFixPaymentResultHtml({
  payment,
  status = 'pending',
  errorMessage = null,
}) {
  const isPaid = status === 'paid';
  const isPending = status === 'pending';
  const isCancelled = status === 'cancelled' || status === 'failed';

  let title = 'Payment successful';
  let badgeBg = '#DCFCE7';
  let badgeColor = '#16A34A';
  let iconSvg = `<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#16A34A" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>`;
  let explanation =
    'Your commission settlement has been cryptographically verified and recorded. Your wallet balance has been updated.';

  if (isCancelled) {
    title = 'Payment was not completed';
    badgeColor = '#DC2626';
    badgeBg = '#FEE2E2';
    iconSvg = `<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#DC2626" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>`;
    explanation =
      errorMessage ||
      'The checkout session was cancelled or could not be completed. No funds were charged and your commission balance remains unchanged.';
  } else if (isPending) {
    title = 'Payment Verification in Progress';
    badgeColor = '#0284C7';
    badgeBg = '#E0F2FE';
    iconSvg = `<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#0284C7" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>`;
    explanation =
      'Payment session received from checkout. WaterFix is verifying the transaction status with Safepay. Your outstanding commission balance will be updated once confirmed.';
  } else if (errorMessage) {
    title = 'Unable to verify payment. Please check your wallet.';
    badgeColor = '#DC2626';
    badgeBg = '#FEE2E2';
    iconSvg = `<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#DC2626" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>`;
    explanation = errorMessage;
  }

  const paymentRef = payment ? payment.paymentReference : 'N/A';
  const tracker = payment && payment.tracker ? payment.tracker : 'N/A';
  const amountStr = payment ? `Rs ${payment.amount.toLocaleString()} PKR` : 'N/A';
  const returnTarget = (payment && payment.returnTarget) || 'wallet';
  const clientOrigin = (payment && payment.clientOrigin) || '';

  const targetLabel =
    returnTarget === 'orders'
      ? 'Orders'
      : returnTarget === 'listings'
      ? 'Listings'
      : returnTarget === 'account'
      ? 'Profile'
      : 'Supplier Wallet';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <title>WaterFix — ${title}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
      background: #F4F8FB;
      color: #0F172A;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px 16px;
    }
    .header-brand {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 20px;
      text-decoration: none;
    }
    .header-logo {
      width: 38px;
      height: 38px;
      background: linear-gradient(135deg, #0F4C81, #00A896);
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 12px rgba(15, 76, 129, 0.25);
    }
    .header-title {
      font-size: 20px;
      font-weight: 800;
      color: #092C4C;
      letter-spacing: -0.3px;
    }
    .header-tag {
      font-size: 11px;
      font-weight: 700;
      color: #00A896;
      background: rgba(0, 168, 150, 0.1);
      padding: 3px 8px;
      border-radius: 6px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .main-card {
      background: #FFFFFF;
      border-radius: 28px;
      box-shadow: 0 12px 36px -8px rgba(15, 76, 129, 0.12), 0 2px 6px rgba(0,0,0,0.03);
      border: 1px solid #E2E8F0;
      width: 100%;
      max-width: 450px;
      padding: 32px 24px;
      text-align: center;
      position: relative;
      overflow: hidden;
    }
    .main-card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 6px;
      background: linear-gradient(90deg, #0F4C81, #00A896);
    }
    .icon-wrapper {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      background: ${badgeBg};
      display: inline-flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 16px;
      box-shadow: 0 4px 14px ${badgeColor}25;
    }
    .status-title {
      font-size: 22px;
      font-weight: 800;
      color: #0F172A;
      margin-bottom: 8px;
      letter-spacing: -0.4px;
    }
    .status-explanation {
      font-size: 13.5px;
      line-height: 1.5;
      color: #64748B;
      margin-bottom: 20px;
      padding: 0 6px;
    }
    /* Simple and unique countdown card */
    .countdown-card {
      background: #F0F9FF;
      border: 1.5px solid #BAE6FD;
      border-radius: 18px;
      padding: 14px 18px;
      margin-bottom: 22px;
      display: flex;
      align-items: center;
      gap: 14px;
      text-align: left;
    }
    .countdown-badge {
      position: relative;
      width: 48px;
      height: 48px;
      flex-shrink: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #0F4C81;
      color: #FFFFFF;
      border-radius: 50%;
      box-shadow: 0 4px 12px rgba(15, 76, 129, 0.3);
    }
    .countdown-number {
      font-size: 22px;
      font-weight: 800;
      line-height: 1;
      transition: transform 0.15s ease;
    }
    .countdown-number.pop {
      transform: scale(1.35);
    }
    .countdown-pulse-ring {
      position: absolute;
      inset: -4px;
      border-radius: 50%;
      border: 2px solid #00A896;
      opacity: 0.7;
      animation: pulseRing 1.2s ease-out infinite;
    }
    @keyframes pulseRing {
      0% { transform: scale(0.95); opacity: 0.9; }
      50% { transform: scale(1.15); opacity: 0.2; }
      100% { transform: scale(0.95); opacity: 0.9; }
    }
    .countdown-main-text {
      font-size: 14px;
      font-weight: 700;
      color: #0F4C81;
    }
    .countdown-sub-text {
      font-size: 12px;
      color: #64748B;
      margin-top: 2px;
    }
    .details-box {
      background: #F8FAFC;
      border-radius: 16px;
      border: 1px solid #E2E8F0;
      padding: 14px 16px;
      margin-bottom: 22px;
      text-align: left;
    }
    .detail-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 7px 0;
      border-bottom: 1px dashed #E2E8F0;
      font-size: 12.5px;
    }
    .detail-row:last-child {
      border-bottom: none;
      padding-bottom: 0;
    }
    .detail-row:first-child {
      padding-top: 0;
    }
    .detail-label {
      color: #64748B;
      font-weight: 600;
    }
    .detail-value {
      color: #0F172A;
      font-weight: 700;
      text-align: right;
    }
    .actions-group {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 14px 20px;
      border-radius: 14px;
      font-size: 14.5px;
      font-weight: 700;
      cursor: pointer;
      text-decoration: none;
      transition: all 0.15s ease-in-out;
      border: none;
      width: 100%;
    }
    .btn-primary {
      background: #0F4C81;
      color: #FFFFFF;
      box-shadow: 0 4px 14px rgba(15, 76, 129, 0.25);
    }
    .btn-primary:hover, .btn-primary:active {
      background: #092C4C;
      transform: translateY(-1px);
    }
    .btn-secondary {
      background: #F1F5F9;
      color: #334155;
    }
    .btn-secondary:hover, .btn-secondary:active {
      background: #E2E8F0;
    }
    .footer-note {
      margin-top: 20px;
      font-size: 12px;
      color: #94A3B8;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="header-brand">
    <div class="header-logo">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path>
      </svg>
    </div>
    <span class="header-title">WaterFix</span>
    <span class="header-tag">Commission Portal</span>
  </div>

  <div class="main-card">
    <div class="icon-wrapper">
      ${iconSvg}
    </div>

    <h1 class="status-title">${title}</h1>
    <p class="status-explanation">${explanation}</p>

    <!-- Always visible, active 5-4-3-2-1 countdown widget -->
    <div class="countdown-card" id="countdownCard">
      <div class="countdown-badge">
        <span class="countdown-pulse-ring"></span>
        <span class="countdown-number" id="countdownVal">5</span>
      </div>
      <div class="countdown-label-group">
        <div class="countdown-main-text">Returning to WaterFix in <strong id="cdTextNum">5</strong> seconds...</div>
        <div class="countdown-sub-text" id="cdSubText">Preparing your refreshed wallet session</div>
      </div>
    </div>

    <div class="details-box">
      <div class="detail-row">
        <span class="detail-label">Payment Amount</span>
        <span class="detail-value" style="color:#0F4C81;">${amountStr}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Payment Reference</span>
        <span class="detail-value" style="font-family:monospace;font-size:12px;">${paymentRef}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Safepay Tracker</span>
        <span class="detail-value" style="font-family:monospace;font-size:12px;">${tracker}</span>
      </div>
      <div class="detail-row">
        <span class="detail-label">Destination Screen</span>
        <span class="detail-value">${targetLabel}</span>
      </div>
    </div>

    <div class="actions-group">
      <button id="redirectNowBtn" class="btn btn-primary" type="button">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="15 18 9 12 15 6"></polyline>
        </svg>
        Return to WaterFix Now
      </button>
      <button id="checkStatusBtn" class="btn btn-secondary" type="button">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/>
        </svg>
        Check Payment Status
      </button>
      <button id="closeWindowBtn" class="btn btn-secondary" type="button" style="background:transparent;border:1px solid #CBD5E1;color:#64748B;">
        Close Window
      </button>
    </div>
  </div>

  <p class="footer-note">
    WaterFix On-Demand Water Delivery Platform • Safepay Sandbox Integration
  </p>

  <script>
    (function() {
      const paymentRef = "${paymentRef}";
      let status = "${status}";
      const returnTarget = "${returnTarget}";
      let clientOrigin = "${clientOrigin}";

      if (!clientOrigin || clientOrigin === 'null' || clientOrigin === 'undefined' || !clientOrigin.startsWith('http')) {
        const host = window.location.hostname || 'localhost';
        clientOrigin = 'http://' + host + ':3000';
      }

      let countdown = 5;
      let hasRedirected = false;
      let timer = null;

      function performRedirect() {
        if (hasRedirected) return;
        hasRedirected = true;
        if (timer) {
          clearInterval(timer);
          timer = null;
        }

        // 1. Post message to opener window if opened in a popup or tab from WaterFix web
        try {
          if (window.opener && !window.opener.closed) {
            window.opener.postMessage({
              type: 'WATERFIX_PAYMENT_RETURN',
              paymentReference: paymentRef,
              status: status,
              target: returnTarget
            }, '*');
          }
        } catch (_) {}

        // 2. Build target Web URL
        const webDestination = clientOrigin.replace(/\\/+$/, '') + '/?paymentRef=' + encodeURIComponent(paymentRef) +
          '&status=' + encodeURIComponent(status) +
          '&target=' + encodeURIComponent(returnTarget);

        const isMobileDevice = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
        if (isMobileDevice) {
          // Attempt Android deep link
          const deepLink = 'waterfix://payment/return?paymentReference=' + encodeURIComponent(paymentRef) +
            '&status=' + encodeURIComponent(status) +
            '&target=' + encodeURIComponent(returnTarget);
          window.location.href = deepLink;
          setTimeout(function() {
            window.location.href = webDestination;
          }, 600);
          return;
        }

        // On desktop / Chrome: Navigate directly to WaterFix
        window.location.href = webDestination;
      }

      function handleClose() {
        if (timer) {
          clearInterval(timer);
          timer = null;
        }
        window.close();
        // If window.close() is blocked by browser for externally opened tabs,
        // seamlessly redirect to the WaterFix app so the user is never stuck
        setTimeout(function() {
          performRedirect();
        }, 150);
      }

      // Wire up buttons immediately
      const redirectBtn = document.getElementById('redirectNowBtn');
      if (redirectBtn) {
        redirectBtn.addEventListener('click', function(e) {
          e.preventDefault();
          performRedirect();
        });
      }

      const closeBtn = document.getElementById('closeWindowBtn');
      if (closeBtn) {
        closeBtn.addEventListener('click', function(e) {
          e.preventDefault();
          handleClose();
        });
      }

      // Active 5, 4, 3, 2, 1 Countdown
      const numEl = document.getElementById('countdownVal');
      const textEl = document.getElementById('cdTextNum');
      const subEl = document.getElementById('cdSubText');

      timer = setInterval(function() {
        countdown--;
        if (numEl) {
          numEl.textContent = countdown >= 0 ? countdown : '0';
          numEl.classList.add('pop');
          setTimeout(function() { if (numEl) numEl.classList.remove('pop'); }, 180);
        }
        if (textEl) {
          textEl.textContent = countdown >= 0 ? countdown : '0';
        }

        if (countdown <= 0) {
          clearInterval(timer);
          timer = null;
          if (subEl) subEl.textContent = 'Redirecting now...';
          performRedirect();
        }
      }, 1000);

      // Check Payment Status button handler
      const checkStatusBtn = document.getElementById('checkStatusBtn');
      if (checkStatusBtn) {
        checkStatusBtn.addEventListener('click', async function(e) {
          e.preventDefault();
          checkStatusBtn.disabled = true;
          checkStatusBtn.innerHTML = 'Checking Safepay status...';
          try {
            const resp = await fetch('/api/wallet/safepay/status?paymentReference=' + encodeURIComponent(paymentRef));
            const data = await resp.json();
            if (data && data.success && data.data) {
              const liveStatus = data.data.status;
              if (liveStatus === 'paid') {
                status = 'paid';
                const titleEl = document.querySelector('.status-title');
                const explEl = document.querySelector('.status-explanation');
                if (titleEl) {
                  titleEl.textContent = 'Payment confirmed';
                  titleEl.style.color = '#16A34A';
                }
                if (explEl) {
                  explEl.textContent = 'Safepay verified your payment. Commission balance updated successfully.';
                }
                checkStatusBtn.innerHTML = 'Payment Confirmed! Redirecting...';
                setTimeout(performRedirect, 1000);
                return;
              } else if (liveStatus === 'cancelled' || liveStatus === 'failed') {
                status = liveStatus;
                const titleEl = document.querySelector('.status-title');
                const explEl = document.querySelector('.status-explanation');
                if (titleEl) {
                  titleEl.textContent = 'Payment was not completed';
                  titleEl.style.color = '#DC2626';
                }
                if (explEl) {
                  explEl.textContent = 'Transaction was not completed. Outstanding commission balance remains unchanged.';
                }
                checkStatusBtn.innerHTML = 'Transaction Not Completed';
                return;
              }
            }
            checkStatusBtn.innerHTML = 'Status: In Verification (Check Again)';
            checkStatusBtn.disabled = false;
          } catch (_) {
            checkStatusBtn.innerHTML = 'Check Payment Status';
            checkStatusBtn.disabled = false;
          }
        });
      }
    })();
  </script>
</body>
</html>`;
}

/**
 * Handles browser redirect callback/return from Safepay hosted checkout.
 * Routes: GET /api/wallet/safepay/return and GET /api/wallet/safepay/callback
 */
exports.handleSafepayReturn = async (req, res, next) => {
  try {
    const paymentReference =
      req.query.paymentReference || req.query.order_id;
    const tracker = req.query.tracker || req.query.beacon;
    const sig = req.query.sig;
    const reference = req.query.reference;
    const rawOutcome = req.query.status;

    const query = paymentReference ? { paymentReference } : { tracker };
    const payment = await CommissionPayment.findOne(query);

    if (!payment) {
      if (req.headers.accept && req.headers.accept.includes('application/json')) {
        return res.status(404).json({
          success: false,
          message: 'Commission payment record not found.',
        });
      }
      return res.status(404).send(
        renderWaterFixPaymentResultHtml({
          payment: null,
          status: 'error',
          errorMessage:
            'Commission payment session was not found in WaterFix records. Please check your wallet.',
        })
      );
    }

    // Check if supplier explicitly cancelled or failed
    if (
      rawOutcome === 'cancelled' ||
      rawOutcome === 'canceled' ||
      rawOutcome === 'failed'
    ) {
      if (payment.status === 'pending') {
        payment.status = rawOutcome === 'failed' ? 'failed' : 'cancelled';
        if (payment.status === 'failed') {
          payment.failedAt = new Date();
        } else {
          payment.cancelledAt = new Date();
        }
        payment.failureReason = 'Checkout cancelled by supplier.';
        await payment.save();
      }

      if (req.headers.accept && req.headers.accept.includes('application/json')) {
        return res.json({
          success: true,
          message: `Payment marked as ${payment.status}. Commission balance unchanged.`,
          data: {
            paymentReference: payment.paymentReference,
            status: formatPaymentStatus(payment.status),
            rawStatus: payment.status,
          },
        });
      }
      return res.status(200).send(
        renderWaterFixPaymentResultHtml({
          payment,
          status: payment.status,
        })
      );
    }

    const trackerToCheck = payment.tracker || tracker;
    let isVerified = payment.status === 'paid';
    let resolvedProviderRef = reference || trackerToCheck;
    let verifiedVia = payment.verifiedVia || 'redirect_callback';

    if (!isVerified) {
      if (sig) {
        isVerified = safepayService.verifyCallbackSignature({
          tracker: trackerToCheck,
          sig,
        });
        if (isVerified) {
          verifiedVia = 'callback_signature';
        }
      }

      if (!isVerified && trackerToCheck) {
        try {
          const trackerInfo = await safepayService.fetchTrackerStatus(trackerToCheck);
          const paidStates = ['TRACKER_ENDED', 'PAID', 'COMPLETED', 'SUCCEEDED'];
          const stateUpper =
            trackerInfo && trackerInfo.state
              ? String(trackerInfo.state).toUpperCase()
              : '';
          if (
            trackerInfo &&
            paidStates.includes(stateUpper) &&
            (trackerInfo.amount === null ||
              Math.round(Number(trackerInfo.amount)) === Math.round(payment.amount))
          ) {
            isVerified = true;
            resolvedProviderRef = trackerInfo.reference || resolvedProviderRef;
            verifiedVia = 'redirect_order_status';
          }
        } catch (_err) {
          isVerified = false;
        }
      }
    }

    let finalizedResult = null;
    if (isVerified && payment.status === 'pending') {
      finalizedResult = await finalizeVerifiedSafepayPayment({
        payment,
        tracker: trackerToCheck,
        providerReference: resolvedProviderRef,
        verifiedVia,
      });
    }

    const currentStatus = isVerified ? 'paid' : payment.status;

    const latestSupplier = isVerified
      ? await SupplierProfile.findById(payment.supplierId)
      : null;

    if (req.headers.accept && req.headers.accept.includes('application/json')) {
      return res.json({
        success: isVerified,
        message: isVerified
          ? 'Safepay payment verified and commission balance updated.'
          : 'Payment verification is still pending.',
        data: {
          paymentReference: payment.paymentReference,
          tracker: payment.tracker,
          amount: payment.amount,
          status: formatPaymentStatus(currentStatus),
          rawStatus: currentStatus,
          isPaid: currentStatus === 'paid',
          isPending: currentStatus === 'pending',
          returnTarget: payment.returnTarget || 'wallet',
          outstandingCommission: latestSupplier
            ? latestSupplier.outstandingCommission
            : 0,
        },
      });
    }

    return res.status(200).send(
      renderWaterFixPaymentResultHtml({
        payment: finalizedResult ? finalizedResult.payment : payment,
        status: currentStatus,
      })
    );
  } catch (err) {
    next(err);
  }
};

/**
 * Backward compatibility alias for handleSafepayReturn
 */
exports.handleSafepayCallback = exports.handleSafepayReturn;

/**
 * Public authoritative status check endpoint for return page polling.
 * Route: GET /api/wallet/safepay/status
 */
exports.getSafepayPaymentStatus = async (req, res, next) => {
  try {
    const paymentReference =
      req.query.paymentReference || req.query.order_id;
    const tracker = req.query.tracker || req.query.beacon;

    if (!paymentReference && !tracker) {
      return res.status(400).json({
        success: false,
        message: 'paymentReference or tracker is required.',
      });
    }

    const query = paymentReference ? { paymentReference } : { tracker };
    const payment = await CommissionPayment.findOne(query);

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Commission payment record not found.',
      });
    }

    // If still pending, query Safepay Sandbox order status to auto-verify if completed
    if (payment.status === 'pending' && payment.tracker) {
      try {
        const trackerInfo = await safepayService.fetchTrackerStatus(payment.tracker);
        const paidStates = ['TRACKER_ENDED', 'PAID', 'COMPLETED', 'SUCCEEDED'];
        const stateUpper =
          trackerInfo && trackerInfo.state ? String(trackerInfo.state).toUpperCase() : '';
        if (
          trackerInfo &&
          paidStates.includes(stateUpper) &&
          (trackerInfo.amount === null ||
            Math.round(Number(trackerInfo.amount)) === Math.round(payment.amount))
        ) {
          await finalizeVerifiedSafepayPayment({
            payment,
            tracker: payment.tracker,
            providerReference: trackerInfo.reference || payment.tracker,
            verifiedVia: 'status_polling_order_api',
          });
          payment.status = 'paid';
          payment.verifiedAt = new Date();
        }
      } catch (_) {}
    }

    const supplier = await SupplierProfile.findById(payment.supplierId);

    return res.json({
      success: true,
      data: {
        paymentReference: payment.paymentReference,
        tracker: payment.tracker,
        amount: payment.amount,
        currency: payment.currency,
        status: formatPaymentStatus(payment.status),
        rawStatus: payment.status,
        isPaid: payment.status === 'paid',
        isPending: payment.status === 'pending',
        isCancelled: payment.status === 'cancelled',
        isFailed: payment.status === 'failed',
        returnTarget: payment.returnTarget || 'wallet',
        verifiedAt: payment.verifiedAt,
        outstandingCommission: supplier
          ? supplier.outstandingCommission
          : payment.outstandingBefore,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * Handles cancellation or failure of a pending Safepay payment session without deducting debt.
 * Routes: POST /api/wallet/safepay/cancel and GET /api/wallet/safepay/cancel
 */
exports.cancelSafepayPayment = async (req, res, next) => {
  try {
    const paymentReference =
      (req.body && (req.body.paymentReference || req.body.order_id)) ||
      req.query.paymentReference ||
      req.query.order_id;
    const tracker =
      (req.body && (req.body.tracker || req.body.beacon)) ||
      req.query.tracker ||
      req.query.beacon;
    const outcome =
      (req.body && req.body.status) || req.query.status || 'cancelled';
    const reason =
      (req.body && req.body.reason) ||
      req.query.reason ||
      'Payment cancelled by supplier before completion.';

    if (!paymentReference && !tracker) {
      return res.status(400).json({
        success: false,
        message: 'paymentReference or tracker is required.',
      });
    }

    const query = paymentReference ? { paymentReference } : { tracker };
    const payment = await CommissionPayment.findOne(query);

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Commission payment session not found.',
      });
    }

    if (
      req.user &&
      req.user.role === 'supplier' &&
      String(payment.supplierUserId) !== String(req.user._id)
    ) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to modify this payment session.',
      });
    }

    if (payment.status === 'paid') {
      return res.status(400).json({
        success: false,
        message: 'A verified paid commission transaction cannot be cancelled.',
      });
    }

    if (payment.status === 'pending') {
      const nextStatus =
        String(outcome).toLowerCase() === 'failed' ? 'failed' : 'cancelled';
      payment.status = nextStatus;
      if (nextStatus === 'failed') {
        payment.failedAt = new Date();
      } else {
        payment.cancelledAt = new Date();
      }
      payment.failureReason = reason;
      await payment.save();
    }

    const supplier = await SupplierProfile.findById(payment.supplierId);

    if (
      req.method === 'GET' &&
      (!req.headers.accept || !req.headers.accept.includes('application/json'))
    ) {
      return res.status(200).send(`<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>WaterFix - Payment Cancelled</title></head>
<body style="font-family:sans-serif;padding:32px;text-align:center;background:#F4F8FB;color:#0F172A;">
  <div style="max-width:460px;margin:40px auto;background:#fff;padding:28px;border-radius:16px;box-shadow:0 4px 16px rgba(0,0,0,0.08);">
    <h2 style="color:#DC2626;margin-top:0;">Commission Payment Cancelled</h2>
    <p>Payment Reference: <strong>${payment.paymentReference}</strong></p>
    <p>No money was charged and your commission balance remains unchanged.</p>
    <p style="color:#475569;margin-top:20px;">You can close this tab and return to the WaterFix app.</p>
  </div>
</body></html>`);
    }

    return res.json({
      success: true,
      message: `Payment session marked as ${payment.status}. Outstanding commission remains unchanged.`,
      data: {
        paymentReference: payment.paymentReference,
        tracker: payment.tracker,
        status: formatPaymentStatus(payment.status),
        rawStatus: payment.status,
        outstandingCommission: supplier ? supplier.outstandingCommission : payment.outstandingBefore,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * Handles Safepay server-to-server webhooks (`POST /api/wallet/safepay/webhook`).
 * Verifies `X-SFPY-SIGNATURE` HMAC-SHA256 signature and processes events idempotently.
 */
exports.handleSafepayWebhook = async (req, res, next) => {
  try {
    const signature =
      req.headers['x-sfpy-signature'] ||
      req.headers['X-SFPY-SIGNATURE'] ||
      req.headers['x-Safepay-Signature'];

    const isAuthentic = safepayService.verifyWebhookSignature({
      rawBody: req.rawBody,
      parsedBody: req.body,
      signature,
    });

    if (!isAuthentic) {
      return res.status(401).json({
        success: false,
        code: 'INVALID_WEBHOOK_SIGNATURE',
        message: 'Unauthorized webhook: X-SFPY-SIGNATURE verification failed.',
      });
    }

    const payload = req.body || {};
    const data = payload.data && typeof payload.data === 'object' ? payload.data : payload;
    const eventId =
      req.headers['x-sfpy-event-id'] ||
      payload.id ||
      payload.event_id ||
      data.event_id ||
      null;

    const eventType = String(
      payload.type || payload.event || data.state || data.status || ''
    ).toLowerCase();

    const paymentReference =
      data.order_id ||
      data.paymentReference ||
      (data.metadata && (data.metadata.order_id || data.metadata.paymentReference)) ||
      payload.order_id;
    const tracker = data.tracker || data.token || data.beacon || payload.tracker;

    if (!paymentReference && !tracker) {
      return res.status(400).json({
        success: false,
        message: 'Webhook payload missing order_id/paymentReference and tracker.',
      });
    }

    const query = paymentReference ? { paymentReference } : { tracker };
    const payment = await CommissionPayment.findOne(query);

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Matching commission payment session not found.',
      });
    }

    // Idempotency check for duplicate webhook events
    if (eventId && payment.webhookEventIds && payment.webhookEventIds.includes(eventId)) {
      return res.status(200).json({
        success: true,
        alreadyProcessed: true,
        message: 'Webhook event already processed.',
      });
    }

    // Validate amount and currency if present in webhook payload
    if (
      data.amount !== undefined &&
      data.amount !== null &&
      Math.round(Number(data.amount)) !== Math.round(payment.amount)
    ) {
      return res.status(400).json({
        success: false,
        code: 'WEBHOOK_AMOUNT_MISMATCH',
        message: 'Webhook amount does not match payment session amount.',
      });
    }

    if (
      data.currency &&
      String(data.currency).toUpperCase() !== String(payment.currency).toUpperCase()
    ) {
      return res.status(400).json({
        success: false,
        code: 'WEBHOOK_CURRENCY_MISMATCH',
        message: 'Webhook currency does not match payment session currency.',
      });
    }

    const isSuccessEvent =
      eventType.includes('succeeded') ||
      eventType.includes('paid') ||
      eventType.includes('tracker_ended') ||
      eventType.includes('completed');

    const isFailureEvent =
      eventType.includes('failed') ||
      eventType.includes('declined') ||
      eventType.includes('error');

    const isCancelEvent =
      eventType.includes('cancelled') ||
      eventType.includes('canceled') ||
      eventType.includes('abandoned');

    const isExpiredEvent = eventType.includes('expired');

    const isRefundEvent =
      eventType.includes('refund') ||
      eventType.includes('chargeback') ||
      eventType.includes('reversed');

    if (isSuccessEvent) {
      const result = await finalizeVerifiedSafepayPayment({
        payment,
        tracker: tracker || payment.tracker,
        providerReference: data.reference || tracker || payment.tracker,
        verifiedVia: 'webhook',
        webhookEventId: eventId,
      });

      return res.status(200).json({
        success: true,
        alreadyProcessed: result.alreadyProcessed,
        message: 'Webhook processed: commission payment marked as paid.',
        data: {
          paymentReference: result.payment.paymentReference,
          status: 'Paid',
          outstandingCommission: result.supplier
            ? result.supplier.outstandingCommission
            : 0,
        },
      });
    }

    if (isRefundEvent) {
      if (payment.status === 'refunded') {
        return res.status(200).json({
          success: true,
          alreadyProcessed: true,
          message: 'Refund webhook already processed.',
        });
      }

      if (payment.status === 'paid') {
        const supplier = await SupplierProfile.findById(payment.supplierId);
        payment.status = 'refunded';
        payment.refundedAt = new Date();
        if (eventId) payment.webhookEventIds.push(eventId);
        await payment.save();

        const newOutstanding = await reversePaymentAllocations(
          supplier,
          payment,
          `Safepay webhook refund for ${payment.paymentReference}`
        );

        return res.status(200).json({
          success: true,
          message: 'Webhook processed: payment refunded and commission debt restored.',
          data: {
            paymentReference: payment.paymentReference,
            status: 'Refunded',
            outstandingCommission: newOutstanding,
          },
        });
      }
    }

    if (isFailureEvent || isCancelEvent || isExpiredEvent) {
      if (payment.status === 'pending') {
        payment.status = isFailureEvent
          ? 'failed'
          : isExpiredEvent
            ? 'expired'
            : 'cancelled';
        if (isFailureEvent) payment.failedAt = new Date();
        if (isCancelEvent) payment.cancelledAt = new Date();
        payment.failureReason =
          data.reason || data.message || `Safepay webhook status: ${eventType}`;
      }
      if (eventId && !payment.webhookEventIds.includes(eventId)) {
        payment.webhookEventIds.push(eventId);
      }
      await payment.save();

      return res.status(200).json({
        success: true,
        message: `Webhook processed: payment status is ${payment.status}.`,
        data: {
          paymentReference: payment.paymentReference,
          status: formatPaymentStatus(payment.status),
        },
      });
    }

    if (eventId && !payment.webhookEventIds.includes(eventId)) {
      payment.webhookEventIds.push(eventId);
      await payment.save();
    }

    return res.status(200).json({
      success: true,
      message: 'Webhook acknowledged.',
    });
  } catch (err) {
    next(err);
  }
};

/**
 * Authorized manual settlement workflow.
 * A supplier CANNOT mark a commission paid simply by tapping a button without the
 * administrator authorization key (or an admin account).
 */
exports.recordManualSettlement = async (req, res, next) => {
  try {
    const { supplierId, amount, adminAuthorizationKey, notes } = req.body;

    // Verify authorization: either admin role OR valid adminSettlementKey
    const isAdminUser = req.user && req.user.role === 'admin';
    const hasValidAuthKey =
      adminAuthorizationKey && adminAuthorizationKey === env.adminSettlementKey;

    if (!isAdminUser && !hasValidAuthKey) {
      return res.status(403).json({
        success: false,
        message:
          'Unauthorized settlement attempt. Settlements require WaterFix administrator verification and authorization key.',
      });
    }

    let supplier;
    if (supplierId) {
      supplier = await SupplierProfile.findById(supplierId);
    } else {
      supplier = await SupplierProfile.findOne({ userId: req.user._id });
    }

    if (!supplier) {
      return res.status(404).json({
        success: false,
        message: 'Supplier profile not found.',
      });
    }

    const settleAmount = Number(amount);
    if (!settleAmount || settleAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Valid positive settlement amount is required.',
      });
    }

    if (settleAmount > supplier.outstandingCommission) {
      return res.status(400).json({
        success: false,
        message: `Settlement amount (Rs ${settleAmount}) cannot exceed outstanding commission balance (Rs ${supplier.outstandingCommission}).`,
      });
    }

    const previousOutstanding = supplier.outstandingCommission;
    const newOutstanding = previousOutstanding - settleAmount;
    const settlementReference = `STL-${Date.now().toString().slice(-6)}`;

    // Allocate across oldest unpaid commission charges as well
    await allocatePaymentAcrossCommissions(supplier._id, settleAmount);

    const settlement = await SupplierSettlement.create({
      settlementReference,
      supplierId: supplier._id,
      supplierUserId: supplier.userId,
      amountSettled: settleAmount,
      previousOutstanding,
      newOutstanding,
      method: 'Authorized Manual Settlement (Cash/Office Verification)',
      notes: notes || 'Verified manual commission settlement',
      authorizedBy: isAdminUser ? req.user.name : 'WaterFix Finance Admin',
    });

    supplier.outstandingCommission = newOutstanding;
    supplier.totalSettledCommission = (supplier.totalSettledCommission || 0) + settleAmount;
    supplier.lastCommissionPaymentAt = new Date();
    await supplier.save();

    const ledgerEntry = await CommissionLedger.create({
      supplierId: supplier._id,
      supplierUserId: supplier.userId,
      type: 'manual_settlement',
      grossBookingAmount: 0,
      commissionRate: env.commissionRate,
      commissionAmount: -settleAmount,
      paidAmount: settleAmount,
      supplierNetAmount: 0,
      status: 'settled',
      outstandingBalanceAfter: newOutstanding,
      settlementReference,
      referenceNote: `Manual settlement ${settlementReference}: Rs ${settleAmount.toLocaleString()} verified.`,
    });

    await Notification.create({
      userId: supplier.userId,
      type: 'settlement_recorded',
      title: 'Commission settlement recorded',
      body: `Manual settlement ${settlementReference} for Rs ${settleAmount.toLocaleString()} has been recorded. Remaining balance: Rs ${newOutstanding.toLocaleString()}.`,
    });

    res.status(201).json({
      success: true,
      message: 'Authorized manual settlement recorded.',
      data: {
        settlement,
        ledgerEntry,
        outstandingCommission: newOutstanding,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * Admin Commission & Settlement Overview (`GET /api/wallet/admin/overview`).
 * Protected by admin role or `x-admin-key` header / `adminKey` query parameter.
 */
exports.getAdminCommissionOverview = async (req, res, next) => {
  try {
    const isAdminUser = req.user && req.user.role === 'admin';
    const providedKey =
      req.headers['x-admin-key'] ||
      req.query.adminKey ||
      (req.body && req.body.adminAuthorizationKey);
    const hasValidAuthKey = providedKey && providedKey === env.adminSettlementKey;

    if (!isAdminUser && !hasValidAuthKey) {
      return res.status(403).json({
        success: false,
        message: 'Administrator authorization key is required to view platform commission overview.',
      });
    }

    const [suppliers, recentPayments, recentSettlements] = await Promise.all([
      SupplierProfile.find({}).sort({ outstandingCommission: -1 }),
      CommissionPayment.find({}).sort({ createdAt: -1 }).limit(50),
      SupplierSettlement.find({}).sort({ createdAt: -1 }).limit(30),
    ]);

    const totalOutstandingCommissions = suppliers.reduce(
      (sum, s) => sum + (s.outstandingCommission || 0),
      0
    );
    const totalVerifiedPayments = suppliers.reduce(
      (sum, s) => sum + (s.totalSettledCommission || 0),
      0
    );
    const totalCommissionGenerated = suppliers.reduce(
      (sum, s) => sum + (s.totalCommissionCharged || 0),
      0
    );
    const pendingPaymentsCount = recentPayments.filter(
      (p) => p.status === 'pending'
    ).length;
    const failedOrCancelledCount = recentPayments.filter((p) =>
      ['failed', 'cancelled', 'expired'].includes(p.status)
    ).length;

    const supplierBalances = suppliers.map((s) => ({
      supplierId: s._id,
      businessName: s.businessName,
      totalGrossEarnings: s.totalGrossEarnings || 0,
      totalCommissionCharged: s.totalCommissionCharged || 0,
      outstandingCommission: s.outstandingCommission || 0,
      totalSettledCommission: s.totalSettledCommission || 0,
      status:
        (s.outstandingCommission || 0) === 0
          ? 'Paid'
          : (s.totalSettledCommission || 0) > 0
            ? 'Partially Paid'
            : 'Outstanding',
    }));

    return res.json({
      success: true,
      data: {
        totals: {
          totalCommissionGenerated,
          totalOutstandingCommissions,
          totalVerifiedPayments,
          pendingPaymentsCount,
          failedOrCancelledCount,
          supplierCount: suppliers.length,
        },
        supplierBalances,
        recentPayments: recentPayments.map((p) => ({
          paymentReference: p.paymentReference,
          supplierId: p.supplierId,
          amount: p.amount,
          currency: p.currency,
          provider: p.provider,
          tracker: p.tracker,
          status: formatPaymentStatus(p.status),
          rawStatus: p.status,
          createdAt: p.createdAt,
          verifiedAt: p.verifiedAt,
        })),
        recentSettlements,
      },
    });
  } catch (err) {
    next(err);
  }
};
