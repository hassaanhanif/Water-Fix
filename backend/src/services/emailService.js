const nodemailer = require('nodemailer');
const crypto = require('crypto');
const env = require('../config/env');

/**
 * Generates a cryptographically secure 6-digit OTP string.
 */
function generateSecureOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

/**
 * Creates a deterministic SHA-256 hash of an OTP for secure storage.
 */
function hashOtp(otp) {
  return crypto.createHash('sha256').update(String(otp).trim()).digest('hex');
}

/**
 * Instantiates a configured Nodemailer SMTP transport for Brevo.
 */
function getTransporter() {
  return nodemailer.createTransport({
    host: env.smtpHost,
    port: env.smtpPort,
    secure: env.smtpPort === 465,
    auth: {
      user: env.smtpUsername,
      pass: env.smtpPassword,
    },
    tls: {
      rejectUnauthorized: env.nodeEnv === 'production',
    },
    connectionTimeout: 10000,
  });
}

/**
 * Sends a transactional 6-digit email OTP via Brevo SMTP.
 */
async function sendOtpEmail({ to, name, otp }) {
  if (!to || !otp) {
    throw new Error('Recipient email and OTP are required.');
  }

  const recipientName = name ? name.trim() : 'WaterFix Member';
  const fromEmail = env.smtpFromEmail || 'support@waterfix.pk';

  const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #F4F8FB; margin: 0; padding: 24px; color: #0F172A; }
    .container { max-width: 520px; margin: 0 auto; background: #FFFFFF; border-radius: 20px; overflow: hidden; border: 1px solid #E2E8F0; box-shadow: 0 4px 16px rgba(0,0,0,0.04); }
    .header { background: #0F172A; padding: 28px 24px; text-align: center; }
    .logo-text { font-size: 26px; font-weight: 800; color: #FFFFFF; letter-spacing: -0.5px; }
    .logo-accent { color: #00A896; }
    .content { padding: 32px 28px; text-align: center; }
    .title { font-size: 22px; font-weight: 800; color: #0F172A; margin-bottom: 12px; }
    .body-text { font-size: 15px; line-height: 1.55; color: #475569; margin-bottom: 24px; }
    .otp-card { background: #E6FFFA; border: 2px dashed #00A896; border-radius: 16px; padding: 20px; margin: 0 auto 24px auto; display: inline-block; }
    .otp-code { font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #0F4C81; font-family: 'Courier New', monospace; margin: 0; }
    .expiry-note { font-size: 13px; font-weight: 600; color: #64748B; margin-top: 8px; }
    .security-note { font-size: 12.5px; color: #94A3B8; line-height: 1.5; padding: 16px; background: #F8FAFC; border-radius: 12px; margin-top: 20px; }
    .footer { padding: 20px 24px; background: #F8FAFC; text-align: center; font-size: 12px; color: #94A3B8; border-top: 1px solid #F1F5F9; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo-text">Water<span class="logo-accent">Fix</span></div>
    </div>
    <div class="content">
      <h1 class="title">Verify Your Email Address</h1>
      <p class="body-text">
        Hello <strong>${recipientName}</strong>,<br>
        Thank you for registering with WaterFix. Please use the verification code below to verify your email and proceed to account approval:
      </p>
      <div class="otp-card">
        <div class="otp-code">${otp}</div>
        <div class="expiry-note">Valid for 5 minutes</div>
      </div>
      <div class="security-note">
        <strong>Security Notice:</strong> Never share this code with anyone. WaterFix staff will never ask for your verification code.
      </div>
    </div>
    <div class="footer">
      WaterFix On-Demand Water Delivery Marketplace • Islamabad, Pakistan
    </div>
  </div>
</body>
</html>`;

  if (!env.isSmtpConfigured()) {
    console.log(`[WaterFix Brevo Email] SMTP credentials not set in .env. Queued OTP email to ${to}.`);
    return {
      success: true,
      simulated: true,
      messageId: `simulated-${Date.now()}`,
    };
  }

  const transporter = getTransporter();
  const info = await transporter.sendMail({
    from: `"WaterFix Platform" <${fromEmail}>`,
    to,
    subject: `Your WaterFix Verification Code: ${otp}`,
    text: `Your WaterFix email verification code is: ${otp}. It expires in 5 minutes. Do not share this code.`,
    html: htmlContent,
  });

  return {
    success: true,
    simulated: false,
    messageId: info.messageId,
  };
}

/**
 * Sends a decision notification email upon admin approval or rejection.
 */
async function sendDecisionEmail({ to, name, role, isApproved, reason }) {
  if (!to) return null;
  const recipientName = name ? name.trim() : 'WaterFix Member';
  const roleLabel = role === 'supplier' ? 'Water Supplier' : 'Customer';
  const fromEmail = env.smtpFromEmail || 'support@waterfix.pk';

  const subject = isApproved
    ? `Welcome! Your WaterFix ${roleLabel} Account has been Approved`
    : `Update Regarding Your WaterFix ${roleLabel} Application`;

  const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #F4F8FB; margin: 0; padding: 24px; color: #0F172A; }
    .container { max-width: 520px; margin: 0 auto; background: #FFFFFF; border-radius: 20px; overflow: hidden; border: 1px solid #E2E8F0; }
    .header { background: #0F172A; padding: 24px; text-align: center; }
    .logo-text { font-size: 24px; font-weight: 800; color: #FFFFFF; }
    .logo-accent { color: #00A896; }
    .content { padding: 32px 28px; }
    .title { font-size: 20px; font-weight: 800; color: ${isApproved ? '#0F766E' : '#B91C1C'}; margin-bottom: 12px; }
    .body-text { font-size: 15px; line-height: 1.6; color: #475569; }
    .footer { padding: 18px 24px; background: #F8FAFC; text-align: center; font-size: 12px; color: #94A3B8; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo-text">Water<span class="logo-accent">Fix</span></div>
    </div>
    <div class="content">
      <h1 class="title">${isApproved ? 'Application Approved!' : 'Application Decision'}</h1>
      <p class="body-text">
        Hello <strong>${recipientName}</strong>,<br><br>
        ${
          isApproved
            ? `Your ${roleLabel} account application and CNIC details have been reviewed and approved by the WaterFix administrator. You can now sign in and access all platform features.`
            : `Your ${roleLabel} account application could not be approved at this time.${
                reason ? `<br><br><strong>Reason:</strong> ${reason}` : ''
              }<br><br>Please contact our support team at ${fromEmail} if you have any questions.`
        }
      </p>
    </div>
    <div class="footer">
      WaterFix On-Demand Water Delivery Marketplace
    </div>
  </div>
</body>
</html>`;

  if (!env.isSmtpConfigured()) {
    console.log(`[WaterFix Brevo Email] SMTP not configured. Notification email to ${to}: ${subject}`);
    return { success: true, simulated: true };
  }

  try {
    const transporter = getTransporter();
    const info = await transporter.sendMail({
      from: `"WaterFix Platform" <${fromEmail}>`,
      to,
      subject,
      html: htmlContent,
    });
    return { success: true, messageId: info.messageId };
  } catch (err) {
    console.warn('[WaterFix Brevo Email] Failed sending decision email:', err.message);
    return null;
  }
}

module.exports = {
  generateSecureOtp,
  hashOtp,
  sendOtpEmail,
  sendDecisionEmail,
};
