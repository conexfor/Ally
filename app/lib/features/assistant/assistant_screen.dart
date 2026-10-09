import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../application/assistant/chat_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alarm_format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/moment.dart';
import '../../core/widgets/ui.dart';
import '../../services/voice_channel.dart';

/// Creación conversacional: se escribe en lenguaje natural y la frase se
/// transforma en un momento estructurado listo para crear.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Conversación por voz en curso (botón de micrófono).
  bool _voice = false;

  static const _examples = [
    'Mañana a las 8 con Nicolás',
    'Llamar a mamá a las 19',
    'Entrenar el viernes a las 7',
  ];

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (_voice) {
      VoiceChannel.stopListening();
      VoiceChannel.stopSpeaking();
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final value = text ?? _input.text;
    if (value.trim().isEmpty) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(value);
  }

  /// Crea el momento preparado y vuelve a Hoy, donde ya aparece en la línea
  /// temporal.
  Future<void> _create() async {
    final controller = ref.read(chatControllerProvider.notifier);
    await controller.confirm();
    if (!mounted) return;
    final items = ref.read(chatControllerProvider).items;
    final created = items.isNotEmpty && (items.last.route?.startsWith('/alarms/') ?? false);
    if (created) {
      context.go('/home');
      showToast(context, 'Momento creado y añadido a tu día');
    }
  }

  /// Dictado: escucha, envía y lee la respuesta. Si el asistente pregunta
  /// algo, vuelve a escuchar. Las alarmas se crean sin confirmar.
  Future<void> _talk() async {
    if (_voice) {
      setState(() => _voice = false);
      await VoiceChannel.stopListening();
      await VoiceChannel.stopSpeaking();
      return;
    }
    setState(() => _voice = true);
    final controller = ref.read(chatControllerProvider.notifier);
    try {
      for (var turn = 0; turn < 4 && _voice && mounted; turn++) {
        final text = await VoiceChannel.listen();
        if (!_voice || !mounted) break;
        if (text == null) {
          if (turn == 0) showMessage(context, 'No te escuché. Toca el micrófono e inténtalo de nuevo.');
          break;
        }
        final speech = await controller.sendVoice(text);
        if (!_voice || !mounted) break;
        if (speech != null) await VoiceChannel.speak(speech);
        if (ref.read(chatControllerProvider).pending == null) break;
      }
    } on PlatformException catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.code == 'permission' ? 'Necesito permiso de micrófono para escucharte.' : 'No pude usar el micrófono.',
        );
      }
    } finally {
      if (mounted) setState(() => _voice = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    ref.listen(chatControllerProvider.select((s) => s.items.length), (_, _) => _scrollToEnd());
    final theme = Theme.of(context);
    final empty = state.items.isEmpty && !state.busy;
    final canSend = _input.text.trim().isNotEmpty && !state.busy;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              Eyebrow(_voice ? 'Te escucho…' : 'Crear'),
              const Spacer(),
              if (!empty)
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (v) async {
                    if (v == 'clear' &&
                        await confirmDialog(
                          context,
                          title: 'Empezar de nuevo',
                          message: 'Se borrará esta conversación de este dispositivo.',
                          confirm: 'Borrar',
                        )) {
                      await ref.read(chatControllerProvider.notifier).clearHistory();
                    }
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Empezar de nuevo'))],
                ),
            ]),
          ),
          Expanded(
            child: empty
                ? _Intro(onPick: _send, examples: _examples)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    itemCount: state.items.length + (state.busy ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == state.items.length) return const _Thinking();
                      return _Entry(item: state.items[i], onCreate: _create);
                    },
                  ),
          ),
          if (!empty && state.pending == null && !state.busy)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _examples.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(label: Text(_examples[i]), onPressed: () => _send(_examples[i])),
              ),
            ),
          // Campo cerca del pulgar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: AppTheme.softShadow(context),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    // Enter en teclado físico también envía.
                    onChanged: (value) {
                      if (value.endsWith('\n')) _send(value);
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      hintText: state.pending?.status == InterpretationStatus.needsClarification
                          ? 'Escribe tu respuesta…'
                          : 'Dilo de forma natural…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (VoiceChannel.isSupported)
                  IconButton(
                    onPressed: state.busy && !_voice ? null : _talk,
                    icon: Icon(_voice ? Icons.stop_rounded : Icons.mic_none_rounded),
                    color: _voice ? AppTheme.violet : null,
                    tooltip: _voice ? 'Detener' : 'Hablar',
                  ),
                const SizedBox(width: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: canSend ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: canSend ? _send : null,
                    icon: Icon(Icons.arrow_upward_rounded,
                        color: canSend ? theme.colorScheme.onPrimary : theme.colorScheme.outline),
                    tooltip: 'Enviar',
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Estado inicial: pregunta, objeto violeta y ejemplos.
class _Intro extends StatelessWidget {
  final void Function(String) onPick;
  final List<String> examples;
  const _Intro({required this.onPick, required this.examples});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final short = isShortScreen(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        Text('¿Qué quieres recordar?', style: theme.textTheme.headlineMedium),
        SizedBox(height: short ? 24 : 48),
        Center(child: _ShapeObject(size: short ? 92 : 120)),
        SizedBox(height: short ? 24 : 40),
        Text('Dilo de forma natural', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Entenderé cuándo, qué y con quién.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (final e in examples) ActionChip(label: Text(e), onPressed: () => onPick(e))],
        ),
      ],
    );
  }
}

