const crypto = require('crypto');
const env = require('../config/env');

let customHttpClient = null;

/**
 * Allows unit/integration tests to inject a deterministic HTTP client
 * without modifying production logic.
 */
function setHttpClient(clientFn) {
  customHttpClient = clientFn;
}

function resetHttpClient() {
  customHttpClient = null;
}

function getSafepayConfig() {
  const apiKey = (process.env.SAFEPAY_API_KEY || env.safepayApiKey || '').trim();
  const secretKey = (process.env.SAFEPAY_SECRET_KEY || env.safepaySecretKey || '').trim();
  const webhookSecret = (
    process.env.SAFEPAY_WEBHOOK_SECRET ||
    env.safepayWebhookSecret ||
    secretKey
  ).trim();
  const environment = (process.env.SAFEPAY_ENV || env.safepayEnv || 'sandbox').toLowerCase();
  const baseUrl = (
    process.env.SAFEPAY_BASE_URL ||
    env.safepayBaseUrl ||
    'https://sandbox.api.getsafepay.com'
  ).replace(/\/+$/, '');
  const checkoutBaseUrl = (
    process.env.SAFEPAY_CHECKOUT_BASE_URL ||
    env.safepayCheckoutBaseUrl ||
    'https://sandbox.api.getsafepay.com/checkout/pay'
  )
    .replace(/\/+$/, '')
    .replace(/\/components$/, '/checkout/pay');
  const redirectUrl =
    process.env.SAFEPAY_REDIRECT_URL ||
    env.safepayRedirectUrl ||
    'http://localhost:5000/api/wallet/safepay/callback';
  const cancelUrl =
    process.env.SAFEPAY_CANCEL_URL ||
    env.safepayCancelUrl ||
    'http://localhost:5000/api/wallet/safepay/cancel';

  return {
    apiKey,
    secretKey,
    webhookSecret,
    environment: environment === 'sandbox' ? 'sandbox' : 'sandbox', // Enforce TEST MODE only
    baseUrl,
    checkoutBaseUrl,
    redirectUrl,
    cancelUrl,
    configured: env.isSafepayConfigured(),
  };
}

function safeHexEqual(a, b) {
  if (!a || !b || typeof a !== 'string' || typeof b !== 'string') {
    return false;
  }
  const cleanA = a.trim().toLowerCase();
  const cleanB = b.trim().toLowerCase();
  if (cleanA.length !== cleanB.length || cleanA.length === 0) {
    return false;
  }
  try {
    const bufA = Buffer.from(cleanA, 'utf8');
    const bufB = Buffer.from(cleanB, 'utf8');
    if (bufA.length !== bufB.length) return false;
    return crypto.timingSafeEqual(bufA, bufB);
  } catch (_err) {
    return false;
  }
}

/**
 * Computes Safepay callback HMAC-SHA256 signature over the tracker token.
 */
function signTracker(tracker, secretOverride) {
  const { secretKey } = getSafepayConfig();
  const keyToUse = secretOverride || secretKey;
  if (!keyToUse || !tracker) return '';
  return crypto.createHmac('sha256', keyToUse).update(String(tracker)).digest('hex');
}

/**
 * Verifies the `sig` parameter returned by Safepay hosted checkout redirect/callback.
 * Official Safepay specification: HMAC-SHA256(tracker, SAFEPAY_SECRET_KEY)
 */
function verifyCallbackSignature({ tracker, sig }) {
  const config = getSafepayConfig();
  if (!config.configured || !config.secretKey) {
    return false;
  }
  if (!tracker || !sig) {
    return false;
  }
  const expectedSig = signTracker(tracker, config.secretKey);
  return safeHexEqual(expectedSig, sig);
}

/**
 * Verifies the `X-SFPY-SIGNATURE` header sent on Safepay webhook notifications.
 * Supports both Safepay v1 (HMAC-SHA256 of JSON.stringify(body.data)) and
 * raw body HMAC-SHA256 using SAFEPAY_WEBHOOK_SECRET (or SAFEPAY_SECRET_KEY fallback).
 */
