import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/admin/auth/admin_login_screen.dart';
import '../features/admin/venue_list/venue_list_screen.dart';
import '../features/admin/create_venue/create_venue_screen.dart';
import '../features/admin/venue_detail/venue_detail_screen.dart';
import '../features/admin/scanner/scanner_screen.dart';
import '../features/student/join/join_screen.dart';
import '../features/student/seat_map/seat_map_screen.dart';
import '../features/student/booking/booking_screen.dart';
import '../features/student/entry_pass/entry_pass_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final path = state.uri.path;

    // Protect all admin routes except the login page
    final isAdminProtected =
        path.startsWith('/admin') && path != '/admin/login';
    if (isAdminProtected && user == null) return '/admin/login';

    // If already logged in and visiting the login page, go straight to venues
    if (path == '/admin/login' && user != null) return '/admin/venues';

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (ctx, _) => const SplashScreen()),
    GoRoute(
        path: '/admin/login',
        builder: (ctx, _) => const AdminLoginScreen()),
    GoRoute(
        path: '/admin/venues',
        builder: (ctx, _) => const VenueListScreen()),
    GoRoute(
        path: '/admin/venues/create',
        builder: (ctx, _) => const CreateVenueScreen()),
    GoRoute(
      path: '/admin/venue/:id',
      builder: (ctx, state) =>
          VenueDetailScreen(venueId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/admin/venue/:id/scanner',
      builder: (ctx, state) =>
          ScannerScreen(venueId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/student', builder: (ctx, _) => const JoinScreen()),
    GoRoute(
      path: '/student/seats/:venueId',
      builder: (ctx, state) =>
          SeatMapScreen(venueId: state.pathParameters['venueId']!),
    ),
    GoRoute(
      path: '/student/book/:venueId/:seatId',
      builder: (ctx, state) => BookingScreen(
        venueId: state.pathParameters['venueId']!,
        seatId: state.pathParameters['seatId']!,
      ),
    ),
    GoRoute(
      path: '/student/pass/:venueId/:seatId',
      builder: (ctx, state) => EntryPassScreen(
        venueId: state.pathParameters['venueId']!,
        seatId: state.pathParameters['seatId']!,
      ),
    ),
  ],
);
