import 'subscription_service.dart';

/// Shared singleton so both the Provider tree (main.dart) and the router's
/// synchronous redirect callback (router.dart) see the same instance.
final subscriptionService = SubscriptionService();
