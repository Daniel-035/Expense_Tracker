import '../errors/app_exception.dart';

/// Simple sliding-window rate limiter for auth, writes, AI, and uploads.
class RateLimiter {
  RateLimiter._();
  static final RateLimiter instance = RateLimiter._();

  final Map<String, List<DateTime>> _hits = {};

  /// Throws [RateLimitException] when [max] calls exceeded within [windowSeconds].
  void ensureAllowed(
    String key, {
    required int max,
    required int windowSeconds,
  }) {
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(seconds: windowSeconds));
    final list = (_hits[key] ?? [])
        .where((t) => t.isAfter(windowStart))
        .toList();
    if (list.length >= max) {
      final retryIn = windowSeconds -
          now.difference(list.first).inSeconds.clamp(0, windowSeconds);
      throw RateLimitException(
        'Too many requests. Please wait ${retryIn.clamp(1, windowSeconds)}s.',
        retryAfterSeconds: retryIn.clamp(1, windowSeconds),
      );
    }
    list.add(now);
    _hits[key] = list;
  }

  void reset(String key) => _hits.remove(key);
}

class RateLimitException extends AppException {
  RateLimitException(super.message, {this.retryAfterSeconds});

  final int? retryAfterSeconds;
}
