function normalizeEmail(email) {
  if (!email || typeof email !== 'string') return '';
  return email.trim().toLowerCase();
}

function isValidEmail(email) {
  const normalized = normalizeEmail(email);
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(normalized);
}

/**
 * Normalizes Pakistani phone numbers to +923XXXXXXXXX format,
 * or general international numbers to +<digits>.
 */
function normalizePhone(phone) {
  if (!phone || typeof phone !== 'string') return '';
  let cleaned = phone.replace(/[\s\-()]/g, '');
  if (cleaned.startsWith('0092')) {
    cleaned = '+92' + cleaned.slice(4);
  } else if (cleaned.startsWith('92') && cleaned.length === 12) {
    cleaned = '+' + cleaned;
  } else if (cleaned.startsWith('03') && cleaned.length === 11) {
    cleaned = '+92' + cleaned.slice(1);
  } else if (cleaned.startsWith('3') && cleaned.length === 10) {
    cleaned = '+92' + cleaned;
  } else if (!cleaned.startsWith('+') && /^\d{10,15}$/.test(cleaned)) {
    cleaned = '+' + cleaned;
  }
  return cleaned;
}

function isValidPhone(phone) {
  const normalized = normalizePhone(phone);
  // Pakistani mobile format +923XXXXXXXXX (13 chars) or general E.164 (+ followed by 10-15 digits)
  if (normalized.startsWith('+92')) {
    return /^\+923\d{9}$/.test(normalized);
  }
  return /^\+\d{10,15}$/.test(normalized);
}

function validatePasswordStrength(password) {
  if (!password || typeof password !== 'string') {
    return { valid: false, message: 'Password is required.' };
  }
  if (password.length < 8) {
    return { valid: false, message: 'Password must be at least 8 characters long.' };
  }
  if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return { valid: false, message: 'Password must contain at least one letter and one number.' };
  }
  return { valid: true };
}

function isEmailIdentifier(identifier) {
  if (!identifier || typeof identifier !== 'string') return false;
  return identifier.includes('@');
}

/**
 * Validates 13-digit Pakistani CNIC format (e.g., 35201-1234567-1 or 3520112345671).
 */
function isValidCnic(cnic) {
  if (!cnic || typeof cnic !== 'string') return false;
  const digitsOnly = cnic.replace(/\D/g, '');
  return digitsOnly.length === 13;
}

/**
 * Normalizes CNIC to standard XXXXX-XXXXXXX-X format.
 */
function normalizeCnic(cnic) {
  if (!cnic || typeof cnic !== 'string') return '';
  const digitsOnly = cnic.replace(/\D/g, '');
  if (digitsOnly.length !== 13) return cnic.trim();
  return `${digitsOnly.slice(0, 5)}-${digitsOnly.slice(5, 12)}-${digitsOnly.slice(12)}`;
}

/**
 * Safely masks CNIC for summaries and non-admin display (e.g. 35201-*******-1).
 */
function maskCnic(cnic) {
  if (!cnic) return 'Not provided';
  const norm = normalizeCnic(cnic);
  if (norm.length === 15 && norm[5] === '-' && norm[13] === '-') {
    return `${norm.slice(0, 6)}*******${norm.slice(13)}`;
  }
  return '************';
}

module.exports = {
  normalizeEmail,
  isValidEmail,
  normalizePhone,
  isValidPhone,
  validatePasswordStrength,
  isEmailIdentifier,
  isValidCnic,
  normalizeCnic,
  maskCnic,
};