function verifyWebhookSignature({ rawBody, parsedBody, signature }) {
  const config = getSafepayConfig();
  const secret = config.webhookSecret || config.secretKey;
  if (!secret || !signature) {
    return false;
  }

  const candidates = [];
  if (typeof rawBody === 'string' && rawBody.length > 0) {
    candidates.push(
      crypto.createHmac('sha256', secret).update(rawBody, 'utf8').digest('hex')
    );
  }
  if (parsedBody && typeof parsedBody === 'object') {
    if (parsedBody.data && typeof parsedBody.data === 'object') {
      candidates.push(
        crypto
          .createHmac('sha256', secret)
          .update(JSON.stringify(parsedBody.data), 'utf8')
          .digest('hex')
      );
    }
    candidates.push(
      crypto
        .createHmac('sha256', secret)
        .update(JSON.stringify(parsedBody), 'utf8')
        .digest('hex')
    );
  }

  return candidates.some((expected) => safeHexEqual(expected, signature));
}

async function performRequest(url, options = {}, retries = 1) {
  if (typeof customHttpClient === 'function') {
    return customHttpClient(url, options);
  }

  const timeoutMs = options.timeoutMs || 15000;
  let attempt = 0;
  let lastError = null;

  while (attempt <= retries) {
    attempt++;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
      });
      clearTimeout(timer);
      const text = await response.text();
      let json = null;
      try {
        json = text ? JSON.parse(text) : null;
      } catch (_err) {
        json = null;
      }
      return {
        ok: response.ok,
        status: response.status,
        data: json,
        rawText: text,
      };
    } catch (err) {
      clearTimeout(timer);
      lastError = err;
      const isAbort = err.name === 'AbortError';
      const isSocket =
        err.name === 'TypeError' ||
        err.code === 'ECONNRESET' ||
        err.code === 'ETIMEDOUT' ||
        (err.cause && (err.cause.code === 'ECONNRESET' || err.cause.code === 'ETIMEDOUT'));

      if (attempt <= retries && (isAbort || isSocket)) {
        await new Promise((resolve) => setTimeout(resolve, 500));
        continue;
      }
      break;
    }
  }

  // Unpack underlying causes (e.g., DNS lookup failure, connection timeout)
  // to prevent raw, unhelpful "fetch failed" errors.
  const causeCode = lastError?.cause?.code || lastError?.code || '';
  const causeMsg =
    lastError?.cause?.message || lastError?.message || 'Gateway network error';
  const diagnostic = causeCode ? `${causeMsg} (${causeCode})` : causeMsg;

  // Safe logging: log endpoint without query string or secrets
  console.error(
    `[Safepay Gateway] HTTP request to ${url.split('?')[0]} failed: ${diagnostic}`
  );

  const friendlyError = new Error(
    `Unable to connect to Safepay sandbox gateway: ${diagnostic}. Please verify your network connection and try again.`
  );
  friendlyError.code = 'SAFEPAY_NETWORK_ERROR';
  friendlyError.statusCode = 502;
  friendlyError.originalError = lastError;
  throw friendlyError;
}

/**
 * Initializes a Safepay Sandbox order tracker (`POST /order/v1/init`) and constructs
 * the official Safepay hosted checkout URL (`https://sandbox.api.getsafepay.com/checkout/pay?...`).
 */
