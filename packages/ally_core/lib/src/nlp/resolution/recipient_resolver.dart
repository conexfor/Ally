import '../model/command_draft.dart';
import '../model/interpretation_context.dart';
import '../model/mentions.dart';
import '../text_normalizer.dart';

sealed class RecipientMatch {
  const RecipientMatch();
}

class RecipientResolved extends RecipientMatch {
  final ResolvedRecipient recipient;
  const RecipientResolved(this.recipient);
}

class RecipientAmbiguous extends RecipientMatch {
  final List<ResolvedRecipient> candidates;
  const RecipientAmbiguous(this.candidates);
}

class RecipientNotFound extends RecipientMatch {
  /// Nombres parecidos ("¿quisiste decir...?").
  final List<ResolvedRecipient> suggestions;
  const RecipientNotFound([this.suggestions = const []]);
}

/// Compara menciones ("Carlos", "@juan", "el equipo") con los contactos y
/// grupos del usuario.
///
/// Nunca elige arbitrariamente: si varias personas coinciden devuelve
/// [RecipientAmbiguous] para que el usuario decida.
class RecipientResolver {
  const RecipientResolver();

  static const _groupNouns = {'grupo', 'equipo'};

  RecipientMatch resolve(RecipientMention mention, InterpretationContext ctx) {
    switch (mention.kind) {
      case RecipientMentionKind.username:
        return resolveUsername(mention.key, ctx);
      case RecipientMentionKind.group:
        return resolveGroup(mention.key, ctx);
      case RecipientMentionKind.person:
        // "la familia": con artículo, probablemente un grupo.
        if (mention.hadArticle) {
          final group = resolveGroup(mention.key, ctx, exactOnly: true);
          if (group is! RecipientNotFound) return group;
        }
        final person = resolvePerson(mention.key, ctx);
        if (person is! RecipientNotFound) return person;
        final group = resolveGroup(mention.key, ctx, exactOnly: true);
        return group is RecipientNotFound ? person : group;
    }
  }

  RecipientMatch resolveUsername(String username, InterpretationContext ctx) {
    final key = TextNormalizer.nameKey(username).replaceAll(' ', '');
    for (final c in ctx.contacts) {
      if (TextNormalizer.nameKey(c.username) == key) {
        return RecipientResolved(_toRecipient(c));
      }
    }
    return const RecipientNotFound();
  }

  /// Busca por nombre con niveles de precisión decrecientes; se detiene en el
  /// primer nivel con coincidencias.
  RecipientMatch resolvePerson(String rawKey, InterpretationContext ctx) {
    final key = TextNormalizer.nameKey(rawKey);
    if (key.isEmpty) return const RecipientNotFound();
    final keyTokens = key.split(' ');

    bool byUsername(DirectoryContact c) =>
        TextNormalizer.nameKey(c.username) == key.replaceAll(' ', '');
    bool byFullName(DirectoryContact c) =>
        TextNormalizer.nameKey(c.displayName) == key;
    bool byTokens(DirectoryContact c) {
      final tokens = TextNormalizer.nameKey(c.displayName).split(' ');
      return keyTokens.every(tokens.contains);
    }
    bool byPrefix(DirectoryContact c) {
      final tokens = TextNormalizer.nameKey(c.displayName).split(' ');
      return keyTokens.every(
        (k) => k.length >= 3 && tokens.any((t) => t.startsWith(k)),
      );
    }

    for (final tier in [byUsername, byFullName, byTokens, byPrefix]) {
      final matches = ctx.contacts.where(tier).toList();
      if (matches.length == 1) return RecipientResolved(_toRecipient(matches.single));
      if (matches.length > 1) {
        return RecipientAmbiguous([for (final c in matches) _toRecipient(c)]);
      }
    }

    final suggestions = ctx.contacts.where((c) {
      final name = TextNormalizer.nameKey(c.displayName);
      final first = name.split(' ').first;
      final tolerance = key.length >= 7 ? 2 : 1;
      return key.length >= 4 &&
          (editDistance(key, first) <= tolerance || editDistance(key, name) <= tolerance);
    }).toList();
    return RecipientNotFound([for (final c in suggestions) _toRecipient(c)]);
  }

  RecipientMatch resolveGroup(
    String rawKey,
    InterpretationContext ctx, {
    bool exactOnly = false,
  }) {
    final key = TextNormalizer.nameKey(rawKey);
    final groups = ctx.groups;

    // "el equipo", "el grupo": genérico.
    if (key.isEmpty || _groupNouns.contains(key)) {
      if (exactOnly) return const RecipientNotFound();
      var candidates = key.isEmpty
          ? groups
          : groups.where((g) => TextNormalizer.nameKey(g.name).split(' ').contains(key)).toList();
      if (candidates.isEmpty) candidates = groups;
      return _groupMatch(candidates);
    }

    // Variantes: "Desarrollo" ↔ "Equipo Desarrollo", "grupo Familia" ↔ "Familia".
    final withoutNoun = key.replaceFirst(RegExp(r'^(?:grupo|equipo)\s+(?:de\s+)?'), '');
    final variants = {key, withoutNoun, for (final n in _groupNouns) '$n $withoutNoun'};

    final exact = groups
        .where((g) => variants.contains(TextNormalizer.nameKey(g.name)))
        .toList();
    if (exact.isNotEmpty || exactOnly) return _groupMatch(exact);

    final tokens = withoutNoun.split(' ');
    final partial = groups.where((g) {
      final groupTokens = TextNormalizer.nameKey(g.name).split(' ');
      return tokens.every((t) => groupTokens.any((gt) => gt.startsWith(t)));
    }).toList();
    return _groupMatch(partial);
  }

  RecipientMatch _groupMatch(List<DirectoryGroup> candidates) {
    if (candidates.isEmpty) return const RecipientNotFound();
    final recipients = [
      for (final g in candidates)
        ResolvedRecipient(
          type: ResolvedRecipientType.group,
          id: g.groupId,
          displayName: g.name,
        ),
    ];
    return recipients.length == 1
        ? RecipientResolved(recipients.single)
        : RecipientAmbiguous(recipients);
  }

  static ResolvedRecipient _toRecipient(DirectoryContact c) => ResolvedRecipient(
        type: ResolvedRecipientType.user,
        id: c.userId,
        displayName: c.displayName,
        username: c.username,
      );

  static ResolvedRecipient self(InterpretationContext ctx) => ResolvedRecipient(
        type: ResolvedRecipientType.self,
        id: ctx.selfUserId,
        displayName: 'Tú',
      );
}

/// Distancia de edición (Damerau, alineamiento óptimo): inserción, borrado,
/// sustitución y transposición de letras contiguas ("Pedor" → "Pedro" = 1).
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final d = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = d[i - 1][j] + 1;
      if (d[i][j - 1] + 1 < best) best = d[i][j - 1] + 1;
      if (d[i - 1][j - 1] + cost < best) best = d[i - 1][j - 1] + cost;
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        if (d[i - 2][j - 2] + 1 < best) best = d[i - 2][j - 2] + 1;
      }
      d[i][j] = best;
    }
  }
  return d[a.length][b.length];
}
