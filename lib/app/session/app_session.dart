import 'package:coworkplace/features/profile/domain/user_profile.dart';

class AppSession {
  const AppSession._({
    required this.isAuthenticated,
    required this.userId,
    required this.profile,
  });

  const AppSession.unauthenticated()
    : this._(isAuthenticated: false, userId: null, profile: null);

  const AppSession.authenticated({required String userId, UserProfile? profile})
    : this._(isAuthenticated: true, userId: userId, profile: profile);

  final bool isAuthenticated;
  final String? userId;
  final UserProfile? profile;

  bool get hasProfile {
    return profile != null;
  }
}
