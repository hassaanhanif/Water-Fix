class AppValidators {
  static String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  static bool isValidEmail(String email) {
    final normalized = normalizeEmail(email);
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(normalized);
  }

  static String normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.startsWith('0092')) {
      cleaned = '+92${cleaned.substring(4)}';
    } else if (cleaned.startsWith('92') && cleaned.length == 12) {
      cleaned = '+$cleaned';
    } else if (cleaned.startsWith('03') && cleaned.length == 11) {
      cleaned = '+92${cleaned.substring(1)}';
    } else if (cleaned.startsWith('3') && cleaned.length == 10) {
      cleaned = '+92$cleaned';
    } else if (!cleaned.startsWith('+') &&
        RegExp(r'^\d{10,15}$').hasMatch(cleaned)) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  static bool isValidPhone(String phone) {
    final normalized = normalizePhone(phone);
    if (normalized.startsWith('+92')) {
      return RegExp(r'^\+923\d{9}$').hasMatch(normalized);
    }
    return RegExp(r'^\+\d{10,15}$').hasMatch(normalized);
  }

  static String? validateIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address or phone number';
    }
    final trimmed = value.trim();
    if (trimmed.contains('@')) {
      if (!isValidEmail(trimmed)) {
        return 'Please enter a valid email address';
      }
      return null;
    } else {
      if (!isValidPhone(trimmed)) {
        return 'Enter a valid Pakistani phone (e.g. 03001234567 or +923001234567)';
      }
      return null;
    }
  }

  static String? validateEmailField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    if (!isValidEmail(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePhoneField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (!isValidPhone(value)) {
      return 'Enter a valid phone (e.g. +92 300 1234567 or 03001234567)';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Password must include at least one letter and one number';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static bool isValidCnic(String? cnic) {
    if (cnic == null || cnic.trim().isEmpty) return false;
    final digitsOnly = cnic.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length == 13;
  }

  static String normalizeCnic(String cnic) {
    final digitsOnly = cnic.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 13) return cnic.trim();
    return '${digitsOnly.substring(0, 5)}-${digitsOnly.substring(5, 12)}-${digitsOnly.substring(12)}';
  }

  static String maskCnic(String? cnic) {
    if (cnic == null || cnic.trim().isEmpty) return 'Not provided';
    final norm = normalizeCnic(cnic);
    if (norm.length == 15 && norm[5] == '-' && norm[13] == '-') {
      return '${norm.substring(0, 6)}*******${norm.substring(13)}';
    }
    return '************';
  }

  static String? validateCnic(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '13-digit CNIC is required for verification';
    }
    if (!isValidCnic(value)) {
      return 'Enter a valid 13-digit Pakistani CNIC (e.g. 35201-1234567-1)';
    }
    return null;
  }

  static Map<String, int> calculateCommissionBreakdown(
    int grossAmount, {
    double rate = 0.10,
  }) {
    final commission = (grossAmount * rate).round();
    final netEarnings = grossAmount - commission;
    return {'gross': grossAmount, 'commission': commission, 'net': netEarnings};
  }
}
