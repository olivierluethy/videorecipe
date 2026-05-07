import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import 'recipe_provider.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  throw UnimplementedError(
      'SubscriptionService must be overridden in main.dart');
});

/// Mirrors `SubscriptionService.isProNotifier` into Riverpod. The
/// customer-info listener inside the service is the single source of truth;
/// this notifier just relays.
class _IsProNotifier extends StateNotifier<bool> {
  _IsProNotifier(this._service) : super(_service.isPro) {
    _service.isProNotifier.addListener(_sync);
  }

  final SubscriptionService _service;

  void _sync() {
    if (!mounted) return;
    state = _service.isPro;
  }

  @override
  void dispose() {
    _service.isProNotifier.removeListener(_sync);
    super.dispose();
  }
}

final isProProvider = StateNotifierProvider<_IsProNotifier, bool>((ref) {
  return _IsProNotifier(ref.watch(subscriptionServiceProvider));
});

class _OfferingsStatusNotifier extends StateNotifier<OfferingsStatus> {
  _OfferingsStatusNotifier(this._service)
      : super(_service.offeringsStatusNotifier.value) {
    _service.offeringsStatusNotifier.addListener(_sync);
  }

  final SubscriptionService _service;

  void _sync() {
    if (!mounted) return;
    state = _service.offeringsStatusNotifier.value;
  }

  @override
  void dispose() {
    _service.offeringsStatusNotifier.removeListener(_sync);
    super.dispose();
  }
}

final offeringsStatusProvider =
    StateNotifierProvider<_OfferingsStatusNotifier, OfferingsStatus>((ref) {
  return _OfferingsStatusNotifier(ref.watch(subscriptionServiceProvider));
});

class ExtractionCounterNotifier extends StateNotifier<int> {
  ExtractionCounterNotifier(this._storage) : super(_storage.freeExtractionsUsed);

  final StorageService _storage;

  /// Persists synchronously, then bumps state. Call this only on a successful
  /// extraction — never on cancel or failure. The counter is monotonic.
  Future<void> increment() async {
    await _storage.incrementFreeExtractionsUsed();
    state = _storage.freeExtractionsUsed;
  }

  /// Debug-only reset so the gate can be re-tested without a reinstall.
  Future<void> debugReset() async {
    if (!kDebugMode) return;
    await _storage.resetFreeExtractionsUsed();
    state = 0;
  }
}

final extractionCounterProvider =
    StateNotifierProvider<ExtractionCounterNotifier, int>((ref) {
  return ExtractionCounterNotifier(ref.watch(storageServiceProvider));
});
