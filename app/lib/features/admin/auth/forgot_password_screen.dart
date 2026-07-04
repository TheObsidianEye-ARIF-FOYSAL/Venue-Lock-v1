import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/auth_service.dart';
import '../subscription/widgets/auth_widgets.dart';

/// Phone -> OTP -> new password, in that order, mirroring the subscription
/// gate's Phone/OTP screens but scoped to AuthService's password-reset flow.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _pageController = PageController();

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                AuthBackButton(
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/admin/login'),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _PhoneStep(onSent: () => _goToStep(1)),
                      _OtpStep(onVerified: () => _goToStep(2)),
                      const _NewPasswordStep(),
                    ],
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

class _PhoneStep extends StatefulWidget {
  final VoidCallback onSent;
  const _PhoneStep({required this.onSent});

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok =
        await context.read<AuthService>().sendPasswordResetOtp(_phoneCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      widget.onSent();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send OTP. Please try again.'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
                child: const Icon(Icons.lock_reset_rounded,
                    color: Colors.white, size: 32),
              ).animate().scale(
                  delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              Text(
                'Reset your password',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 8),
              Text(
                'Enter the phone number on your account. We\'ll send a '
                '6-digit OTP to verify it\'s you.',
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          hintText: '01812345678',
                          labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6)),
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3)),
                          prefixIcon: const Icon(Icons.phone_android_outlined,
                              color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      AuthPrimaryButton(
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
    );
  }
}

class _OtpStep extends StatefulWidget {
  final VoidCallback onVerified;
  const _OtpStep({required this.onVerified});

  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  Future<void> _submit() async {
    if (_code.length < 6) return;
    setState(() => _loading = true);
    final ok = await context.read<AuthService>().verifyPasswordResetOtp(_code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      widget.onVerified();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid OTP'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      for (final c in _ctrls) {
        c.clear();
      }
      _nodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
                child: const Icon(Icons.sms_outlined,
                    color: Colors.white, size: 32),
              ).animate().scale(
                  delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              Text(
                'Verify OTP',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to your phone.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ).animate().fadeIn(delay: 250.ms),
              const SizedBox(height: 28),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        return _OtpBox(
                          controller: _ctrls[i],
                          node: _nodes[i],
                          onChanged: (v) {
                            if (v.isNotEmpty && i < 5) {
                              _nodes[i + 1].requestFocus();
                            }
                            if (v.isNotEmpty && i == 5) {
                              _submit();
                            }
                            setState(() {});
                          },
                          delay: (100 + i * 60).ms,
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: 'Verify',
                      loading: _loading,
                      onTap: _submit,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 350.ms).slideY(
                  begin: 0.08, delay: 350.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode node;
  final ValueChanged<String> onChanged;
  final Duration delay;

  const _OtpBox({
    required this.controller,
    required this.node,
    required this.onChanged,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: controller,
        focusNode: node,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          filled: false,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    ).animate().scale(delay: delay, duration: 300.ms);
  }
}

class _NewPasswordStep extends StatefulWidget {
  const _NewPasswordStep();

  @override
  State<_NewPasswordStep> createState() => _NewPasswordStepState();
}

class _NewPasswordStepState extends State<_NewPasswordStep> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error =
        await context.read<AuthService>().resetPassword(_passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset. You\'re signed in.'),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
                child: const Icon(Icons.key_rounded,
                    color: Colors.white, size: 32),
              ).animate().scale(
                  delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              Text(
                'Set a new password',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 28),
              GlassCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'New password',
                          helperText: 'At least 6 characters',
                          helperStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5)),
                          labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6)),
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white70),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 6) return 'Minimum 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirm,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6)),
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white70),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      AuthPrimaryButton(
                        label: 'Reset Password',
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
    );
  }
}
