import 'dart:async';
import 'dart:io';

import 'package:backend/src/app.dart';
import 'package:backend/src/config/app_config.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/db/migrator.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:ally_core/ally_core.dart';

Future<void> main() async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    stdout.writeln(
      '${r.time.toIso8601String()} [${r.level.name}] ${r.loggerName}: ${r.message}'
      '${r.error == null ? '' : ' — ${r.error}'}',
    );
  });

  final config = AppConfig.fromEnvironment();
  if (config.isProduction) {
    final problems = config.productionProblems();
    if (problems.isNotEmpty) {
      Logger('server').severe('Configuración no apta para producción:\n- ${problems.join('\n- ')}');
      exit(78); // EX_CONFIG
    }
  }
  ZonedSchedule.ensureInitialized();
  final db = Database.connect(config.databaseUrl);

  if (Platform.environment['RUN_MIGRATIONS'] != 'false') {
    final applied = await Migrator(db, Directory('migrations')).migrate();
    if (applied.isNotEmpty) Logger('server').info('Migraciones aplicadas: ${applied.join(', ')}');
  }

  final app = Application.build(config, db);
  app.maintenance.start();

  final server = await io.serve(app.handler, config.host, config.port);
  server.autoCompress = true;
  Logger('server').info('Ally API escuchando en http://${config.host}:${server.port}');

  // Ctrl+C en local; SIGTERM lo envían Docker y los servicios de hosting al
  // desplegar o reiniciar (no existe en Windows).
  final signals = <StreamSubscription<ProcessSignal>>[];
  var closing = false;
  Future<void> shutdown(ProcessSignal signal) async {
    if (closing) return;
    closing = true;
    Logger('server').info('Cerrando ($signal)...');
    app.maintenance.stop();
    await server.close();
    await db.close();
    for (final s in signals) {
      await s.cancel();
    }
    exit(0);
  }

  signals.add(ProcessSignal.sigint.watch().listen(shutdown));
  if (!Platform.isWindows) signals.add(ProcessSignal.sigterm.watch().listen(shutdown));
}
