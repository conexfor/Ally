/// Intenciones que el asistente de alarmas sabe reconocer.
enum CommandIntent {
  createAlarm('CREATE_ALARM'),
  editAlarm('EDIT_ALARM'),

  /// Elimina la alarma para todos (cancela, elimina, borra...).
  deleteAlarm('DELETE_ALARM'),

  /// Detiene/desactiva solo la ocurrencia activa o próxima (apaga, desactiva...).
  cancelAlarm('CANCEL_ALARM'),
  listAlarms('LIST_ALARMS'),
  snoozeAlarm('SNOOZE_ALARM'),
  createGroup('CREATE_GROUP'),
  addMember('ADD_MEMBER'),
  removeMember('REMOVE_MEMBER'),
  listContacts('LIST_CONTACTS'),
  listGroups('LIST_GROUPS'),
  help('HELP'),
  unknown('UNKNOWN');

  const CommandIntent(this.code);

  /// Código estable usado en la API y en los tests.
  final String code;

  static CommandIntent fromCode(String code) => values.firstWhere(
        (i) => i.code == code,
        orElse: () => CommandIntent.unknown,
      );

  /// Operaciones que modifican datos y por tanto requieren confirmación.
  bool get isMutation => switch (this) {
        createAlarm ||
        editAlarm ||
        deleteAlarm ||
        cancelAlarm ||
        snoozeAlarm ||
        createGroup ||
        addMember ||
        removeMember =>
          true,
        _ => false,
      };

  /// Operaciones que actúan sobre una alarma existente.
  bool get targetsExistingAlarm => switch (this) {
        editAlarm || deleteAlarm || cancelAlarm || snoozeAlarm => true,
        _ => false,
      };
}
