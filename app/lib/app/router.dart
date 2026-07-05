import 'package:go_router/go_router.dart';
import '../core/services/service_instances.dart';
import '../features/splash/splash_screen.dart';
import '../features/admin/auth/admin_login_screen.dart';
import '../features/admin/auth/forgot_password_screen.dart';
import '../features/admin/subscription/subscription_screen.dart';
import '../features/admin/subscription/phone_screen.dart';
import '../features/admin/subscription/otp_screen.dart';
import '../features/admin/profile/profile_screen.dart';
import '../features/admin/venue_list/venue_list_screen.dart';
import '../features/admin/create_venue/create_venue_screen.dart';
import '../features/admin/venue_detail/venue_detail_screen.dart';
import '../features/admin/venue_detail/seat_reserve_screen.dart';
import '../features/admin/scanner/scanner_screen.dart';
import '../features/student/join/join_screen.dart';
import '../features/student/seat_map/seat_map_screen.dart';
import '../features/student/booking/booking_screen.dart';
import '../features/student/entry_pass/entry_pass_screen.dart';
import '../features/student/profile/student_profile_screen.dart';
import '../features/volunteer/volunteer_join_screen.dart';
import '../features/volunteer/volunteer_status_screen.dart';
import '../features/volunteer/volunteer_scanner_screen.dart';
import '../features/admin/venue_detail/volunteer_review_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final path = state.uri.path;
    final isSubscribePath = path.startsWith('/admin/subscribe');
    final isLoginPath = path == '/admin/login';
    final isForgotPasswordPath = path == '/admin/forgot-password';
    final loggedIn = authService.isLoggedIn;
    final subscribed = subscriptionService.isSubscribed;

    // Gate 1: BdApps-style subscription (Subscribe → Phone → OTP) required
    // before anything else, including the login screen — applies to the
    // whole app, so the Admin/Student role picker only appears once both
    // this gate and Gate 2 below have passed.
    if (!subscribed && !isSubscribePath) {
      return '/admin/subscribe';
    }
    if (subscribed && isSubscribePath) {
      return !loggedIn ? '/admin/login' : '/';
    }

    // Gate 2: phone+password login required once subscribed — except the
    // forgot-password flow, which must be reachable while logged out.
    if (subscribed && !loggedIn && !isLoginPath && !isForgotPasswordPath) {
      return '/admin/login';
    }
    if (subscribed && loggedIn && isLoginPath) {
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
        path: '/admin/forgot-password',
        builder: (ctx, _) => const ForgotPasswordScreen()),
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
    GoRoute(
      path: '/admin/venue/:id/reserve',
      builder: (ctx, state) =>
          SeatReserveScreen(venueId: state.pathParameters['id']!),
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
    GoRoute(
        path: '/student/profile',
        builder: (ctx, _) => const StudentProfileScreen()),
    GoRoute(
        path: '/volunteer', builder: (ctx, _) => const VolunteerJoinScreen()),
    GoRoute(
      path: '/volunteer/status/:venueId/:volunteerId',
      builder: (ctx, state) => VolunteerStatusScreen(
        venueId: state.pathParameters['venueId']!,
        volunteerId: state.pathParameters['volunteerId']!,
      ),
    ),
    GoRoute(
      path: '/volunteer/scanner/:venueId/:volunteerId',
      builder: (ctx, state) => VolunteerScannerScreen(
        venueId: state.pathParameters['venueId']!,
        volunteerId: state.pathParameters['volunteerId']!,
      ),
    ),
    GoRoute(
      path: '/admin/venue/:id/volunteers',
      builder: (ctx, state) =>
          VolunteerReviewScreen(venueId: state.pathParameters['id']!),
    ),
  ],
);
