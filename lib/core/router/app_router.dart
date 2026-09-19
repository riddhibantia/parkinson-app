import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/detailed_metrics_screen.dart';
import '../../features/dashboard/screens/history_screen.dart';
import '../../features/dashboard/screens/layer1_result_screen.dart';
import '../../features/dashboard/screens/layer2_result_screen.dart';
import '../../features/dashboard/screens/layer2_session_insight_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/checkin/screens/checkin_screen.dart';
import '../../features/onboarding/screens/consent_screen.dart';
import '../../features/onboarding/screens/context_profile_screen.dart';
import '../../features/onboarding/screens/demographics_screen.dart';
import '../../features/onboarding/screens/how_it_works_screen.dart';
import '../../features/onboarding/screens/layer_selection_screen.dart';
import '../../features/onboarding/screens/typing_experience_screen.dart';
import '../../features/onboarding/screens/welcome_screen.dart';
import '../../features/info/screens/about_screen.dart';
import '../../features/info/screens/disclaimer_screen.dart';
import '../../features/info/screens/faq_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/free_typing/screens/free_typing_screen.dart';
import '../../data/models/typing_session.dart';
import '../../features/typing_test/screens/motor_task_screen.dart';
import '../../features/typing_test/screens/session_complete_screen.dart';
import '../../features/typing_test/screens/structured_typing_screen.dart';
import '../../features/typing_test/screens/typing_screen.dart';
import '../../core/layout/app_shell.dart';

/// GoRouter with auth guards per plan Stage 1.3/1.5:
/// - not signed in -> /login
/// - signed in but not onboarded -> /onboarding
/// - otherwise -> tabbed home
final appRouterProvider = Provider<GoRouter>((ref) {
  final signedIn = ref.watch(isSignedInProvider);
  final onboarded = ref.watch(hasOnboardedProvider);
  // Demo mode overrides auth requirement
  // Demo mode is entered via Welcome → AppMode.demo; router treats
  // demo users as onboarded-after-wizard via hasOnboarded flag.
  // Keeping read here to trigger rebuild on auth change.
  // Note: demo state is stored separately; for router we treat demo as signed-in
  // The WelcomeScreen sets AppMode.demo, then router sees signedIn || isDemo via hasOnboarded guard bypass.
  // We keep simple: if at /login and already demo, allow /home
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/signup' || loc == '/splash';
      final isOnboarding = loc.startsWith('/onboarding');
      if (!signedIn && !isAuthRoute && !isOnboarding) return '/login';
      if (signedIn && !onboarded && !isOnboarding && !isAuthRoute) {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'how-it-works',
            builder: (context, state) => const HowItWorksScreen(),
          ),
          GoRoute(
            path: 'consent',
            builder: (context, state) => const ConsentScreen(),
          ),
          GoRoute(
            path: 'typing-experience',
            builder: (context, state) => const TypingExperienceScreen(),
          ),
          GoRoute(
            path: 'demographics',
            builder: (context, state) => const DemographicsScreen(),
          ),
          GoRoute(
            path: 'context-profile',
            builder: (context, state) => const ContextProfileScreen(),
          ),
          GoRoute(
            path: 'layer-selection',
            builder: (context, state) => const LayerSelectionScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/checkin',
        builder: (context, state) => const CheckInScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        path: '/disclaimer',
        builder: (context, state) => const DisclaimerScreen(),
      ),
      GoRoute(
        path: '/session/layer2/:id',
        builder: (context, state) {
          final extra = state.extra is TypingSession ? state.extra as TypingSession : null;
          return Layer2SessionInsightScreen(sessionId: state.pathParameters['id']!, initialSession: extra);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/type',
                builder: (context, state) => const TypingScreen(),
                routes: [
                  GoRoute(
                    path: 'structured',
                    builder: (context, state) =>
                        const StructuredTypingScreen(),
                  ),
                  GoRoute(
                    path: 'free',
                    builder: (context, state) => const FreeTypingScreen(),
                  ),
                  GoRoute(
                    path: 'motor-task',
                    builder: (context, state) => const MotorTaskScreen(),
                  ),
                  GoRoute(
                    path: 'complete',
                    builder: (context, state) {
                      final s = state.extra as TypingSession;
                      return SessionCompleteScreen(session: s);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                builder: (context, state) => const DetailedMetricsScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const HistoryScreen(),
                  ),
                  GoRoute(
                    path: 'layer1',
                    builder: (context, state) => const Layer1ResultScreen(),
                  ),
                  GoRoute(
                    path: 'layer2',
                    builder: (context, state) => const Layer2ResultScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
