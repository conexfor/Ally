import '../model/command_intent.dart';
import '../model/mentions.dart';
import '../parse_state.dart';
import '../text_normalizer.dart';

class GroupCommandParse {
  /// Nombre del grupo tal como lo escribió el usuario ("equipo" = genérico,
  /// p. ej. "al equipo").
  final String? groupName;

  /// Personas a añadir/quitar.
  final RecipientSegment? members;

  const GroupCommandParse({this.groupName, this.members});
}

/// Extrae el nombre del grupo y los miembros en los comandos de grupos:
///
/// - "Crea un grupo llamado Familia con Juan y María"
/// - "Agrega a Juan al grupo Familia"
/// - "Saca a Pedro del equipo Desarrollo"
class GroupParser {
  static final _createGroup = RegExp(
    r'\bgrupo\s+(?:llamado\s+|llamada\s+|que\s+se\s+llame\s+|con\s+(?:el\s+)?nombre\s+(?:de\s+)?|de\s+nombre\s+|nombrado\s+)?["“«]?(?<name>[^"”»|]+?)["”»]?(?:\s+(?:con|y\s+agrega\s+a|y\s+anade\s+a|e\s+incluye\s+a|para)\s+(?:a\s+)?(?<members>[^|]+))?$',
  );
  static final _addMember = RegExp(
    r'\b(?:agreg|anad|mete|met|incluy|incorpor|sum|invit)\w*\s+(?:a\s+)?(?<members>.+?)\s+(?:al|a\s+mi|a\s+el|en\s+el|en\s+mi)\s+(?<noun>grupo|equipo)\b\s*(?:de\s+|llamado\s+)?["“«]?(?<name>[^"”»|]*?)["”»]?\s*$',
  );
  static final _removeMember = RegExp(
    r'\b(?:sac|quit|elimin|borr|expuls|remuev|remov|retir)\w*\s+(?:a\s+)?(?<members>.+?)\s+(?:del|de\s+mi|de\s+el)\s+(?<noun>grupo|equipo)\b\s*(?:de\s+|llamado\s+)?["“«]?(?<name>[^"”»|]*?)["”»]?\s*$',
  );
  static final _separator = RegExp(r'\s*,\s*|\s+(?:y|e)\s+');

  GroupCommandParse? parse(ParseState state, CommandIntent intent) {
    final pattern = switch (intent) {
      CommandIntent.createGroup => _createGroup,
      CommandIntent.addMember => _addMember,
      CommandIntent.removeMember => _removeMember,
      _ => null,
    };
    if (pattern == null) return null;

    final text = _stripTrailingPunctuation(state.available);
    final match = pattern.firstMatch(text);
    if (match == null) return const GroupCommandParse();

    final name = _originalOf(state, text, match, 'name');
    final noun = match.groupNames.contains('noun') ? match.namedGroup('noun') : null;
    final membersText = match.namedGroup('members');
    RecipientSegment? members;
    if (membersText != null && membersText.trim().isNotEmpty) {
      members = _buildMembers(state, text, match, membersText);
    }
    state.consume(match.start, match.end);
    return GroupCommandParse(
      // "al equipo" sin nombre: grupo genérico que se resuelve por la palabra.
      groupName: (name == null || name.isEmpty) && noun == 'equipo' ? 'equipo' : name,
      members: members,
    );
  }

  String _stripTrailingPunctuation(String text) =>
      text.replaceFirst(RegExp(r'[\s.!?]+$'), '');

  String? _originalOf(ParseState state, String text, RegExpMatch m, String group) {
    final value = m.namedGroup(group);
    if (value == null || value.trim().isEmpty) return null;
    final start = text.indexOf(value, m.start);
    final original = state.originalSlice(start, start + value.length).trim();
    return original.replaceAll(RegExp(r'^["“«]|["”»]$'), '');
  }

  RecipientSegment _buildMembers(
    ParseState state,
    String text,
    RegExpMatch match,
    String membersText,
  ) {
    final start = text.indexOf(membersText, match.start);
    final original = state.originalSlice(start, start + membersText.length);
    final normalized = membersText;
    final items = <RecipientMention>[];
    var cursor = 0;
    for (final sep in [..._separator.allMatches(normalized), null]) {
      final end = sep?.start ?? normalized.length;
      var raw = original.substring(cursor, end).trim();
      raw = raw.replaceFirst(RegExp(r'^(?:a|al)\s+', caseSensitive: false), '');
      if (raw.isNotEmpty) {
        final isUsername = raw.startsWith('@');
        items.add(RecipientMention(
          raw: raw,
          key: TextNormalizer.nameKey(raw),
          kind: isUsername
              ? RecipientMentionKind.username
              : RecipientMentionKind.person,
        ));
      }
      if (sep != null) cursor = sep.end;
    }
    return RecipientSegment(original.trim(), items);
  }
}
