import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/subscription_service.dart';

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
    final ok = await context
        .read<SubscriptionService>()
        .sendOtp(_phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1B4B), Color(0xFF3730A3)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackButton(onTap: () => context.pop()),
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
                              'We\'ll send a 6-digit OTP to verify your '
                              'number.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ).animate().fadeIn(delay: 250.ms),
                            const SizedBox(height: 28),
                            _GlassCard(
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
                                        fillColor:
                                            Colors.white.withValues(alpha: 0.06),
                                      ),
                                      validator: _validate,
                                    ),
                                    const SizedBox(height: 20),
                                    _PrimaryButton(
                                      label: 'Send OTP',
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

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kIndigoLight, kIndigo],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: kIndigo.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
