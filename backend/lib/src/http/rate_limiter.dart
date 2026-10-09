/// Limitador de peticiones en memoria (ventana deslizante por clave).
///
/// Suficiente para una instancia. Con varias réplicas detrás de un balanceador
/// debería sustituirse por una implementación compartida (p. ej. Redis)
/// manteniendo esta interfaz.
class RateLimiter {
  final int maxRequests;
  final Duration window;
  final DateTime Function() _now;
  final _hits = <String, List<DateTime>>{};
  var _calls = 0;

  RateLimiter({
    required this.maxRequests,
    this.window = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Registra un intento; devuelve `false` si se superó el límite.
  bool tryAcquire(String key) {
    final now = _now();
    final cutoff = now.subtract(window);
    final hits = _hits.putIfAbsent(key, () => [])
      ..removeWhere((t) => t.isBefore(cutoff));
    if (++_calls % 1000 == 0) _evictIdle(cutoff);
    if (hits.length >= maxRequests) return false;
    hits.add(now);
    return true;
  }

  void _evictIdle(DateTime cutoff) =>
      _hits.removeWhere((_, hits) => hits.every((t) => t.isBefore(cutoff)));
}
