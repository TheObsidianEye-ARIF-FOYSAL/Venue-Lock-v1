import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../core/services/service_instances.dart';
import '../features/splash/splash_screen.dart';
import '../features/admin/auth/admin_login_screen.dart';
import '../features/admin/subscription/subscription_screen.dart';
import '../features/admin/subscription/phone_screen.dart';
import '../features/admin/subscription/otp_screen.dart';
import '../features/admin/profile/profile_screen.dart';
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
    final path = state.uri.path;
    final isSubscribePath = path.startsWith('/admin/subscribe');
    final isLoginPath = path == '/admin/login';
    final user = FirebaseAuth.instance.currentUser;
    final subscribed = subscriptionService.isSubscribed;

    // Gate 1: BdApps-style subscription (Subscribe → Phone → OTP) required
    // before anything else, including the Firebase login screen — applies
    // to the whole app, so the Admin/Student role picker only appears once
    // both this gate and Gate 2 below have passed.
    if (!subscribed && !isSubscribePath) {
      return '/admin/subscribe';
    }
    if (subscribed && isSubscribePath) {
      return user == null ? '/admin/login' : '/';
    }

    // Gate 2: Firebase login required once subscribed.
    if (subscribed && user == null && !isLoginPath) {
      return '/admin/login';
    }
    if (subscribed && user != null && isLoginPath) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (ctx, _) => const SplashScreen()),
    GoRoute(
        path: '/admin/subscribe',
        builder: (ctx, _) => const SubscriptionScreen()),
    GoRoute(
        path: '/admin/subscribe/phone', builder: (ctx, _) => const PhoneScreen()),
    GoRoute(
        path: '/admin/subscribe/otp', builder: (ctx, _) => const OtpScreen()),
    GoRoute(
        path: '/admin/login',
        builder: (ctx, _) => const AdminLoginScreen()),
    GoRoute(
        path: '/admin/venues',
        builder: (ctx, _) => const VenueListScreen()),
    GoRoute(
        path: '/admin/profile',
        builder: (ctx, _) => const ProfileScreen()),
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
