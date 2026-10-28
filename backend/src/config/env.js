const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const PLACEHOLDER_MARKERS = [
  'replace_with_your',
  'your_safepay',
  'placeholder',
  'changeme',
];

function isRealSecret(value) {
  if (!value || typeof value !== 'string') return false;
  const trimmed = value.trim();
  if (!trimmed) return false;
  const lower = trimmed.toLowerCase();
  return !PLACEHOLDER_MARKERS.some((marker) => lower.includes(marker));
}

const env = {
  port: process.env.PORT || 5000,
  mongoUri: process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/waterfix_db',
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET || 'waterfix_local_dev_access_secret_key_2026_secure',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || 'waterfix_local_dev_refresh_secret_key_2026_secure',
  jwtAccessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '1h',
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  commissionRate: parseFloat(process.env.COMMISSION_RATE || '0.10'),
  adminSettlementKey: process.env.ADMIN_SETTLEMENT_KEY || 'waterfix_admin_settlement_secret_2026',
  adminEmail: (process.env.ADMIN_EMAIL || 'admin@waterfix.pk').trim().toLowerCase(),
  adminPassword: process.env.ADMIN_PASSWORD || 'AdminPass123!',
  adminPhone: (process.env.ADMIN_PHONE || '+923000000000').trim(),
  adminName: (process.env.ADMIN_NAME || 'WaterFix Administrator').trim(),
  nodeEnv: process.env.NODE_ENV || 'development',

  // Safepay Test Mode Configuration
  safepayEnv: (process.env.SAFEPAY_ENV || 'sandbox').toLowerCase(),
  safepayApiKey: (process.env.SAFEPAY_API_KEY || '').trim(),
  safepaySecretKey: (process.env.SAFEPAY_SECRET_KEY || '').trim(),
  safepayWebhookSecret: (process.env.SAFEPAY_WEBHOOK_SECRET || '').trim(),
  safepayBaseUrl: (process.env.SAFEPAY_BASE_URL || 'https://sandbox.api.getsafepay.com').replace(/\/+$/, ''),
  safepayCheckoutBaseUrl: (
    process.env.SAFEPAY_CHECKOUT_BASE_URL || 'https://sandbox.api.getsafepay.com/checkout/pay'
  )
    .replace(/\/+$/, '')
    .replace(/\/components$/, '/checkout/pay'),
  safepayRedirectUrl:
    process.env.SAFEPAY_REDIRECT_URL || 'http://localhost:5000/api/wallet/safepay/callback',
  safepayCancelUrl:
    process.env.SAFEPAY_CANCEL_URL || 'http://localhost:5000/api/wallet/safepay/cancel',

  // Groq AI Recommendations Configuration
  groqApiKey: (process.env.GROQ_API_KEY || '').trim(),
  groqModel: process.env.GROQ_MODEL || 'openai/gpt-oss-20b',

  // Brevo SMTP Email Configuration
  smtpHost: (process.env.SMTP_HOST || 'smtp-relay.brevo.com').trim(),
  smtpPort: parseInt(process.env.SMTP_PORT || '587', 10),
  smtpUsername: (process.env.SMTP_USERNAME || '').trim(),
  smtpPassword: (process.env.SMTP_PASSWORD || '').trim(),
  smtpFromEmail: (process.env.SMTP_FROM_EMAIL || 'support@waterfix.pk').trim(),

  isSafepayConfigured() {
    const apiKey = (process.env.SAFEPAY_API_KEY || this.safepayApiKey || '').trim();
    const secretKey = (process.env.SAFEPAY_SECRET_KEY || this.safepaySecretKey || '').trim();
    return isRealSecret(apiKey) && isRealSecret(secretKey);
  },

  isGroqConfigured() {
    const apiKey = (process.env.GROQ_API_KEY || this.groqApiKey || '').trim();
    return isRealSecret(apiKey);
  },

  isSmtpConfigured() {
    const username = (process.env.SMTP_USERNAME || this.smtpUsername || '').trim();
    const password = (process.env.SMTP_PASSWORD || this.smtpPassword || '').trim();
    return isRealSecret(username) && isRealSecret(password);
  },
};

module.exports = env;
