enum AuthenticationStatus { unknown, authenticated, unauthenticated }

/// Authentication providers required by the product. Credentials are never
/// represented as profile data or persisted by this application.
enum AuthenticationMethod { google, emailPassword, phoneOtp }

class AuthSession {
  const AuthSession({required this.status, this.userId});

  final AuthenticationStatus status;
  final String? userId;
}
