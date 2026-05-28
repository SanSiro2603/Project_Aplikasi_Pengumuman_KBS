import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/guest/presentation/screens/splash_screen.dart';
import '../../features/guest/presentation/screens/home_screen.dart';
import '../../features/guest/presentation/screens/detail_screen.dart';
import '../../features/admin/presentation/screens/admin_login_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_form_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = Supabase.instance.client.auth.currentSession != null;
      final isGoingToAdmin = state.matchedLocation.startsWith('/admin');
      final isGoingToLogin = state.matchedLocation == '/admin/login';

      if (isGoingToAdmin) {
        if (!isAuth && !isGoingToLogin) {
          return '/admin/login'; // Cekam admin yg belum login
        }
        if (isAuth && isGoingToLogin) {
          return '/admin'; // Admin udah login, jangan ke login screen
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'form',
            builder: (context, state) {
              final id = state.uri.queryParameters['id'];
              return AdminFormScreen(id: id);
            },
          ),
        ],
      ),
    ],
  );
}
