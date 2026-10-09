import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/ui.dart';
import '../../services/alarm_scheduler.dart';
import '../../services/device_service.dart';
import '../profile/devices_screen.dart';

enum _RepeatMode { once, daily, weekly, monthly }

/// Formulario tradicional para crear o editar alarmas sin el asistente.
class AlarmFormScreen extends ConsumerStatefulWidget {
  final String? editAlarmId;
  final CommandDraft? draft;
  final String? presetGroupId;
  final String? presetUserId;

  const AlarmFormScreen({super.key, this.editAlarmId, this.draft, this.presetGroupId, this.presetUserId});

  @override
  ConsumerState<AlarmFormScreen> createState() => _AlarmFormScreenState();
}

class _AlarmFormScreenState extends ConsumerState<AlarmFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _recipientQuery = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  _RepeatMode _repeat = _RepeatMode.once;
  Set<int> _days = {};
  int? _dayOfMonth;
  final _users = <String>{};
  final _groups = <String>{};
  bool _includeMe = true;
  final _devices = <String>{};
  bool _onlySomeDevices = false;
  AlarmPriority _priority = AlarmPriority.normal;
  String _sound = 'default';
  bool _vibration = true;
  bool _shareResponses = true;
  bool _busy = false;
  Alarm? _editing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay(hour: now.hour, minute: 0);
    _load();
  }

  Future<void> _load() async {
    final services = ref.read(appServicesProvider);
    final me = await services.store.me();
    if (widget.editAlarmId != null) {
      final alarm = await services.store.alarm(widget.editAlarmId!);
      if (alarm != null) _fillFromAlarm(alarm, me?.id ?? '');
    } else if (widget.draft != null) {
      _fillFromDraft(widget.draft!, me?.id ?? '');
    } else {
      if (widget.presetGroupId != null) {
        _groups.add(widget.presetGroupId!);
        _includeMe = false;
      }
      if (widget.presetUserId != null) {
        _users.add(widget.presetUserId!);
        _includeMe = false;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  void _fillFromAlarm(Alarm a, String meId) {
    _editing = a;
    _title.text = a.title;
    _message.text = a.message ?? '';
    final next = a.nextOccurrenceAt?.toLocal();
    final date = a.repeat == null && next != null ? LocalDate.fromDateTime(next) : a.localDate;
    _date = DateTime(date.year, date.month, date.day);
    _time = TimeOfDay(hour: a.localTime.hour, minute: a.localTime.minute);
    _applyRule(a.repeat);
    _priority = a.priority;
    _sound = AlarmScheduler.sounds.containsKey(a.sound) ? a.sound : 'default';
    _vibration = a.vibration;
    _shareResponses = a.shareResponses;
    _includeMe = false;
    for (final r in a.recipients.where((r) => r.sourceGroupId == null)) {
      switch (r.recipientType) {
        case RecipientType.user when r.recipientId == meId:
          _includeMe = true;
        case RecipientType.user:
          _users.add(r.recipientId);
        case RecipientType.group:
          _groups.add(r.recipientId);
        case RecipientType.device:
          _devices.add(r.recipientId);
          _onlySomeDevices = true;
      }
    }
  }

  void _fillFromDraft(CommandDraft d, String meId) {
    _title.text = d.message ?? '';
    _message.text = d.message ?? '';
    if (d.date != null) _date = DateTime(d.date!.year, d.date!.month, d.date!.day);
    if (d.time != null) _time = TimeOfDay(hour: d.time!.hour, minute: d.time!.minute);
    _applyRule(d.repeat);
    _includeMe = d.recipients.any((r) => r.type == ResolvedRecipientType.self) || d.recipients.isEmpty;
    for (final r in d.recipients) {
      if (r.type == ResolvedRecipientType.user && r.id != null) _users.add(r.id!);
      if (r.type == ResolvedRecipientType.group && r.id != null) _groups.add(r.id!);
    }
  }

  void _applyRule(RepeatRule? rule) {
    if (rule == null) return;
    switch (rule.frequency) {
      case RepeatFrequency.daily:
        _repeat = _RepeatMode.daily;
      case RepeatFrequency.weekly:
        _repeat = _RepeatMode.weekly;
        _days = {...rule.daysOfWeek};
      case RepeatFrequency.monthly:
        _repeat = _RepeatMode.monthly;
        _dayOfMonth = rule.dayOfMonth;
    }
  }

  RepeatRule? _rule() => switch (_repeat) {
        _RepeatMode.once => null,
        _RepeatMode.daily => _editing?.repeat?.frequency == RepeatFrequency.daily ? _editing!.repeat : RepeatRule.daily(),
        _RepeatMode.weekly => RepeatRule.weekly(_days.isEmpty ? {_date.weekday} : _days),
        _RepeatMode.monthly => RepeatRule(frequency: RepeatFrequency.monthly, dayOfMonth: _dayOfMonth ?? _date.day),
      };

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _recipientQuery.dispose();
    _player.dispose();
    super.dispose();
  }

  final _player = AudioPlayer();

  /// Reproduce unos segundos del sonido elegido.
  Future<void> _previewSound() async {
    if (_sound == 'default') {
      showMessage(context, 'Sonará el tono de alarma configurado en tu teléfono.');
      return;
    }
    await _player.stop();
    await _player.play(AssetSource('sounds/$_sound.wav'));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_repeat == _RepeatMode.weekly && _days.isEmpty) {
      showMessage(context, 'Elige al menos un día de la semana.');
      return;
    }
    if (!_includeMe && _users.isEmpty && _groups.isEmpty && !_onlySomeDevices) {
      showMessage(context, 'Elige al menos un destinatario.');
      return;
    }
    // El servidor acepta horas pasadas (por las alarmas creadas sin conexión)
    // y las guarda como completadas: nunca sonarían.
    final at = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (_rule() == null && !at.isAfter(DateTime.now())) {
      showMessage(context, 'Esa fecha y hora ya pasaron. Revisa si es AM o PM.');
      return;
    }
    final services = ref.read(appServicesProvider);
    final me = (await services.store.me())!;
    final recipients = <RecipientInput>[
      if (_includeMe && !_onlySomeDevices) RecipientInput(RecipientType.user, me.id),
      if (_includeMe && _onlySomeDevices)
        for (final d in _devices) RecipientInput(RecipientType.device, d),
      for (final u in _users) RecipientInput(RecipientType.user, u),
      for (final g in _groups) RecipientInput(RecipientType.group, g),
    ];
    final input = AlarmInput(
      title: _title.text.trim(),
      message: _message.text.trim().isEmpty ? null : _message.text.trim(),
      localDate: LocalDate(_date.year, _date.month, _date.day),
      localTime: LocalTime(_time.hour, _time.minute),
      timezone: _editing?.timezone ?? await DeviceService.currentTimezone(),
      repeat: _rule(),
      priority: _priority,
      sound: _sound,
      vibration: _vibration,
      shareResponses: _shareResponses,
      recipients: recipients,
    );
    setState(() => _busy = true);
    try {
      final outcome = _editing == null
          ? await services.alarms.create(input)
          : await services.alarms.update(_editing!, input);
      if (!mounted) return;
      showMessage(
        context,
        outcome.queued
            ? 'Guardada sin conexión. Se enviará al recuperar internet.'
            : (_editing == null ? 'Alarma creada.' : 'Cambios guardados.'),
      );
      if (_editing == null) {
        context.pushReplacement('/alarms/${outcome.value.id}');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = (ref.watch(contactsProvider).value ?? const <Contact>[]).where((c) => c.isAccepted).toList();
    final groups =
        (ref.watch(groupsProvider).value ?? const <Group>[]).where((g) => g.canSendAlarms).toList();
    final devices = ref.watch(myDevicesProvider).value ?? const <Device>[];
    final submit = FilledButton(
      onPressed: _busy || !_loaded ? null : _save,
      child: _busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
          : Text(_editing == null ? 'Crear alarma' : 'Guardar cambios'),
    );

    final blocks = !_loaded ? const <Widget>[] : _blocks(contacts, groups, devices);
    Widget formList() => Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              PageBody(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, b) in blocks.indexed) ...[if (i > 0) const SizedBox(height: 16), b],
                  ],
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(_editing == null ? 'Nueva alarma' : 'Editar alarma')),
      body: !_loaded ? const LoadingView() : formList(),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: submit)),
    );
  }

  String _dateLabel() =>
      SpanishFormatter.date(LocalDate(_date.year, _date.month, _date.day), LocalDate.fromDateTime(DateTime.now()));

  List<Widget> _blocks(List<Contact> contacts, List<Group> groups, List<Device> devices) {
    final theme = Theme.of(context);
    final query = TextNormalizer.nameKey(_recipientQuery.text);
    final groupMatches = groups.where((g) => query.isEmpty || TextNormalizer.nameKey(g.name).contains(query)).toList();
    final contactMatches = contacts
        .where((c) =>
            query.isEmpty ||
            TextNormalizer.nameKey('${c.user.displayName} ${c.user.username}').contains(query))
        .toList();
    final selected = [
      for (final g in groups)
        if (_groups.contains(g.id)) (g.name, Icons.groups_rounded, () => _groups.remove(g.id)),
      for (final c in contacts)
        if (_users.contains(c.user.id)) (c.user.displayName, null, () => _users.remove(c.user.id)),
    ];

    return [
      BlockCard(
        title: 'Nombre de la alarma',
        icon: Icons.label_outline_rounded,
        child: TextFormField(
          controller: _title,
          decoration: const InputDecoration(hintText: 'Reunión, Despertar, Medicina…'),
          maxLength: Validators.maxTitleLength,
          validator: Validators.alarmTitle,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
      ),
      BlockCard(
        title: 'Fecha y hora',
        icon: Icons.schedule_rounded,
        child: Row(children: [
          Expanded(
            child: _PickerCard(
              icon: Icons.access_time_rounded,
              label: 'Hora',
              value: SpanishFormatter.time(LocalTime(_time.hour, _time.minute)),
              large: true,
              onTap: () async {
                final t = await pickTime(context, _time);
                if (t != null) setState(() => _time = t);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PickerCard(
              icon: Icons.calendar_today_rounded,
              label: _repeat == _RepeatMode.once ? 'Fecha' : 'Desde',
              value: _dateLabel(),
              onTap: () async {
                final today = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date.isBefore(today) ? today : _date,
                  firstDate: DateTime(today.year, today.month, today.day),
                  lastDate: today.add(const Duration(days: 365 * 2)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
          ),
        ]),
      ),
      BlockCard(
        title: 'Mensaje o instrucciones',
        icon: Icons.notes_rounded,
        child: TextFormField(
          controller: _message,
          decoration: const InputDecoration(hintText: 'Opcional: qué hacer cuando suene'),
          maxLength: Validators.maxMessageLength,
          minLines: 2,
          maxLines: 4,
          validator: Validators.alarmMessage,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
      BlockCard(
        title: 'Repetición',
        icon: Icons.repeat_rounded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<_RepeatMode>(
            segments: [
              const ButtonSegment(value: _RepeatMode.once, label: Text('Una vez')),
              const ButtonSegment(value: _RepeatMode.daily, label: Text('Diaria')),
              const ButtonSegment(value: _RepeatMode.weekly, label: Text('Semanal')),
              if (_repeat == _RepeatMode.monthly)
                const ButtonSegment(value: _RepeatMode.monthly, label: Text('Mensual')),
            ],
            selected: {_repeat},
            onSelectionChanged: (s) => setState(() {
              _repeat = s.first;
              if (_repeat == _RepeatMode.weekly && _days.isEmpty) _days = {_date.weekday};
            }),
          ),
          if (_repeat == _RepeatMode.weekly) ...[
            const SizedBox(height: 16),
            Text('Días', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(children: [
              for (final (d, label) in const [(1, 'L'), (2, 'M'), (3, 'X'), (4, 'J'), (5, 'V'), (6, 'S'), (7, 'D')])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _DayButton(
                      label: label,
                      selected: _days.contains(d),
                      onTap: () => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d)),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Wrap(children: [
              TextButton(onPressed: () => setState(() => _days = {1, 2, 3, 4, 5}), child: const Text('Lunes a viernes')),
              TextButton(onPressed: () => setState(() => _days = {6, 7}), child: const Text('Fines de semana')),
            ]),
          ],
        ]),
      ),
      BlockCard(
        title: 'Destinatarios',
        icon: Icons.group_add_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilterChip(
              avatar: const Icon(Icons.person_rounded, size: 18),
              label: const Text('Yo'),
              selected: _includeMe,
              onSelected: (v) => setState(() => _includeMe = v),
            ),
            for (final (name, icon, remove) in selected)
              InputChip(
                avatar: icon != null ? Icon(icon, size: 18) : UserAvatar(name, size: 24),
                label: Text(name),
                selected: true,
                showCheckmark: false,
                onDeleted: () => setState(remove),
              ),
          ]),
          const SizedBox(height: 14),
          if (contacts.isEmpty && groups.isEmpty)
            Text('Agrega contactos para enviarles alarmas.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          else ...[
            TextField(
              controller: _recipientQuery,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Buscar personas o grupos',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final g in groupMatches)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: UserAvatar(g.name, icon: Icons.groups_rounded, size: 36),
                      title: Text(g.name),
                      subtitle: Text('Grupo · ${g.activeMemberCount} miembros'),
                      value: _groups.contains(g.id),
                      onChanged: (v) => setState(() => v == true ? _groups.add(g.id) : _groups.remove(g.id)),
                    ),
                  for (final c in contactMatches)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: UserAvatar(c.user.displayName, size: 36, imageUrl: c.user.avatarUrl),
                      title: Text(c.user.displayName),
                      subtitle: Text(c.grantedToMe.allowAlarms ? '@${c.user.username}' : 'No acepta alarmas tuyas'),
                      value: _users.contains(c.user.id),
                      onChanged: c.grantedToMe.allowAlarms
                          ? (v) => setState(() => v == true ? _users.add(c.user.id) : _users.remove(c.user.id))
                          : null,
                    ),
                  if (groupMatches.isEmpty && contactMatches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Sin resultados.', style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ],
          if (_includeMe && devices.length > 1) ...[
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solo en algunos de mis dispositivos'),
              value: _onlySomeDevices,
              onChanged: (v) => setState(() => _onlySomeDevices = v),
            ),
            if (_onlySomeDevices)
              for (final d in devices)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(deviceIcon(d.deviceType)),
                  title: Text(d.deviceName),
                  value: _devices.contains(d.id),
                  onChanged: (v) => setState(() => v == true ? _devices.add(d.id) : _devices.remove(d.id)),
                ),
          ],
        ]),
      ),
      BlockCard(
        title: 'Confirmación y aviso',
        icon: Icons.task_alt_rounded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'Cuando suene, cada destinatario podrá confirmar o posponer.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (_users.length + _groups.length > 0)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar respuestas a los destinatarios'),
              subtitle: const Text('Cada destinatario verá quién confirmó o pospuso.'),
              value: _shareResponses,
              onChanged: (v) => setState(() => _shareResponses = v),
            ),
          const SizedBox(height: 12),
          Text('Prioridad', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<AlarmPriority>(
            segments: const [
              ButtonSegment(value: AlarmPriority.normal, label: Text('Normal')),
              ButtonSegment(value: AlarmPriority.important, label: Text('Importante')),
              ButtonSegment(value: AlarmPriority.urgent, label: Text('Urgente')),
            ],
            selected: {_priority},
            onSelectionChanged: (s) => setState(() => _priority = s.first),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _sound,
                decoration: const InputDecoration(labelText: 'Sonido'),
                items: [
                  for (final e in AlarmScheduler.sounds.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _sound = v ?? 'default'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Escuchar',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: _previewSound,
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibración'),
            value: _vibration,
            onChanged: (v) => setState(() => _vibration = v),
          ),
        ]),
      ),
    ];
  }
}

class _PickerCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool large;
  final VoidCallback onTap;

  const _PickerCard({required this.icon, required this.label, required this.value, required this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(label, style: theme.textTheme.bodySmall),
              ]),
              const SizedBox(height: 8),
              Text(value,
                  style: large ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 1,
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}
