/// Form validators shared by all screens. Return null when valid.
class Validators {
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? name(String? v) {
    if (v == null || v.trim().length < 2) return 'Enter your name';
    return null;
  }

  static String? incident(String? v) {
    if (v == null || v.trim().length < 10) {
      return 'Please describe what happened (at least 10 characters)';
    }
    return null;
  }
}
