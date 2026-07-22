import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../app/responsive.dart';
import '../../../app/theme.dart';
import '../../../core/models/seat.dart';
import '../../../core/models/venue.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/pass_storage.dart';
import '../../../core/services/student_profile_service.dart';

class BookingScreen extends StatefulWidget {
  final String venueId;
  final String seatId;

  const BookingScreen({
    super.key,
    required this.venueId,
    required this.seatId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();

  bool _booking = false;
  bool _loading = true;
  Venue? _venue;
  Seat? _seat;

  @override
  void initState() {
    super.initState();
    final profile = context.read<StudentProfileService>();
    _nameCtrl.text = profile.name;
    _emailCtrl.text = profile.email;
    _rollCtrl.text = profile.roll;
    _loadData();
  }

  Future<void> _loadData() async {
    final appState = context.read<AppState>();
    final results = await Future.wait([
      appState.getVenueByFirestoreId(widget.venueId),
      appState.getSeats(widget.venueId),
    ]);
    if (!mounted) return;
    setState(() {
      _venue = results[0] as Venue?;
      final seats = results[1] as List<Seat>;
      _seat = seats.where((s) => s.id == widget.seatId).firstOrNull;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _rollCtrl.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _booking = true);

    final token = await context.read<AppState>().bookSeat(
          venueId: widget.venueId,
          seatId: widget.seatId,
          studentName: _nameCtrl.text.trim(),
          studentEmail: _emailCtrl.text.trim(),
          rollNumber: _rollCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _booking = false);

    if (token != null) {
      await context.read<StudentProfileService>().save(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            roll: _rollCtrl.text.trim(),
          );
      if (!mounted) return;
      await PassStorage.savePass(SavedPass(
        venueId: widget.venueId,
        seatId: widget.seatId,
        venueName: _venue?.name ?? '',
        seatLabel: _seat?.id ?? widget.seatId,
        eventDate: _venue?.eventDate,
      ));
      if (!mounted) return;
      // Replaces the booking form, keeping the seat map underneath so back
      // stays inside the app.
      context.pushReplacement('/student/pass/${widget.venueId}/${widget.seatId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This seat is no longer available. Please choose another.'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Your Seat'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ResponsiveScaffoldBody(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seat badge + section
                      if (_seat != null)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: kIndigo,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                'Seat ${_seat!.id}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (_seat!.section.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: kIndigo.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  _seat!.section,
                                  style: const TextStyle(
                                    color: kIndigo,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (_venue != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _venue!.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          DateFormat('MMM d, yyyy').format(_venue!.eventDate),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'YOUR INFORMATION',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                                letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 12),
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
                        controller: _emailCtrl,
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
                        controller: _rollCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Roll Number',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Roll number is required'
                                : null,
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: _booking ? null : _book,
                        child: _booking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Book My Seat'),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ),
    );
  }
}
