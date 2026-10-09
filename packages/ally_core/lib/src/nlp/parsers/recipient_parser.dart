import '../lexicon/date_lexicon.dart' show alternation;
import '../lexicon/recipient_lexicon.dart';
import '../model/mentions.dart';
import '../parse_state.dart';
import '../text_normalizer.dart';

class RecipientParseResult {
  final List<RecipientSegment> segments;
  final bool includesSelf;
  const RecipientParseResult(this.segments, {required this.includesSelf});
}

/// Extrae destinatarios: "para Nicolás y Juan", "recuérdale a María",
/// "para todo el equipo", "@juan", "para mí"...
///
/// Solo identifica menciones; `RecipientResolver` las compara después con los
/// contactos y grupos reales del usuario.
class RecipientParser {
  static final _selfPatterns = [for (final p in selfPatterns) RegExp(p)];
  static final _username = RegExp(r'@(?<u>[a-z0-9_.]{3,30})');

  static final _stop = alternation(recipientStopWords);
  static const _segmentBody = r'[^|.;:!?]';
  static final _segment =
      '(?<seg>(?:(?!\\b(?:$_stop)\\b)$_segmentBody)+)';

  static final _triggers = [
    RegExp('\\bpara\\s+$_segment'),
    RegExp('\\b(?:${alternation(recipientVerbs)})\\s+(?:a\\s+)?$_segment'),
    RegExp(
      '\\b(?:ponle|ponles|programale|programales|creale|creales|agendale|activale)\\b'
      '(?:\\s+(?:una|la|el)?\\s*(?:alarma|recordatorio|aviso))?\\s+a\\s+$_segment',
    ),
    RegExp('\\b(?:alarma|recordatorio|aviso)\\s+a\\s+(?!las?\\b)$_segment'),
  ];

  /// "con Ana, Luis y Pedro": habitual al dictar por voz. Se evalúa al final
  /// y el segmento es tentativo (ver [RecipientSegment.tentative]).
  static final _withTrigger = RegExp('\\bcon\\s+$_segment');

  static final _separator = RegExp(r'\s*,\s*|\s+(?:y|e)\s+');
  static final _articles = RegExp(
    '^(?:${alternation(recipientArticles)})\\s+',
  );
  static final _wholeGroup = RegExp(
    '^(?:${alternation(wholeGroupPrefixes)})\\s+',
  );
  static final _groupNoun = RegExp('^(?:${groupNouns.join('|')})\\b');
  static final _infinitive = RegExp(
    r'^[a-z]{2,}(?:ar|er|ir)(?:me|te|se|le|les|lo|la|nos)?$',
  );

  RecipientParseResult parse(ParseState state) {
    var includesSelf = false;
    for (final pattern in _selfPatterns) {
      for (final match in pattern.allMatches(state.available).toList()) {
        includesSelf = true;
        state.consumeMatch(match);
      }
    }

    final segments = <RecipientSegment>[];

    // @usuario explícitos, en cualquier posición.
    final usernameMatches = _username.allMatches(state.available).toList();
    if (usernameMatches.isNotEmpty) {
      segments.add(RecipientSegment(
        usernameMatches.map((m) => m[0]).join(', '),
        [
          for (final m in usernameMatches)
            RecipientMention(
              raw: '@${m.namedGroup('u')}',
              key: m.namedGroup('u')!,
              kind: RecipientMentionKind.username,
            ),
        ],
      ));
      for (final m in usernameMatches) {
        state.consumeMatch(m);
      }
    }

    for (final trigger in [..._triggers, _withTrigger]) {
      while (true) {
        final match = trigger.firstMatch(state.available);
        if (match == null) break;
        final seg = match.namedGroup('seg')!;
        final segStart = match.end - seg.length;
        final segment = _buildSegment(
          state,
          segStart,
          match.end,
          tentative: identical(trigger, _withTrigger),
        );
        state.consumeMatch(match);
        if (segment != null) segments.add(segment);
      }
    }

    return RecipientParseResult(segments, includesSelf: includesSelf);
  }

  RecipientSegment? _buildSegment(
    ParseState state,
    int start,
    int end, {
    bool tentative = false,
  }) {
    final normalized = state.normalized;
    final items = <RecipientMention>[];
    var itemStart = start;
    final separators =
        _separator.allMatches(normalized.substring(0, end), start).toList();
    for (final sep in [...separators, null]) {
      final itemEnd = sep?.start ?? end;
      final item = _buildItem(state, itemStart, itemEnd);
      if (item != null) items.add(item);
      if (sep != null) itemStart = sep.end;
    }
    if (items.isEmpty) return null;
    return RecipientSegment(
      state.originalSlice(start, end).trim(),
      items,
      tentative: tentative,
    );
  }

  RecipientMention? _buildItem(ParseState state, int start, int end) {
    var text = state.normalized.substring(start, end);
    var offset = start;

    // Recorta espacios y restos ya consumidos.
    final leading = RegExp(r'^[\s|]*').firstMatch(text)![0]!.length;
    final trailing = RegExp(r'[\s|]*$').firstMatch(text)![0]!.length;
    if (leading + trailing >= text.length) return null;
    text = text.substring(leading, text.length - trailing);
    offset += leading;
    if (text.contains(ParseState.consumedMark)) {
      // Mezcla de nombre y entidades ya reconocidas: nos quedamos con lo
      // anterior a la primera entidad.
      text = text.substring(0, text.indexOf(ParseState.consumedMark)).trim();
      if (text.isEmpty) return null;
    }

    var isGroup = false;
    var hadArticle = false;
    final whole = _wholeGroup.firstMatch(text);
    if (whole != null) {
      isGroup = true;
      text = text.substring(whole.end);
      offset += whole.end;
    } else {
      final article = _articles.firstMatch(text);
      if (article != null) {
        hadArticle = true;
        text = text.substring(article.end);
        offset += article.end;
      }
    }
    if (text.isEmpty) return null;
    if (_groupNoun.hasMatch(text)) isGroup = true;

    final raw = state.originalSlice(offset, offset + text.length).trim();
    final firstWord = text.split(' ').first;
    return RecipientMention(
      raw: raw,
      key: TextNormalizer.nameKey(raw),
      kind: isGroup ? RecipientMentionKind.group : RecipientMentionKind.person,
      hadArticle: hadArticle,
      looksLikeInfinitive: _infinitive.hasMatch(firstWord),
    );
  }
}
