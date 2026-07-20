import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/pass_storage.dart';
import '../../../core/services/student_profile_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/volunteer_service.dart';
import '../../admin/subscription/widgets/auth_widgets.dart';

/// The single profile screen for the whole app, reachable only from the
/// VenueLock role-picker (SplashScreen) — there is no separate admin-only
/// profile entry point. Shows sections in a fixed, role-aware order so every
/// role sees exactly the info that's relevant to them:
///   1. Avatar header with a role badge (Admin / Volunteer / Audience / Guest)
///   2. Personal details form (name/email/roll — prefills booking & volunteer
///      forms on this device)
///   3. Role-specific status: admin account stats & actions, OR the active
///      volunteer application, OR saved audience booking passes
///   4. Appearance (theme) — available to everyone, not just admins
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _rollCtrl;
  bool _saving = false;

  VolunteerApplication? _volunteerApp;
  VolunteerInfo? _volunteerInfo;
  List<SavedPass> _passes = [];
  bool _loadingExtras = true;

  @override
  void initState() {
    super.initState();
    final profile = context.read<StudentProfileService>();
    _nameCtrl = TextEditingController(text: profile.name);
    _emailCtrl = TextEditingController(text: profile.email);
    _rollCtrl = TextEditingController(text: profile.roll);
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final service = VolunteerService();
    final app = await service.getActiveApplication();
    VolunteerInfo? info;
    if (app != null) {
      info = await service.getStatus(
        volunteerId: app.volunteerId,
        deviceToken: app.deviceToken,
      );
    }
    final passes = await PassStorage.getPasses();
    if (!mounted) return;
    setState(() {
      _volunteerApp = app;
      _volunteerInfo = info;
      _passes = passes;
      _loadingExtras = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _rollCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await context.read<StudentProfileService>().save(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          roll: _rollCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved'),
        backgroundColor: kSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: kError)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will permanently delete your account, all data, '
              'and cancel your subscription.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your password to confirm',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final password = ctrl.text;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting account…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (context.mounted) {
      await context.read<SubscriptionService>().unsubscribe();
    }
    final error = context.mounted
        ? await context.read<AuthService>().deleteAccount(password: password)
        : 'No account is signed in.';

    if (context.mounted) Navigator.of(context).pop(); // close loader
    if (!context.mounted) return;

    if (error == null) {
      context.go('/admin/subscribe');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleChangePassword(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (v != newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
    if (submitted != true || !context.mounted) return;

    final error = await context
        .read<AuthService>()
        .changePassword(currentCtrl.text, newCtrl.text);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Password changed successfully.'),
        backgroundColor: error == null ? kSuccess : kError,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isAdmin = auth.isLoggedIn;
    final profile = context.watch<StudentProfileService>();
    final role = isAdmin ? _Role.admin : _Role.member;
    final displayName = isAdmin ? auth.displayName : profile.name;

    return Scaffold(
      body: Container(
        decoration: authGradient(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      // Profile is the landing screen after login (no route
                      // below it to pop to) — falls back to the role picker
                      // so a logged-in admin can still switch to Audience/
                      // Volunteer on this device.
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.push('/'),
                    ),
                    const Text(
                      'My Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loadingExtras
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        children: [
                          _AvatarHeader(name: displayName, role: role)
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.1, duration: 400.ms),
                          const SizedBox(height: 28),
                          _SectionDivider(label: 'PERSONAL DETAILS'),
                          const SizedBox(height: 20),
                          _BookingDetailsCard(
                            formKey: _formKey,
                            nameCtrl: _nameCtrl,
                            emailCtrl: _emailCtrl,
                            rollCtrl: _rollCtrl,
                            saving: _saving,
                            onSave: _save,
                          ).animate().fadeIn(duration: 400.ms),
                          if (isAdmin) ...[
                            const SizedBox(height: 28),
                            _SectionDivider(label: 'ADMIN ACCOUNT'),
                            const SizedBox(height: 20),
                            _AdminSection(
                              onChangePassword: () =>
                                  _handleChangePassword(context),
                              onDeleteAccount: () =>
                                  _handleDeleteAccount(context),
                              confirm: (
                                      {required title,
                                      required message,
                                      required confirmLabel,
                                      destructive = false}) =>
                                  _confirm(context,
                                      title: title,
                                      message: message,
                                      confirmLabel: confirmLabel,
                                      destructive: destructive),
                            ),
                          ],
                          const SizedBox(height: 28),
                          _SectionDivider(label: 'MY BOOKINGS'),
                          const SizedBox(height: 20),
                          _passes.isEmpty
                              ? const _EmptyState(
                                  icon: Icons.confirmation_number_outlined,
                                  message: 'No bookings yet — join a venue '
                                      'with its code to reserve a seat.',
                                )
                              : _AudienceSection(
                                  passes: _passes,
                                  onViewPass: (pass) => context.push(
                                      '/student/pass/${pass.venueId}/${pass.seatId}'),
                                ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 28),
                          _SectionDivider(label: 'VOLUNTEER STATUS'),
                          const SizedBox(height: 20),
                          _volunteerApp == null
                              ? const _EmptyState(
                                  icon: Icons.volunteer_activism_outlined,
                                  message: 'Not volunteering anywhere yet — '
                                      'apply with a venue\'s access code.',
                                )
                              : _VolunteerSection(
                                  app: _volunteerApp!,
                                  info: _volunteerInfo,
                                  onViewStatus: () => context.push(
                                      '/volunteer/status/${_volunteerApp!.venueId}/${_volunteerApp!.volunteerId}'),
                                ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 28),
                          _SectionDivider(label: 'APPEARANCE'),
                          const SizedBox(height: 20),
                          const _AppearanceCard()
                              .animate()
                              .fadeIn(duration: 400.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingDetailsCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController rollCtrl;
  final bool saving;
  final VoidCallback onSave;

  const _BookingDetailsCard({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.rollCtrl,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_outline,
                    color: kIndigo, size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                'Your Details',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Used to prefill booking and volunteer forms on this '
                'device. You can update it any time.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!v.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: rollCtrl,
                decoration: const InputDecoration(
                  labelText: 'Roll Number (optional)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _ConfirmFn = Future<bool> Function({
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive,
});

class _AdminSection extends StatelessWidget {
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;
  final _ConfirmFn confirm;

  const _AdminSection({
    required this.onChangePassword,
    required this.onDeleteAccount,
    required this.confirm,
  });

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionService>();
    final venues = context.watch<AppState>().venues;

    final venuesCreated = venues.length;
    final totalCapacity =
        venues.fold<int>(0, (acc, v) => acc + v.totalSeats);
    final seatsBooked =
        venues.fold<int>(0, (acc, v) => acc + v.bookedCount);
    final checkedIn =
        venues.fold<int>(0, (acc, v) => acc + v.checkedInCount);

    return Column(
      children: [
        _InfoCard(phone: subscription.phone).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push('/admin/venues'),
            icon: const Icon(Icons.dashboard_customize_rounded),
            label: const Text('Manage Venues'),
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.dashboard_customize_rounded,
                value: '$venuesCreated',
                label: 'Venues Created',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.event_seat_rounded,
                value: '$seatsBooked',
                label: 'Seats Booked',
              ),
            ),
          ],
        ).animate().fadeIn(delay: 250.ms).slideY(
            begin: 0.08, delay: 250.ms, duration: 400.ms),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.how_to_reg_rounded,
                value: '$checkedIn',
                label: 'Checked In',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.chair_alt_rounded,
                value: '$totalCapacity',
                label: 'Total Capacity',
              ),
            ),
          ],
        ).animate().fadeIn(delay: 320.ms).slideY(
            begin: 0.08, delay: 320.ms, duration: 400.ms),
        const SizedBox(height: 24),
        _ActionTile(
          icon: Icons.password_rounded,
          label: 'Change Password',
          subtitle: 'Update your account password',
          onTap: onChangePassword,
        ).animate().fadeIn(delay: 390.ms),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.logout_rounded,
          label: 'Logout',
          subtitle: 'Sign out — subscription stays active',
          onTap: () async {
            final ok = await confirm(
              title: 'Logout?',
              message: 'You will be signed out and redirected to the login '
                  'screen. Your subscription remains active.',
              confirmLabel: 'Logout',
            );
            if (!ok || !context.mounted) return;
            await context.read<AuthService>().logout();
            if (context.mounted) context.go('/admin/login');
          },
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.unsubscribe_rounded,
          label: 'Unsubscribe',
          subtitle: 'Cancel subscription and sign out',
          destructive: true,
          onTap: () async {
            final ok = await confirm(
              title: 'Unsubscribe?',
              message: 'Your subscription will be cancelled and you will '
                  'be signed out. You will need to subscribe again to use '
                  'the admin console.',
              confirmLabel: 'Unsubscribe',
              destructive: true,
            );
            if (!ok || !context.mounted) return;
            final unsubOk =
                await context.read<SubscriptionService>().unsubscribe();
            if (!context.mounted) return;
            if (unsubOk) {
              await context.read<AuthService>().logout();
              if (context.mounted) context.go('/admin/subscribe');
            } else {
              final err = context.read<SubscriptionService>().error;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(err ?? 'Unsubscribe failed'),
                  backgroundColor: kError,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ).animate().fadeIn(delay: 460.ms),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.delete_forever_rounded,
          label: 'Delete Account',
          subtitle: 'Permanently delete your account and data',
          destructive: true,
          onTap: onDeleteAccount,
        ).animate().fadeIn(delay: 520.ms),
      ],
    );
  }
}

enum _Role { admin, member }

extension on _Role {
  String get label {
    switch (this) {
      case _Role.admin:
        return 'Admin';
      case _Role.member:
        return 'Member';
    }
  }

  IconData get icon {
    switch (this) {
      case _Role.admin:
        return Icons.admin_panel_settings_rounded;
      case _Role.member:
        return Icons.person_rounded;
    }
  }
}

/// Shown in place of the Volunteer/Audience sections when the person hasn't
/// used that part of the app yet — keeps the profile's section order fixed
/// and predictable for every user instead of sections popping in and out.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.35), size: 28),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  final String name;
  final _Role role;
  const _AvatarHeader({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    final seed = context.watch<ThemeService>().seedColor;
    final dark = brandAccent(context);
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [seed, dark]),
                boxShadow: [
                  BoxShadow(
                    color: dark.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -2,
              right: -6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: dark,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(role.icon, color: Colors.white, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      role.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          name.isNotEmpty ? name : role.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white24)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white24)),
      ],
    );
  }
}

