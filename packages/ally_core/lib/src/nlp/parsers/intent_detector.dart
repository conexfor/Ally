import '../lexicon/intent_lexicon.dart';
import '../model/command_intent.dart';

class IntentDetection {
  final CommandIntent intent;

  /// Posición de la palabra clave que determinó el intent (-1 si ninguna).
  final int position;

  const IntentDetection(this.intent, this.position);

  bool get matched => intent != CommandIntent.unknown;
}

/// Detecta la intención del usuario a partir de los patrones del
/// [intentRules] (ver `lexicon/intent_lexicon.dart`).
class IntentDetector {
  final List<_CompiledRule> _rules;

  IntentDetector({List<IntentRule>? rules})
      : _rules = [
          for (final rule in rules ?? intentRules)
            _CompiledRule(rule, [for (final p in rule.patterns) RegExp(p)]),
        ];

  IntentDetection detect(String normalizedText) {
    IntentDetection? best;
    var bestPriority = -1;
    for (final compiled in _rules) {
      final position = compiled.firstMatchPosition(normalizedText);
      if (position == null) continue;
      final better = best == null ||
          position < best.position ||
          (position == best.position && compiled.rule.priority > bestPriority);
      if (better) {
        best = IntentDetection(compiled.rule.intent, position);
        bestPriority = compiled.rule.priority;
      }
    }
    return best ?? const IntentDetection(CommandIntent.unknown, -1);
  }
}

class _CompiledRule {
  final IntentRule rule;
  final List<RegExp> patterns;
  _CompiledRule(this.rule, this.patterns);

  int? firstMatchPosition(String text) {
    int? earliest;
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && (earliest == null || match.start < earliest)) {
        earliest = match.start;
      }
    }
    return earliest;
  }
}