/// Objeto violeta abstracto: dos formas que giran y respiran lentamente
/// (interpretación y transformación, sin parecer un chatbot).
class _ShapeObject extends StatefulWidget {
  final double size;
  const _ShapeObject({required this.size});

  @override
  State<_ShapeObject> createState() => _ShapeObjectState();
}

class _ShapeObjectState extends State<_ShapeObject> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return ExcludeSemantics(
      child: SizedBox(
        width: s * 1.3,
        height: s * 1.3,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            final t = _controller.value * 2 * math.pi;
            final breathe = 1 + 0.04 * math.sin(t * 2);
            return Stack(alignment: Alignment.center, children: [
              Transform.rotate(
                angle: t / 4 + math.pi / 4,
                child: Container(
                  width: s * 0.86 * breathe,
                  height: s * 0.86 * breathe,
                  decoration: BoxDecoration(
                    color: AppTheme.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(s * 0.22),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -t / 6,
                child: Container(
                  width: s * 0.6,
                  height: s * 0.6,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(s * 0.18),
                    boxShadow: [
                      BoxShadow(color: AppTheme.violet.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12)),
                    ],
                  ),
                ),
              ),
              Container(
                width: s * 0.14,
                height: s * 0.14,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// Un elemento de la conversación.
class _Entry extends ConsumerWidget {
  final ChatItem item;
  final Future<void> Function() onCreate;
  const _Entry({required this.item, required this.onCreate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(chatControllerProvider.notifier);

    // La frase del usuario aparece de forma discreta.
    if (item.role == ChatRole.user) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6, left: 48),
        child: Text(
          '«${item.text}»',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final interpretation = item.interpretation;
    final confirmation = interpretation?.confirmation;
    final clarification = interpretation?.pendingClarification;
    final isCreation = confirmation != null &&
        !confirmation.partial &&
        interpretation!.draft.intent == CommandIntent.createAlarm &&
        interpretation.draft.time != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: _Appear(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (isCreation)
            _PreparedMoment(draft: interpretation.draft, active: item.active, onCreate: onCreate)
          else if (confirmation != null)
            _ActionSummary(summary: confirmation, active: item.active)
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: 10),
                width: 8,
                height: 8,
                decoration: BoxDecoration(gradient: AppTheme.brandGradient, borderRadius: BorderRadius.circular(2.5)),
              ),
              Expanded(child: Text(item.text, style: theme.textTheme.bodyLarge)),
            ]),
          if (clarification != null && item.active && clarification.options.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final option in clarification.options)
                ActionChip(label: Text(option.label), onPressed: () => controller.chooseOption(option)),
            ]),
          ],
          if (item.route != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 18)),
                onPressed: () => context.push(item.route!),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(item.routeLabel ?? 'Ver'),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Aparición breve (la tarjeta surge después de interpretar la frase).
class _Appear extends StatelessWidget {
  final Widget child;
  const _Appear({required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
          ),
        ),
        child: child,
      );
}

