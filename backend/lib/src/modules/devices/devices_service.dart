import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../../http/api_exception.dart';

const _deviceColumns =
    'id::text AS id, device_name, device_type, platform, timezone, is_active, receives_alarms, last_seen_at';

Device _deviceFromRow(Row r) => Device(
      id: r['id'] as String,
      deviceName: r['device_name'] as String,
      deviceType: DeviceType.fromWire(r['device_type'] as String),
      platform: DevicePlatform.fromWire(r['platform'] as String),
      timezone: r['timezone'] as String?,
      isActive: r['is_active'] as bool,
      receivesAlarms: r['receives_alarms'] as bool,
      lastSeenAt: r['last_seen_at'] as DateTime?,
    );

class DevicesService {
  final Db db;
  DevicesService(this.db);

  static const maxDevicesPerUser = 20;

  Future<List<Device>> list(String me) async {
    final rows = await db.query(
      'SELECT $_deviceColumns FROM devices WHERE user_id = @me::uuid AND is_active ORDER BY last_seen_at DESC NULLS LAST',
      {'me': me},
    );
    return [for (final r in rows) _deviceFromRow(r)];
  }

  /// Registra el dispositivo actual o actualiza su token/zona horaria.
  /// Un mismo token de push no puede quedar asociado a dos cuentas.
  Future<Device> register(String me, DeviceInput input) async {
    final errors = FieldErrors();
    if (input.deviceName.isEmpty || input.deviceName.length > Validators.maxDeviceNameLength) {
      errors.add('device_name', 'Escribe un nombre para el dispositivo.');
    }
    if (!ZonedSchedule.isValidTimezone(input.timezone)) {
      errors.add('timezone', 'La zona horaria no es válida.');
    }
    if (input.id != null && !Validators.isUuid(input.id)) {
      errors.add('id', 'El identificador no es válido.');
    }
    errors.throwIfAny();

    return db.transaction((tx) async {
      if (input.pushToken != null) {
        await tx.execute(
          'UPDATE devices SET push_token = NULL WHERE push_token = @t AND (id <> @id::uuid OR @id::uuid IS NULL)',
          {'t': input.pushToken, 'id': input.id},
        );
      }
      if (input.id != null) {
        final existing = await tx.one(
          'SELECT user_id::text AS user_id FROM devices WHERE id = @id::uuid',
          {'id': input.id},
        );
        if (existing != null) {
          if (existing['user_id'] != me) {
            throw const ApiException.conflict('Ese dispositivo pertenece a otra cuenta.');
          }
          final row = await tx.one(
            '''
            UPDATE devices SET device_name = @name, device_type = @type, platform = @platform,
              push_token = COALESCE(@token, push_token), timezone = @tz, app_version = @version,
              is_active = true, last_seen_at = now()
            WHERE id = @id::uuid RETURNING $_deviceColumns
            ''',
            _params(input),
          );
          return _deviceFromRow(row!);
        }
      }
      final count = await tx.one(
        'SELECT count(*)::int AS c FROM devices WHERE user_id = @me::uuid AND is_active',
        {'me': me},
      );
      if ((count!['c'] as int) >= maxDevicesPerUser) {
        throw const ApiException.conflict('Alcanzaste el máximo de dispositivos. Elimina alguno.');
      }
      final row = await tx.one(
        '''
        INSERT INTO devices (id, user_id, device_name, device_type, platform, push_token, timezone, app_version, last_seen_at)
        VALUES (COALESCE(@id::uuid, gen_random_uuid()), @me::uuid, @name, @type, @platform, @token, @tz, @version, now())
        RETURNING $_deviceColumns
        ''',
        {..._params(input), 'me': me},
      );
      return _deviceFromRow(row!);
    });
  }

  Map<String, Object?> _params(DeviceInput input) => {
        'id': input.id,
        'name': input.deviceName,
        'type': input.deviceType.wire,
        'platform': input.platform.wire,
        'token': input.pushToken,
        'tz': input.timezone,
        'version': input.appVersion,
      };

  Future<Device> update(String me, String id, {String? name, bool? receivesAlarms}) async {
    if (name != null && (name.trim().isEmpty || name.length > Validators.maxDeviceNameLength)) {
      throw ApiException.validation({'device_name': 'El nombre no es válido.'});
    }
    final row = await db.one(
      '''
      UPDATE devices SET device_name = COALESCE(@name, device_name),
        receives_alarms = COALESCE(@receives, receives_alarms)
      WHERE id = @id::uuid AND user_id = @me::uuid AND is_active
      RETURNING $_deviceColumns
      ''',
      {'id': id, 'me': me, 'name': name?.trim(), 'receives': receivesAlarms},
    );
    if (row == null) throw const ApiException.notFound('No encontramos ese dispositivo.');
    return _deviceFromRow(row);
  }

  /// Desvincula el dispositivo y cierra las sesiones abiertas en él.
  Future<void> remove(String me, String id) => db.transaction((tx) async {
        final updated = await tx.execute(
          'UPDATE devices SET is_active = false, push_token = NULL WHERE id = @id::uuid AND user_id = @me::uuid',
          {'id': id, 'me': me},
        );
        if (updated == 0) throw const ApiException.notFound('No encontramos ese dispositivo.');
        await tx.execute(
          'UPDATE refresh_tokens SET revoked_at = now() WHERE device_id = @id::uuid AND revoked_at IS NULL',
          {'id': id},
        );
      });

  Future<void> touch(String me, String id) => db.execute(
        'UPDATE devices SET last_seen_at = now() WHERE id = @id::uuid AND user_id = @me::uuid',
        {'id': id, 'me': me},
      );
}
