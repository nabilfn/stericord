class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Named AppAuthException (not AuthException) to avoid colliding with
/// supabase_flutter's own AuthException type when both are imported together.
class AppAuthException extends AppException {
  const AppAuthException(super.message);
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}