async function createCheckoutSession({
  amount,
  currency = 'PKR',
  paymentReference,
  redirectUrl,
  cancelUrl,
  returnTarget = 'wallet',
}) {
  const config = getSafepayConfig();

  if (!config.configured) {
    const err = new Error(
      'Safepay Test Mode credentials are not configured yet. Please add your SAFEPAY_API_KEY and SAFEPAY_SECRET_KEY in APP/backend/.env and restart the backend server.'
    );
    err.code = 'SAFEPAY_CREDENTIALS_MISSING';
    err.statusCode = 503;
    throw err;
  }

  const initUrl = `${config.baseUrl}/order/v1/init`;
  const payload = {
    client: config.apiKey,
    amount: Number(amount),
    currency: String(currency || 'PKR').toUpperCase(),
    environment: 'sandbox',
  };

  const result = await performRequest(initUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!result.ok || !result.data || !result.data.data || !result.data.data.token) {
    const upstreamMsg =
      (result.data &&
        result.data.status &&
        Array.isArray(result.data.status.errors) &&
        result.data.status.errors.join(', ')) ||
      (result.data && result.data.message) ||
      `Safepay sandbox order initialization failed (HTTP ${result.status || 502}).`;
    const err = new Error(upstreamMsg);
    err.code = 'SAFEPAY_UPSTREAM_ERROR';
    err.statusCode = 502;
    throw err;
  }

  const tracker = result.data.data.token;
  const finalRedirect = redirectUrl || config.redirectUrl;
  const finalCancel = cancelUrl || config.cancelUrl;

  const separatorCancel = finalCancel.includes('?') ? '&' : '?';
  const cancelWithRef = `${finalCancel}${separatorCancel}paymentReference=${encodeURIComponent(paymentReference)}&target=${encodeURIComponent(returnTarget)}`;

  const separatorRedirect = finalRedirect.includes('?') ? '&' : '?';
  const redirectWithRef = `${finalRedirect}${separatorRedirect}paymentReference=${encodeURIComponent(paymentReference)}&target=${encodeURIComponent(returnTarget)}`;

  // Safepay's hosted checkout query parameters
  const query = new URLSearchParams({
    env: 'sandbox',
    beacon: tracker,
    source: 'custom',
    order_id: paymentReference,
    webhooks: 'true',
    redirect_url: redirectWithRef,
    cancel_url: cancelWithRef,
  });

  const checkoutUrl = `${config.checkoutBaseUrl}?${query.toString()}`;

  return {
    tracker,
    checkoutUrl,
    environment: 'sandbox',
    currency: payload.currency,
    amount: payload.amount,
    redirectUrl: redirectWithRef,
    cancelUrl: cancelWithRef,
  };
}

/**
 * Queries Safepay Order API (`GET /order/v1/:tracker`) to verify
 * tracker status directly from Safepay Sandbox (`TRACKER_STARTED`, `TRACKER_ENDED`, `TRACKER_CANCELLED`, etc.).
 */
async function fetchTrackerStatus(tracker) {
  const config = getSafepayConfig();
  if (!config.configured) {
    const err = new Error('Safepay Test Mode credentials are not configured.');
    err.code = 'SAFEPAY_CREDENTIALS_MISSING';
    err.statusCode = 503;
    throw err;
  }

  try {
    const url = `${config.baseUrl}/order/v1/${encodeURIComponent(tracker)}`;
    const result = await performRequest(url, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
      },
    });

    if (!result.ok || !result.data) {
      return null;
    }

    const beaconData = result.data.data || result.data;
    const txn = beaconData.transaction || null;
    return {
      state: beaconData.state || beaconData.status || null,
      amount: beaconData.amount !== undefined ? Number(beaconData.amount) : null,
      currency: beaconData.currency || 'PKR',
      reference:
        (txn && (txn.reference || txn.token)) ||
        beaconData.reference ||
        beaconData.token ||
        tracker,
      raw: beaconData,
    };
  } catch (err) {
    console.warn(`[Safepay] Could not query tracker status (${tracker}): ${err.message}`);
    return null;
  }
}

module.exports = {
  getSafepayConfig,
  setHttpClient,
  resetHttpClient,
  signTracker,
  verifyCallbackSignature,
  verifyWebhookSignature,
  createCheckoutSession,
  fetchTrackerStatus,
};
