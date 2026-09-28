/// Every rule here mirrors a real backend constraint (see
/// app/schemas/auth.py and app/services/pan_verification.py in the
/// inpockets-main backend) so the user gets instant feedback instead of
/// a round trip to discover their input was invalid.
class Validators {
  Validators._();

  static final RegExp _panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

  /// Matches RequestOTPRequest.validate_phone_number: exactly 10 digits,
  /// starting with 6, 7, 8, or 9.
  static String? phoneNumber(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your mobile number';
    if (v.length != 10 || !RegExp(r'^\d{10}$').hasMatch(v)) {
      return 'Enter a valid 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]').hasMatch(v)) {
      return 'Enter a valid Indian mobile number';
    }
    return null;
  }

  static String? otp(String? value, {int length = 6}) {
    final v = value?.trim() ?? '';
    if (v.length != length || !RegExp(r'^\d+$').hasMatch(v)) {
      return 'Enter the $length-digit code';
    }
    return null;
  }

  /// Matches PAN_PATTERN in app/services/pan_verification.py.
  static String? pan(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return 'Enter your PAN number';
    if (!_panPattern.hasMatch(v)) {
      return 'PAN should look like ABCDE1234F';
    }
    return null;
  }

  static String? requiredName(String? value, {String field = 'This field'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field is required';
    if (v.length < 2) return '$field looks too short';
    if (!RegExp(r"^[A-Za-z .'-]+$").hasMatch(v)) {
      return '$field can only contain letters';
    }
    return null;
  }

  /// NOTE: the backend today only enforces `requested_amount > 0` — it has
  /// no published min/max. These bounds are a client-side UX guardrail
  /// only; tune them (or wire them to a future /loan-products endpoint)
  /// once product/risk sets real limits.
  static String? loanAmount(String? value, {double min = 1000, double max = 500000}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter an amount';
    final amount = double.tryParse(v);
    if (amount == null || amount <= 0) return 'Enter a valid amount';
    if (amount < min) return 'Minimum amount is ₹${min.toStringAsFixed(0)}';
    if (amount > max) return 'Maximum amount is ₹${max.toStringAsFixed(0)}';
    return null;
  }
}
