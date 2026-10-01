/// A user-friendly error. The [message] is safe to show directly in the UI.
class AppException implements Exception {
  AppException(this.message);
  final String message;

  @override
  String toString() => message;
}
