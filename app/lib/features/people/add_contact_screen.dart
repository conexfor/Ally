import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/config/env.dart';
import '../../core/widgets/common.dart';

/// Agregar contactos: buscar (@usuario, correo, teléfono), mostrar mi código
/// QR o escanear el de otra persona.
class AddContactScreen extends ConsumerWidget {
  final String? initialQuery;
  final String? initialTab;
  final String? initialCode;

  const AddContactScreen({super.key, this.initialQuery, this.initialTab, this.initialCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = switch (initialTab) {
      'invite' => 1,
      'code' => 2,
      _ => 0,
    };
    return DefaultTabController(
      length: 3,
      initialIndex: index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agregar contacto'),
          bottom: const TabBar(tabs: [Tab(text: 'Buscar'), Tab(text: 'Mi código'), Tab(text: 'Escanear')]),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _SearchTab(initialQuery: initialQuery),
            const _MyCodeTab(),
            _ScanTab(initialCode: initialCode),
          ],
        ),
      ),
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  final String? initialQuery;
  const _SearchTab({this.initialQuery});

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  late final _query = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;
  List<PublicUser> _results = const [];
  bool _loading = false;
  final _sent = <String>{};

  @override
  void initState() {
    super.initState();
    if (_query.text.length >= 2) _search(_query.text);
  }

  @override
  void dispose() {
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    if (value.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await ref.read(appServicesProvider).social.search(value);
      if (mounted && value == _query.text) setState(() => _results = results);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(PublicUser user) async {
    final result = await runGuarded(
      context,
      () => ref.read(appServicesProvider).social.request(userId: user.id),
    );
    if (result != null && mounted) {
      setState(() => _sent.add(user.id));
      showMessage(
        context,
        result.status == ConnectionStatus.accepted
            ? 'Ahora estás conectado con ${user.displayName}.'
            : 'Solicitud enviada a ${user.displayName}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = {for (final c in ref.watch(contactsProvider).value ?? const <Contact>[]) c.user.id: c};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _query,
          autofocus: widget.initialQuery == null,
          decoration: InputDecoration(
            hintText: '@usuario, nombre, correo o teléfono',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          onChanged: _onChanged,
        ),
        const SizedBox(height: 12),
        if (_results.isEmpty && _query.text.length >= 2 && !_loading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(
              icon: Icons.person_search_rounded,
              title: 'Sin resultados',
              message: 'Comparte tu código desde "Mi código" para que te agreguen.',
            ),
          ),
        for (final user in _results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: UserAvatar(user.displayName, imageUrl: user.avatarUrl),
            title: Text(user.displayName),
            subtitle: Text('@${user.username}'),
            trailing: switch (contacts[user.id]?.status) {
              ConnectionStatus.accepted => const Chip(label: Text('Contacto')),
              ConnectionStatus.pending => const Chip(label: Text('Pendiente')),
              _ when _sent.contains(user.id) => const Chip(label: Text('Enviada')),
              _ => FilledButton.tonal(onPressed: () => _request(user), child: const Text('Agregar')),
            },
          ),
      ],
    );
  }
}

class _MyCodeTab extends ConsumerStatefulWidget {
  const _MyCodeTab();

  @override
  ConsumerState<_MyCodeTab> createState() => _MyCodeTabState();
}

class _MyCodeTabState extends ConsumerState<_MyCodeTab> {
  late Future<InvitationCode> _code = ref.read(appServicesProvider).social.invitationCode();

  /// Invitación para alguien que aún no tiene la app: enlace web (abre la app
  /// si está instalada o lleva a Google Play) y el código para escribirlo.
  Future<void> _share(InvitationCode code, String? name) async {
    final pretty = '${code.code.substring(0, 4)}-${code.code.substring(4)}';
    final store = Env.playStoreUrl.isEmpty ? '' : '\nDescárgala aquí: ${Env.playStoreUrl}';
    await SharePlus.instance.share(ShareParams(
      subject: 'Conéctate conmigo en Ally',
      text: '${name ?? 'Te'} invito a Ally para enviarnos alarmas.\n'
          'Abre este enlace: ${Env.publicWebUrl}/c/${code.code}\n'
          'O escribe el código $pretty en Personas → Agregar → Escanear.$store',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    final theme = Theme.of(context);
    return FutureBuilder<InvitationCode>(
      future: _code,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            snapshot.error!,
            onRetry: () => setState(() => _code = ref.read(appServicesProvider).social.invitationCode()),
          );
        }
        if (!snapshot.hasData) return const LoadingView();
        final code = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Pide a la otra persona que escanee este código.',
                style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: QrImageView(data: code.qrPayload, size: 220, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            if (me != null)
              Text('${me.displayName} · @${me.username}',
                  textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code.code));
                  showMessage(context, 'Código copiado.');
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '${code.code.substring(0, 4)}-${code.code.substring(4)}',
                      style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 4),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded, size: 20),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _share(code, me?.displayName),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Compartir invitación'),
            ),
            const SizedBox(height: 12),
            Text(
              'Al conectarse, ambos podrán enviarse alarmas según los permisos que elijan.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

class _ScanTab extends ConsumerStatefulWidget {
  final String? initialCode;
  const _ScanTab({this.initialCode});

  @override
  ConsumerState<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends ConsumerState<_ScanTab> {
  late final _manual = TextEditingController(text: widget.initialCode ?? '');
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _busy = false;

  @override
  void dispose() {
    _manual.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _connect(String raw) async {
    if (_busy) return;
    final code = InvitationCode.parsePayload(raw);
    if (code == null) {
      showMessage(context, 'Ese código no es válido.');
      return;
    }
    setState(() => _busy = true);
    await _scanner.stop();
    if (!mounted) return;
    final contact = await runGuarded(context, () => ref.read(appServicesProvider).social.connectWithCode(code));
    if (!mounted) return;
    setState(() => _busy = false);
    if (contact != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, size: 48),
          title: const Text('Conexión establecida'),
          content: Text('${contact.user.displayName} ahora puede enviarte alarmas.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
          ],
        ),
      );
      if (mounted) context.pushReplacement('/contacts/${contact.connectionId}');
    } else {
      await _scanner.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 300,
            child: MobileScanner(
              controller: _scanner,
              onDetect: (capture) {
                final value = capture.barcodes.firstOrNull?.rawValue;
                if (value != null) _connect(value);
              },
              errorBuilder: (context, error) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No se pudo usar la cámara. Escribe el código abajo.', textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('¿No puedes escanear? Escribe el código:', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _manual,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'ABCD-1234'),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: _busy ? null : () => _connect(_manual.text), child: const Text('Conectar')),
        ]),
      ],
    );
  }
}
