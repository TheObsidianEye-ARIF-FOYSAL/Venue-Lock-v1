import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/responsive.dart';
import '../../../app/theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/pass_storage.dart';
import '../../admin/subscription/widgets/auth_widgets.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  List<SavedPass> _savedPasses = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPasses();
  }

  Future<void> _loadSavedPasses() async {
    final passes = await PassStorage.getPasses();
    if (!mounted) return;
    setState(() => _savedPasses = passes);
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final appState = context.read<AppState>();
    final code = _codeCtrl.text.trim().toUpperCase();
    final venue = await appState.getVenueByCode(code);

    if (!mounted) return;
    setState(() => _loading = false);

    if (venue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid code or venue is not open. Please check and try again.'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    appState.studentCurrentVenue = venue;
    context.push('/student/seats/${venue.id}');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      onPressed: () => context.go('/'),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.lock_outlined,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'VenueLock',
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
                              color: kIndigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                                Icons.confirmation_number_outlined,
                                color: kIndigo,
                                size: 28),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Join a Venue',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter the 6-character code from your organizer',
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
                                return 'Please enter the access code';
                              }
                              if (v.length != 6) {
                                return 'Code must be 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _loading ? null : _join,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Join Venue'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
              ),
              if (_savedPasses.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.horizontalPadding(context),
                  ),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: Text(
                              'MY ENTRY PASSES',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                          ),
                          for (final pass in _savedPasses)
                            ListTile(
                              leading: const Icon(
                                  Icons.confirmation_number_outlined,
                                  color: kIndigo),
                              title: Text(pass.venueName.isEmpty
                                  ? 'Seat ${pass.seatLabel}'
                                  : pass.venueName),
                              subtitle: Text('Seat ${pass.seatLabel}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(
                                  '/student/pass/${pass.venueId}/${pass.seatId}'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
