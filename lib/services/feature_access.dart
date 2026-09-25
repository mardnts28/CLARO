import 'package:firebase_auth/firebase_auth.dart';
import 'guest_session.dart';

enum FeatureKey { history, profile, personalizedAdvisory, healthRanking }

enum FeatureAccessReason { guest, noProfile }

class FeatureAccessResult {
  const FeatureAccessResult({required this.allowed, this.reason});

  final bool allowed;
  final FeatureAccessReason? reason;
}

/// Central feature gate used by screens before rendering account-only content.
FeatureAccessResult useFeatureAccess(
  FeatureKey featureKey, {
  bool? isProfileComplete,
}) {
  final isGuest = GuestSession.isGuest.value;
  final isLoggedIn = FirebaseAuth.instance.currentUser != null;

  if (featureKey == FeatureKey.history || featureKey == FeatureKey.profile) {
    return FeatureAccessResult(
      allowed: isLoggedIn,
      reason: isLoggedIn ? null : FeatureAccessReason.guest,
    );
  }

  if (isGuest || !isLoggedIn) {
    return const FeatureAccessResult(
      allowed: false,
      reason: FeatureAccessReason.guest,
    );
  }

  if (isProfileComplete != true) {
    return const FeatureAccessResult(
      allowed: false,
      reason: FeatureAccessReason.noProfile,
    );
  }

  return const FeatureAccessResult(allowed: true);
}
