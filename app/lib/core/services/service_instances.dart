import 'auth_service.dart';
import 'subscription_service.dart';

/// Shared singletons so both the Provider tree (main.dart) and the router's
/// synchronous redirect callback (router.dart) see the same instances.
final subscriptionService = SubscriptionService();
final authService = AuthService();