/// La frase convertida en un momento preciso, listo para crear.
class _PreparedMoment extends ConsumerWidget {
  final CommandDraft draft;
  final bool active;
  final Future<void> Function() onCreate;
  const _PreparedMoment({required this.draft, required this.active, required this.onCreate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(chatControllerProvider.notifier);
    final busy = ref.watch(chatControllerProvider.select((s) => s.busy));
    final date = draft.date ?? AlarmFormat.today;
    final time = draft.time!;
    final names = [
      for (final r in draft.recipients) r.type == ResolvedRecipientType.self ? 'Tú' : r.displayName,
    ];
    final shared = names.any((n) => n != 'Tú') || draft.recipients.any((r) => r.type == ResolvedRecipientType.group);
    final color = draft.repeat != null
        ? AppTheme.blue
        : shared
            ? AppTheme.violet
            : AppTheme.cyan;
    final when = draft.repeat != null
        ? SpanishFormatter.repeat(draft.repeat!)
        : SpanishFormatter.date(date, AlarmFormat.today);
    final title = (draft.message?.trim().isNotEmpty ?? false) ? draft.message!.trim() : 'Alarma';

    return Surface(
      padding: EdgeInsets.zero,
      radius: 22,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 4,
            margin: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 20, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Eyebrow(when, color: color),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: BigTime(hour: time.hour, minute: time.minute, size: 60),
                ),
                const SizedBox(height: 6),
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(children: [
                  if (names.isNotEmpty) ...[AvatarStack(names, size: 24, max: 4), const SizedBox(width: 8)],
                  Expanded(
                    child: Text(
                      names.isEmpty ? 'Solo para ti' : SpanishFormatter.joinList(names),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                if (active) ...[
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : onCreate,
                    child: busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                          )
                        : const Text('Crear alarma'),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    TextButton(onPressed: busy ? null : controller.cancel, child: const Text('Descartar')),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              final d = controller.takePendingDraft();
                              if (d != null) context.push('/alarms/new', extra: d);
                            },
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Ajustar'),
                    ),
                  ]),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Otras acciones (posponer, cancelar, consultar…): resumen compacto.
class _ActionSummary extends ConsumerWidget {
  final ConfirmationSummary summary;
  final bool active;
  const _ActionSummary({required this.summary, required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(chatControllerProvider.notifier);
    return Surface(
      padding: const EdgeInsets.all(18),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (summary.partial) ...[
          Text('No entendí todo. Esto es lo que encontré:', style: theme.textTheme.titleSmall),
        ] else
          Text(summary.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final line in summary.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: line.kind == SummaryLineKind.time
                ? Text(line.text, style: AppTheme.time(30, color: theme.colorScheme.onSurface))
                : Text(line.text, style: theme.textTheme.bodyMedium),
          ),
        const SizedBox(height: 8),
        Text(summary.question, style: theme.textTheme.bodySmall),
        if (active) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainer,
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                onPressed: () {
                  if (summary.partial) {
                    final draft = controller.takePendingDraft();
                    if (draft != null && draft.intent == CommandIntent.createAlarm) {
                      context.push('/alarms/new', extra: draft);
                    }
                  } else {
                    controller.cancel();
                  }
                },
                child: Text(summary.cancelLabel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: summary.destructive ? FilledButton.styleFrom(backgroundColor: AppTheme.danger) : null,
                onPressed: controller.confirm,
                child: Text(summary.confirmLabel),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Align(alignment: Alignment.centerLeft, child: _ShapeObject(size: 26)),
      );
}