class _VolunteerSection extends StatelessWidget {
  final VolunteerApplication app;
  final VolunteerInfo? info;
  final VoidCallback onViewStatus;

  const _VolunteerSection({
    required this.app,
    required this.info,
    required this.onViewStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = info?.status ?? 'pending';
    final (statusColor, statusLabel, statusIcon) = switch (status) {
      'approved' => (kSuccess, 'Approved', Icons.check_circle_rounded),
      'rejected' => (kError, 'Rejected', Icons.cancel_rounded),
      _ => (kWarning, 'Pending Approval', Icons.hourglass_top_rounded),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kIndigo.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.venueName.isNotEmpty ? app.venueName : 'Venue',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Volunteer application',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewStatus,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('View Status'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceSection extends StatelessWidget {
  final List<SavedPass> passes;
  final ValueChanged<SavedPass> onViewPass;

  const _AudienceSection({required this.passes, required this.onViewPass});

  @override
  Widget build(BuildContext context) {
    final venueCount = passes.map((p) => p.venueId).toSet().length;
    final now = DateTime.now();

    final sorted = [...passes]..sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return a.eventDate!.compareTo(b.eventDate!);
      });
    final upcoming =
        sorted.where((p) => p.eventDate == null || !p.eventDate!.isBefore(
              DateTime(now.year, now.month, now.day),
            )).toList();
    final past = sorted
        .where((p) =>
            p.eventDate != null &&
            p.eventDate!.isBefore(DateTime(now.year, now.month, now.day)))
        .toList()
        .reversed
        .toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.dashboard_customize_rounded,
                value: '$venueCount',
                label: venueCount == 1 ? 'Venue' : 'Venues Attending',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.confirmation_number_rounded,
                value: '${passes.length}',
                label: passes.length == 1 ? 'Booking' : 'Total Bookings',
              ),
            ),
          ],
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SubLabel(text: 'UPCOMING'),
          const SizedBox(height: 10),
          for (var i = 0; i < upcoming.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _PassTile(pass: upcoming[i], onTap: () => onViewPass(upcoming[i])),
          ],
        ],
        if (past.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SubLabel(text: 'PAST'),
          const SizedBox(height: 10),
          for (var i = 0; i < past.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _PassTile(
              pass: past[i],
              onTap: () => onViewPass(past[i]),
              dimmed: true,
            ),
          ],
        ],
      ],
    );
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 10.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PassTile extends StatelessWidget {
  final SavedPass pass;
  final VoidCallback onTap;
  final bool dimmed;
  const _PassTile({
    required this.pass,
    required this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = dimmed ? 0.045 : 0.08;
    return Material(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kIndigo.withValues(alpha: dimmed ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.confirmation_number_rounded,
                    color: Colors.white.withValues(alpha: dimmed ? 0.5 : 1),
                    size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pass.venueName.isNotEmpty ? pass.venueName : 'Venue',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: dimmed ? 0.6 : 1),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      pass.eventDate != null
                          ? '${DateFormat('MMM d, yyyy').format(pass.eventDate!)} · Seat ${pass.seatLabel}'
                          : 'Seat ${pass.seatLabel}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String? phone;
  const _InfoCard({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_rounded,
              color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Text(
            'Subscribed number',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
          const Spacer(),
          Text(
            phone ?? '—',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatTile(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: brandAccent(context).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? kError : Colors.white;
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Appearance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: appPalettes.map((p) {
              final selected = themeService.palette == p.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => themeService.setPalette(p.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: p.seed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.2),
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                  selected: themeService.mode == ThemeMode.light,
                  onTap: () => themeService.setMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                  selected: themeService.mode == ThemeMode.dark,
                  onTap: () => themeService.setMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  icon: Icons.brightness_auto_rounded,
                  label: 'System',
                  selected: themeService.mode == ThemeMode.system,
                  onTap: () => themeService.setMode(ThemeMode.system),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.white70, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
