import 'package:flutter/foundation.dart';

/// Process-local guest session. It intentionally resets when the app relaunches.
/// Set [persistGuestSession] to true only if product explicitly wants a
/// persistent guest experience backed by a durable store.
class GuestSession {
  GuestSession._();

  static const bool persistGuestSession = false;
  static final ValueNotifier<bool> isGuest = ValueNotifier<bool>(false);

  static void enter() => isGuest.value = true;
  static void clear() => isGuest.value = false;
}
