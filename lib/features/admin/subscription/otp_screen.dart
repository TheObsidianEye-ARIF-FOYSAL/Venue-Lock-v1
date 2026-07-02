import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/subscription_service.dart';
import 'widgets/auth_widgets.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
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
    final ok = await context.read<SubscriptionService>().verifyOtp(_code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      // Pop the whole subscribe-flow stack back to root; the router's
      // top-level redirect (watching SubscriptionService reactively)
      // takes it from there.
      while (context.canPop()) {
        context.pop();
      }
      context.go('/admin/login');
    } else {
      final err = context.read<SubscriptionService>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Invalid OTP'),
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
    final phone = context.watch<SubscriptionService>().phone ?? '';
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
                              child: const Icon(Icons.sms_outlined,
                                  color: Colors.white, size: 32),
                            ).animate().scale(
                                delay: 100.ms,
                                duration: 400.ms,
                                curve: Curves.easeOutBack),
                            const SizedBox(height: 24),
                            Text(
                              'Verify OTP',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ).animate().fadeIn(delay: 150.ms),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                                children: [
                                  const TextSpan(
                                      text: 'Enter the 6-digit code sent '
                                          'to '),
                                  TextSpan(
                                    text: phone,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 250.ms),
                            const SizedBox(height: 28),
                            GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    ).animate().scale(delay: delay, duration: 300.ms);
  }
}
