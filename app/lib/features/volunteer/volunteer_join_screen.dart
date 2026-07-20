import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/services/student_profile_service.dart';
import '../../core/services/volunteer_service.dart';
import '../admin/subscription/widgets/auth_widgets.dart';

class VolunteerJoinScreen extends StatefulWidget {
  const VolunteerJoinScreen({super.key});

  @override
  State<VolunteerJoinScreen> createState() => _VolunteerJoinScreenState();
}

const _kVolunteerAccent = Color(0xFF10B981);

class _VolunteerJoinScreenState extends State<VolunteerJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _service = VolunteerService();
  bool _loading = false;
  bool _checkingExisting = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = context.read<StudentProfileService>().name;
    _resumeIfActive();
  }

  Future<void> _resumeIfActive() async {
    final active = await _service.getActiveApplication();
    if (!mounted) return;
    if (active != null) {
      context.go('/volunteer/status/${active.venueId}/${active.volunteerId}');
      return;
    }
    setState(() => _checkingExisting = false);
  }

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await _service.apply(
      accessCode: _codeCtrl.text.trim().toUpperCase(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid code or venue is not open. Please check and try again.'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.go('/volunteer/status/${result.venueId}/${result.volunteerId}');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        decoration: authGradient(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _kVolunteerAccent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.volunteer_activism_rounded,
                          color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Volunteer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.horizontalPadding(context),
                ),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _kVolunteerAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                                Icons.volunteer_activism_outlined,
                                color: _kVolunteerAccent,
                                size: 28),
                          ).animate().scale(
                              duration: 400.ms,
                              curve: Curves.easeOutBack,
                              begin: const Offset(0.6, 0.6)),
                          const SizedBox(height: 20),
                          Text(
                            'Apply to Volunteer',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter the venue code and your details. The '
                            'organizer must approve you before you can scan '
                            'entry passes.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _codeCtrl,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.characters,
                            enabled: !_loading,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'ABCDEF',
                              counterText: '',
                            ),
                            onChanged: (v) {
                              final upper = v.toUpperCase();
                              if (v != upper) {
                                _codeCtrl.value = TextEditingValue(
                                  text: upper,
                                  selection: TextSelection.collapsed(
                                      offset: upper.length),
                                );
                              }
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter the venue code';
                              }
                              if (v.length != 6) {
                                return 'Code must be 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone (optional)',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: _kVolunteerAccent),
                            onPressed: _loading ? null : _apply,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
