import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/widgets/common.dart';
import '../../services/device_service.dart';

class _Step {
  TimeOfDay time;
  final TextEditingController title;
  _Step(this.time, String title) : title = TextEditingController(text: title);
}

enum _Repeat { once, daily, weekdays, weekends }

/// Crear una rutina: varios pasos con hora y título.
class SequenceFormScreen extends ConsumerStatefulWidget {
  const SequenceFormScreen({super.key});

  @override
  ConsumerState<SequenceFormScreen> createState() => _SequenceFormScreenState();
}

class _SequenceFormScreenState extends ConsumerState<SequenceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Mañana');
  late DateTime _date;
  _Repeat _repeat = _Repeat.weekdays;
  bool _includeMe = true;
  final _users = <String>{};
  final _groups = <String>{};
  bool _busy = false;
  final _steps = [
    _Step(const TimeOfDay(hour: 7, minute: 0), 'Despertar'),
    _Step(const TimeOfDay(hour: 7, minute: 15), 'Prepararse'),
    _Step(const TimeOfDay(hour: 7, minute: 30), 'Salir de casa'),
  ];

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  @override
  void dispose() {
    _name.dispose();
    for (final s in _steps) {
      s.title.dispose();
    }
    super.dispose();
  }

  RepeatRule? _rule() => switch (_repeat) {
        _Repeat.once => null,
        _Repeat.daily => RepeatRule.daily(),
        _Repeat.weekdays => RepeatRule.weekdaysOnly,
        _Repeat.weekends => RepeatRule.weekendsOnly,
      };

  void _addStep() {
    final last = _steps.last.time;
    final minutes = (last.hour * 60 + last.minute + 15).clamp(0, 23 * 60 + 59);
    setState(() => _steps.add(_Step(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60), '')));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    for (var i = 1; i < _steps.length; i++) {
      final prev = _steps[i - 1].time;
      final cur = _steps[i].time;
      if (cur.hour * 60 + cur.minute <= prev.hour * 60 + prev.minute) {
        showMessage(context, 'Cada paso debe ser más tarde que el anterior.');
        return;
      }
    }
    if (!_includeMe && _users.isEmpty && _groups.isEmpty) {
      showMessage(context, 'Elige al menos un destinatario.');
      return;
    }
    final services = ref.read(appServicesProvider);
    final me = (await services.store.me())!;
    final input = SequenceInput(
      name: _name.text.trim(),
      localDate: LocalDate(_date.year, _date.month, _date.day),
      timezone: await DeviceService.currentTimezone(),
      repeat: _rule(),
      recipients: [
        if (_includeMe) RecipientInput(RecipientType.user, me.id),
        for (final u in _users) RecipientInput(RecipientType.user, u),
        for (final g in _groups) RecipientInput(RecipientType.group, g),
      ],
      steps: [
        for (final s in _steps)
          SequenceStepInput(title: s.title.text.trim(), localTime: LocalTime(s.time.hour, s.time.minute)),
      ],
    );
    if (!mounted) return;
    setState(() => _busy = true);
    final created = await runGuarded(context, () => services.alarms.createSequence(input), success: 'Rutina creada.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (created != null) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = (ref.watch(contactsProvider).value ?? const <Contact>[])
        .where((c) => c.isAccepted && c.grantedToMe.allowAlarms)
        .toList();
    final groups = (ref.watch(groupsProvider).value ?? const <Group>[]).where((g) => g.canSendAlarms).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva rutina')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre de la rutina'),
              maxLength: 60,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre.' : null,
            ),
            const SectionHeader('Pasos'),
            for (final (i, step) in _steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(96, 52)),
                    onPressed: () async {
                      final t = await pickTime(context, step.time);
                      if (t != null) setState(() => step.time = t);
                    },
                    child: Text(SpanishFormatter.time(LocalTime(step.time.hour, step.time.minute))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: step.title,
                      decoration: InputDecoration(hintText: 'Paso ${i + 1}'),
                      validator: Validators.alarmTitle,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar paso',
                    onPressed: _steps.length <= 2 ? null : () => setState(() => _steps.removeAt(i).title.dispose()),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ]),
              ),
            if (_steps.length < 12)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Añadir paso'),
                ),
              ),
            const SectionHeader('Cuándo'),
            SegmentedButton<_Repeat>(
              segments: const [
                ButtonSegment(value: _Repeat.once, label: Text('Una vez')),
                ButtonSegment(value: _Repeat.daily, label: Text('Diaria')),
                ButtonSegment(value: _Repeat.weekdays, label: Text('L-V')),
                ButtonSegment(value: _Repeat.weekends, label: Text('S-D')),
              ],
              selected: {_repeat},
              onSelectionChanged: (s) => setState(() => _repeat = s.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded),
              title: Text(_repeat == _Repeat.once ? 'Fecha' : 'Empieza'),
              subtitle: Text(SpanishFormatter.date(
                LocalDate(_date.year, _date.month, _date.day),
                LocalDate.fromDateTime(DateTime.now()),
              )),
              onTap: () async {
                final today = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(today.year, today.month, today.day),
                  lastDate: today.add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SectionHeader('Para quién'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeMe,
              onChanged: (v) => setState(() => _includeMe = v ?? false),
              title: const Text('Yo'),
              secondary: const Icon(Icons.person_rounded),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in groups)
                FilterChip(
                  avatar: const Icon(Icons.groups_rounded, size: 18),
                  label: Text(g.name),
                  selected: _groups.contains(g.id),
                  onSelected: (v) => setState(() => v ? _groups.add(g.id) : _groups.remove(g.id)),
                ),
              for (final c in contacts)
                FilterChip(
                  label: Text(c.user.displayName),
                  selected: _users.contains(c.user.id),
                  onSelected: (v) => setState(() => v ? _users.add(c.user.id) : _users.remove(c.user.id)),
                ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                : const Text('Crear rutina'),
          ),
        ),
      ),
    );
  }
}
