import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/subscription_service.dart';
import 'widgets/auth_widgets.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your phone';
    final d = v.replaceAll(RegExp(r'[^0-9]'), '');
    final normalized = d.startsWith('880') && d.length > 10
        ? d.substring(3)
        : (d.startsWith('88') && d.length > 11 ? d.substring(2) : d);
    if (normalized.length != 11) {
      return 'Enter a valid 11-digit phone number';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final service = context.read<SubscriptionService>();

    // Already have a login account for this number? They passed this gate
    // once before (an account can't exist without it) — skip the OTP
    // round-trip and let them go straight to phone+password login.
    final hasAccount = await service.checkExistingAccount(phone);
    if (!mounted) return;
    if (hasAccount == true) {
      await service.markSubscribedLocally(phone);
      if (!mounted) return;
      setState(() => _loading = false);
      context.go('/admin/login');
      return;
    }

    final ok = await service.sendOtp(phone);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.push('/admin/subscribe/otp');
    } else {
      final err = context.read<SubscriptionService>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Unable to request OTP'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: authGradient(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthBackButton(onTap: () => context.pop()),
                const SizedBox(height: 32),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.phone_android_rounded,
                                  color: Colors.white, size: 32),
                            ).animate().scale(
                                delay: 100.ms,
                                duration: 400.ms,
                                curve: Curves.easeOutBack),
                            const SizedBox(height: 24),
                            Text(
                              'Enter mobile number',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ).animate().fadeIn(delay: 150.ms).slideX(
                                begin: -0.1, delay: 150.ms, duration: 400.ms),
                            const SizedBox(height: 8),
                            Text(
                              'Already subscribed? We\'ll take you straight '
                              'to login. Otherwise, we\'ll send a 6-digit '
                              'OTP to verify your number.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ).animate().fadeIn(delay: 250.ms),
                            const SizedBox(height: 28),
                            GlassCard(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      style: const TextStyle(
                                          color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Mobile number',
                                        hintText: '01812345678',
                                        labelStyle: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.6)),
                                        hintStyle: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.3)),
                                        prefixIcon: const Icon(
                                            Icons.phone_android_outlined,
                                            color: Colors.white70),
                                        filled: true,
                                        fillColor: Colors.white
                                            .withValues(alpha: 0.06),
                                      ),
                                      validator: _validate,
                                    ),
                                    const SizedBox(height: 20),
                                    AuthPrimaryButton(
                                      label: 'Continue',
                                      loading: _loading,
                                      onTap: _submit,
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(delay: 350.ms).slideY(
                                begin: 0.08, delay: 350.ms, duration: 400.ms),
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
      ),
    );
  }
}
