import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../application/session_controller.dart';
import '../features/alarms/alarm_detail_screen.dart';
import '../features/alarms/alarm_form_screen.dart';
import '../features/alarms/alarms_screen.dart';
import '../features/alarms/received_screen.dart';
import '../features/alarms/ring_screen.dart';
import '../features/alarms/sequence_form_screen.dart';
import '../features/alarms/sequences_screen.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/groups/group_detail_screen.dart';
import '../features/groups/group_form_screen.dart';
import '../features/home/home_screen.dart';
import '../features/people/add_contact_screen.dart';
import '../features/people/contact_screen.dart';
import '../features/people/people_screen.dart';
import '../features/people/requests_screen.dart';
import '../features/profile/devices_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/history_screen.dart';
import '../features/profile/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/profile/stats_screen.dart';
import '../features/shell/main_shell.dart';
import 'providers.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Puente entre Riverpod y go_router para reevaluar redirecciones.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(ringingProvider, (_, _) => notifyListeners());
  }
}

const _publicRoutes = {'/login', '/register', '/forgot-password', '/reset-password', '/onboarding'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      if (session is SessionLoading) return location == '/splash' ? null : '/splash';
      if (session is SignedOut) {
        if (_publicRoutes.contains(location)) return null;
        return session.onboardingSeen ? '/login' : '/onboarding';
      }
      // Sesión iniciada.
      final ringing = ref.read(ringingProvider).value ?? const [];
      if (ringing.isNotEmpty && location != '/ring') return '/ring';
      if (ringing.isEmpty && location == '/ring') return '/home';
      if (location == '/splash' || _publicRoutes.contains(location)) {
        return location == '/reset-password' ? null : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(path: '/ring', builder: (_, _) => const RingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        // El orden debe coincidir con ShellTab (features/shell/main_shell.dart).
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/alarms',
              // Enlaces antiguos (`?tab=received|requests`) abren Recibidas.
              redirect: (_, state) =>
                  const {'received', 'requests'}.contains(state.uri.queryParameters['tab']) ? '/received' : null,
              builder: (_, _) => const AlarmsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/received', builder: (_, _) => const ReceivedScreen()),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/assistant', builder: (_, _) => const AssistantScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(
        path: '/alarms/new',
        builder: (_, state) => AlarmFormScreen(
          draft: state.extra is CommandDraft ? state.extra as CommandDraft : null,
          presetGroupId: state.uri.queryParameters['group'],
          presetUserId: state.uri.queryParameters['user'],
        ),
      ),
      // Detalle como bottom sheet sobre la pantalla anterior.
      GoRoute(path: '/alarms/:id', pageBuilder: (_, state) => alarmDetailPage(state)),
      GoRoute(
        path: '/alarms/:id/edit',
        builder: (_, state) => AlarmFormScreen(editAlarmId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/contacts/add',
        builder: (_, state) => AddContactScreen(
          initialQuery: state.uri.queryParameters['q'],
          initialTab: state.uri.queryParameters['tab'],
          initialCode: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(path: '/contacts/requests', builder: (_, _) => const RequestsScreen()),
      GoRoute(path: '/sequences', builder: (_, _) => const SequencesScreen()),
      GoRoute(path: '/sequences/new', builder: (_, _) => const SequenceFormScreen()),
      GoRoute(
        path: '/contacts/:id',
        builder: (_, state) => ContactScreen(connectionId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/groups/new', builder: (_, _) => const GroupFormScreen()),
      GoRoute(
        path: '/groups/:id',
        builder: (_, state) => GroupDetailScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/groups/:id/edit',
        builder: (_, state) => GroupFormScreen(groupId: state.pathParameters['id']),
      ),
      GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/devices', builder: (_, _) => const DevicesScreen()),
      GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
      GoRoute(
        path: '/people',
        builder: (_, state) => PeopleScreen(initialTab: state.uri.queryParameters['tab']),
      ),
      GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
      // Introducción del producto desde el perfil (con sesión iniciada).
      GoRoute(path: '/intro', builder: (_, _) => const OnboardingScreen(replay: true)),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
    ],
  );
});
