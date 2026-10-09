import 'dart:io';

import 'package:backend/src/config/app_config.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/db/migrator.dart';
import 'package:logging/logging.dart';

/// Aplica las migraciones pendientes: `dart run bin/migrate.dart`.
Future<void> main() async {
  Logger.root.onRecord.listen((r) => stdout.writeln('[${r.level.name}] ${r.message}'));
  final config = AppConfig.fromEnvironment();
  final db = Database.connect(config.databaseUrl);
  try {
    final applied = await Migrator(db, Directory('migrations')).migrate();
    stdout.writeln(applied.isEmpty
        ? 'La base de datos ya está al día.'
        : 'Migraciones aplicadas: ${applied.join(', ')}');
  } finally {
    await db.close();
  }
}
