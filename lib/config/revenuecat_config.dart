import 'dart:io' show Platform;

/// RevenueCat configuration.
///
/// NOTE: real RevenueCat public SDK keys are platform-specific:
///   - App Store: starts with `appl_`
///   - Google Play: starts with `goog_`
/// The placeholder below is a sandbox/secret-style key — swap each constant
/// for the matching public key from the RevenueCat dashboard before
/// shipping. All call sites use [kRevenueCatApiKey], so no other file
/// needs to change.
class RcConfig {
  static const String kRcAppleKey = 'appl_DTEfIRQFhjjRiHijpCXZcISFHjb';
  static const String kRcGoogleKey = 'goog_kQtQPskBcXrgyUVeUCTADtYzhHr';

  static String get kRevenueCatApiKey =>
      Platform.isIOS ? kRcAppleKey : kRcGoogleKey;

  static const String kProEntitlementId = 'DishExtract: Video to Recipe Pro';

  // Placeholder URLs for the fallback paywall's Terms / Privacy footer.
  // Required by App Store review — swap these for real published URLs
  // before TestFlight.
  static const String kTermsUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const String kPrivacyUrl = 'https://flickclean.app/privacy';
}
