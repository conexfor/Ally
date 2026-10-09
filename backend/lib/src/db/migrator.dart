import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'database.dart';

/// Aplica en orden los archivos `migrations/NNNN_nombre.sql` que aún no se
/// hayan ejecutado. Cada migración corre en su propia transacción.
class Migrator {
  final Db db;
  final Directory directory;
  final _log = Logger('Migrator');

  Migrator(this.db, this.directory);

  Future<List<String>> migrate() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version    text PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      )''');
    final applied = {
      for (final row in await db.query('SELECT version FROM schema_migrations'))
        row['version'] as String,
    };

    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'^\d{4}_.+\.sql$').hasMatch(p.basename(f.path)))
        .toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    final newlyApplied = <String>[];
    for (final file in files) {
      final version = p.basenameWithoutExtension(file.path);
      if (applied.contains(version)) continue;
      _log.info('Aplicando migración $version');
      final sql = await file.readAsString();
      await db.transaction((tx) async {
        for (final statement in splitSqlStatements(sql)) {
          await tx.execute(statement);
        }
        await tx.execute(
          'INSERT INTO schema_migrations (version) VALUES (@v)',
          {'v': version},
        );
      });
      newlyApplied.add(version);
    }
    return newlyApplied;
  }
}

/// Divide un script SQL en sentencias, respetando cadenas, comentarios y
/// bloques `$$ ... $$` de funciones.
List<String> splitSqlStatements(String sql) {
  final statements = <String>[];
  final buffer = StringBuffer();
  var inSingleQuote = false;
  var inDollar = false;
  var i = 0;
  while (i < sql.length) {
    final char = sql[i];
    final next = i + 1 < sql.length ? sql[i + 1] : '';
    if (!inSingleQuote && !inDollar && char == '-' && next == '-') {
      final end = sql.indexOf('\n', i);
      i = end == -1 ? sql.length : end + 1;
      buffer.write('\n');
      continue;
    }
    if (!inSingleQuote && char == r'$' && next == r'$') {
      inDollar = !inDollar;
      buffer.write(r'$$');
      i += 2;
      continue;
    }
    if (!inDollar && char == "'") inSingleQuote = !inSingleQuote;
    if (!inSingleQuote && !inDollar && char == ';') {
      final statement = buffer.toString().trim();
      if (statement.isNotEmpty) statements.add(statement);
      buffer.clear();
    } else {
      buffer.write(char);
    }
    i++;
  }
  final last = buffer.toString().trim();
  if (last.isNotEmpty) statements.add(last);
  return statements;
}
