import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/pass_storage.dart';
import '../../../core/services/student_profile_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/volunteer_service.dart';
import '../../admin/subscription/widgets/auth_widgets.dart';
import 'profile_widgets.dart';

/// The profile hub: personal details stay inline here, and everything else
/// — Admin Console, Entry Passes, Volunteering, Appearance — is its own
/// screen reached via a navigation row, so this screen never turns into a
/// wall of unrelated content. Account-level actions (change password,
/// logout, unsubscribe, delete account) live in one card at the very
/// bottom. A person can be Admin, Volunteer, and Audience on the same
/// device at once — the header shows every badge that applies, not just
/// one.
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

  // Only fetches what the header badges / nav-row subtitles need — the
  // sub-screens load their own full detail (including live status) when
  // opened.
  Future<void> _loadExtras() async {
    final app = await VolunteerService().getActiveApplication();
    final passes = await PassStorage.getPasses();
    if (!mounted) return;
    setState(() {
      _volunteerApp = app;
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

    // Only a logged-in admin has a password to confirm with — the local
    // Audience/Volunteer profile isn't tied to any account.
    if (context.read<AuthService>().isLoggedIn) {
      final password = await _promptPassword(context);
      if (password == null || !mounted) return; // cancelled
      setState(() => _saving = true);
      final error =
          await context.read<AuthService>().verifyPassword(password);
      if (!mounted) return;
      if (error != null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: kError,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else {
      setState(() => _saving = true);
    }

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

  Future<String?> _promptPassword(BuildContext context) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ctrl.text);
              }
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ctrl.text);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result;
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
    final displayName = isAdmin ? auth.displayName : profile.name;

    final badges = <_RoleBadge>[
      if (isAdmin)
        const _RoleBadge('Admin', Icons.admin_panel_settings_rounded),
      if (_volunteerApp != null)
        const _RoleBadge('Volunteer', Icons.volunteer_activism_rounded),
      if (_passes.isNotEmpty)
        const _RoleBadge('Audience', Icons.confirmation_number_rounded),
      if (!isAdmin && _volunteerApp == null && _passes.isEmpty)
        const _RoleBadge('Member', Icons.person_rounded),
    ];

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
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.push('/'),
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
                    : ProfileScrollBody(
                        child: Column(
                          children: [
                            _ProfileHeader(name: displayName, badges: badges)
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.1, duration: 400.ms),
                            const SizedBox(height: 24),
                            _Section(
                              label: 'PERSONAL DETAILS',
                              delay: 60,
                              child: _BookingDetailsCard(
                                formKey: _formKey,
                                nameCtrl: _nameCtrl,
                                emailCtrl: _emailCtrl,
                                rollCtrl: _rollCtrl,
                                saving: _saving,
                                onSave: _save,
                              ),
                            ),
                            _Section(
                              label: 'SECTIONS',
                              delay: 120,
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Column(
                                  children: [
                                    if (isAdmin)
                                      SettingsRow(
                                        icon: Icons
                                            .admin_panel_settings_rounded,
                                        label: 'Admin Console',
                                        subtitle:
                                            'Venues, stats & subscription',
                                        onTap: () => context
                                            .push('/student/profile/console'),
                                      ),
                                    SettingsRow(
                                      icon: Icons.confirmation_number_rounded,
                                      label: 'Entry Passes',
                                      subtitle: _passes.isEmpty
                                          ? 'No bookings yet'
                                          : '${_passes.length} booking${_passes.length == 1 ? '' : 's'}',
                                      onTap: () => context
                                          .push('/student/profile/passes'),
                                    ),
                                    SettingsRow(
                                      icon: Icons.volunteer_activism_rounded,
                                      label: 'Volunteering',
                                      subtitle: _volunteerApp == null
                                          ? 'Not volunteering'
                                          : _volunteerApp!.venueName,
                                      onTap: () => context.push(
                                          '/student/profile/volunteering'),
                                    ),
                                    SettingsRow(
                                      icon: Icons.palette_rounded,
                                      label: 'Appearance',
                                      subtitle: 'Theme & colors',
                                      onTap: () => context.push(
                                          '/student/profile/appearance'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isAdmin)
                              _Section(
                                label: 'ACCOUNT',
                                delay: 180,
                                isLast: true,
                                child: GlassCard(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Column(
                                    children: [
                                      SettingsRow(
                                        icon: Icons.password_rounded,
                                        label: 'Change Password',
                                        onTap: () =>
                                            _handleChangePassword(context),
                                      ),
                                      SettingsRow(
                                        icon: Icons.logout_rounded,
                                        label: 'Logout',
                                        onTap: () async {
                                          final ok = await _confirm(context,
                                              title: 'Logout?',
                                              message:
                                                  'You will be signed out '
                                                  'and redirected to the '
                                                  'login screen. Your '
                                                  'subscription remains '
                                                  'active.',
                                              confirmLabel: 'Logout');
                                          if (!ok || !context.mounted) return;
                                          await context
                                              .read<AuthService>()
                                              .logout();
                                          if (context.mounted) {
                                            context.go('/admin/login');
                                          }
                                        },
                                      ),
                                      const CardDivider(),
                                      SettingsRow(
                                        icon: Icons.unsubscribe_rounded,
                                        label: 'Unsubscribe',
                                        destructive: true,
                                        onTap: () async {
                                          final ok = await _confirm(context,
                                              title: 'Unsubscribe?',
                                              message: 'Your subscription '
                                                  'will be cancelled and '
                                                  'you will be signed out. '
                                                  'You will need to '
                                                  'subscribe again to use '
                                                  'the admin console.',
                                              confirmLabel: 'Unsubscribe',
                                              destructive: true);
                                          if (!ok || !context.mounted) return;
                                          final unsubOk = await context
                                              .read<SubscriptionService>()
                                              .unsubscribe();
                                          if (!context.mounted) return;
                                          if (unsubOk) {
                                            await context
                                                .read<AuthService>()
                                                .logout();
                                            if (context.mounted) {
                                              context.go('/admin/subscribe');
                                            }
                                          } else {
                                            final err = context
                                                .read<SubscriptionService>()
                                                .error;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(err ??
                                                    'Unsubscribe failed'),
                                                backgroundColor: kError,
                                                behavior: SnackBarBehavior
                                                    .floating,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      SettingsRow(
                                        icon: Icons.delete_forever_rounded,
                                        label: 'Delete Account',
                                        destructive: true,
                                        onTap: () =>
                                            _handleDeleteAccount(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
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

class _RoleBadge {
  final String label;
  final IconData icon;
  const _RoleBadge(this.label, this.icon);
}

/// One consistent wrapper for every section on the profile screen: a small
/// caps label followed by exactly one card.
class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  final int delay;
  final bool isLast;
  const _Section({
    required this.label,
    required this.child,
    required this.delay,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child,
        ],
      ).animate().fadeIn(delay: delay.ms, duration: 350.ms).slideY(
          begin: 0.05, delay: delay.ms, duration: 350.ms),
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

  static const _fieldStyle = TextStyle(color: Colors.white);
  static InputDecoration _decoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kError),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Used to prefill booking and volunteer forms on this device.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: nameCtrl,
              style: _fieldStyle,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('Full Name', Icons.person_outline),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: emailCtrl,
              style: _fieldStyle,
              keyboardType: TextInputType.emailAddress,
              decoration: _decoration('Email', Icons.email_outlined),
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
              style: _fieldStyle,
              decoration:
                  _decoration('Roll Number (optional)', Icons.badge_outlined),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AuthPrimaryButton(
                label: 'Save Profile',
                loading: saving,
                onTap: onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar + name + a row of every role badge that currently applies (a
/// person can be Admin, Volunteer, and Audience on the same device at the
/// same time — this is never collapsed down to a single "primary" role).
class _ProfileHeader extends StatelessWidget {
  final String name;
  final List<_RoleBadge> badges;
  const _ProfileHeader({required this.name, required this.badges});

  @override
  Widget build(BuildContext context) {
    final seed = context.watch<ThemeService>().seedColor;
    final dark = brandAccent(context);
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
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
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name.isNotEmpty ? name : 'Welcome',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: badges
              .map((b) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(b.icon, color: Colors.white, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          b.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
