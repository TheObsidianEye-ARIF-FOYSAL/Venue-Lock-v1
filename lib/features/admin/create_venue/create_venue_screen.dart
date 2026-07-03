import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/venue_section.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';

class CreateVenueScreen extends StatefulWidget {
  const CreateVenueScreen({super.key});

  @override
  State<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends State<CreateVenueScreen> {
  final _pageController = PageController();
  final _nameFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  int _currentStep = 0;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  bool _publishing = false;

  // Sections — start with one default section
  final List<VenueSection> _sections = [
    const VenueSection(name: 'General', rows: 10, cols: 10),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep == 0 && !_nameFormKey.currentState!.validate()) return;
    if (_currentStep == 1 && _sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one section'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep++);
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep--);
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final adminId = context.read<AuthService>().phone!;
      final venueId = await context.read<AppState>().createVenue(
            name: _nameCtrl.text.trim(),
            eventDate: _eventDate,
            sections: _sections,
            adminId: adminId,
          );
      if (mounted) context.go('/admin/venue/$venueId');
    } catch (e) {
      if (mounted) {
        setState(() => _publishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create venue: $e'),
            backgroundColor: kError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Venue'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/venues'),
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == _currentStep;
                final done = i < _currentStep;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 32 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: done || active
                        ? kIndigo
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(5),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1(
                  nameCtrl: _nameCtrl,
                  formKey: _nameFormKey,
                  eventDate: _eventDate,
                  onDatePick: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) setState(() => _eventDate = picked);
                  },
                  onNext: _nextPage,
                ),
                _Step2Sections(
                  sections: _sections,
                  onSectionsChanged: (updated) =>
                      setState(() => _sections
                        ..clear()
                        ..addAll(updated)),
                  onNext: _nextPage,
                  onBack: _prevPage,
                ),
                _Step3Review(
                  name: _nameCtrl.text,
                  date: _eventDate,
                  sections: _sections,
                  publishing: _publishing,
                  onBack: _prevPage,
                  onPublish: _publish,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Name + Date ───────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final GlobalKey<FormState> formKey;
  final DateTime eventDate;
  final VoidCallback onDatePick;
  final VoidCallback onNext;

  const _Step1({
    required this.nameCtrl,
    required this.formKey,
    required this.eventDate,
    required this.onDatePick,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Venue Details',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('What is this venue for?',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 24),
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Venue Name',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Venue name is required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Event Date',
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
                OutlinedButton.icon(
                  onPressed: onDatePick,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('MMM d, yyyy').format(eventDate)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onNext, child: const Text('Next')),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Sections ──────────────────────────────────────────────────────────

class _Step2Sections extends StatefulWidget {
  final List<VenueSection> sections;
  final ValueChanged<List<VenueSection>> onSectionsChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2Sections({
    required this.sections,
    required this.onSectionsChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step2Sections> createState() => _Step2SectionsState();
}

class _Step2SectionsState extends State<_Step2Sections> {
  late List<VenueSection> _sections;
  late List<TextEditingController> _nameCtrlList;

  @override
  void initState() {
    super.initState();
    _sections = List.from(widget.sections);
    _nameCtrlList = _sections
        .map((s) => TextEditingController(text: s.name))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _nameCtrlList) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSection() {
    setState(() {
      _sections.add(const VenueSection(name: 'New Section', rows: 5, cols: 5));
      _nameCtrlList.add(TextEditingController(text: 'New Section'));
    });
    _notify();
  }

  void _removeSection(int i) {
    if (_sections.length <= 1) return;
    setState(() {
      _nameCtrlList[i].dispose();
      _sections.removeAt(i);
      _nameCtrlList.removeAt(i);
    });
    _notify();
  }

  void _updateName(int i, String name) {
    _sections[i] = _sections[i].copyWith(name: name);
    _notify();
  }

  void _updateRows(int i, int rows) {
    setState(() => _sections[i] = _sections[i].copyWith(rows: rows));
    _notify();
  }

  void _updateCols(int i, int cols) {
    setState(() => _sections[i] = _sections[i].copyWith(cols: cols));
    _notify();
  }

  void _notify() => widget.onSectionsChanged(List.from(_sections));

  int get _totalSeats => _sections.fold(0, (acc, sec) => acc + sec.totalSeats);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Total seats summary
        Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kIndigo.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_seat, color: kIndigo, size: 20),
              const SizedBox(width: 10),
              Text(
                '$_totalSeats total seats across ${_sections.length} section${_sections.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: kIndigo, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sections.length,
            itemBuilder: (ctx, i) => _SectionCard(
              index: i,
              section: _sections[i],
              nameCtrl: _nameCtrlList[i],
              canDelete: _sections.length > 1,
              onNameChanged: (v) => _updateName(i, v),
              onRowsChanged: (v) => _updateRows(i, v),
              onColsChanged: (v) => _updateCols(i, v),
              onDelete: () => _removeSection(i),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.add),
            label: const Text('Add Section'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: widget.onBack, child: const Text('Back')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                    onPressed: widget.onNext, child: const Text('Review')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final int index;
  final VenueSection section;
  final TextEditingController nameCtrl;
  final bool canDelete;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<int> onRowsChanged;
  final ValueChanged<int> onColsChanged;
  final VoidCallback onDelete;

  const _SectionCard({
    required this.index,
    required this.section,
    required this.nameCtrl,
    required this.canDelete,
    required this.onNameChanged,
    required this.onRowsChanged,
    required this.onColsChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF6366F1), const Color(0xFF22C55E),
      const Color(0xFFF59E0B), const Color(0xFFEC4899),
      const Color(0xFF14B8A6), const Color(0xFFEF4444),
    ];
    final color = colors[index % colors.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Section Name',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: onNameChanged,
                  ),
                ),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: kError),
                    onPressed: onDelete,
                    tooltip: 'Remove section',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _SliderRow(
              label: 'Rows',
              value: section.rows,
              min: 1,
              max: 30,
              onChanged: onRowsChanged,
              color: color,
            ),
            _SliderRow(
              label: 'Columns',
              value: section.cols,
              min: 1,
              max: 25,
              onChanged: onColsChanged,
              color: color,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${section.rows} × ${section.cols} = ${section.totalSeats} seats',
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final Color color;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text('$label: $value',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            activeColor: color,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ],
    );
  }
}

// ── Step 3: Review ────────────────────────────────────────────────────────────

class _Step3Review extends StatelessWidget {
  final String name;
  final DateTime date;
  final List<VenueSection> sections;
  final bool publishing;
  final VoidCallback onBack;
  final VoidCallback onPublish;

  const _Step3Review({
    required this.name,
    required this.date,
    required this.sections,
    required this.publishing,
    required this.onBack,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final total = sections.fold(0, (acc, sec) => acc + sec.totalSeats);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Review & Publish',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Everything looks good?',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _ReviewRow(
                      icon: Icons.place_outlined,
                      label: 'Venue Name',
                      value: name.isEmpty ? '(not set)' : name),
                  const Divider(height: 20),
                  _ReviewRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Event Date',
                      value: DateFormat('MMM d, yyyy').format(date)),
                  const Divider(height: 20),
                  _ReviewRow(
                      icon: Icons.event_seat_outlined,
                      label: 'Total Seats',
                      value: '$total seats across ${sections.length} section${sections.length == 1 ? '' : 's'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Section breakdown
          ...sections.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.grid_view_outlined,
                        color: kIndigo),
                    title: Text(s.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${s.rows} rows × ${s.cols} cols'),
                    trailing: Text('${s.totalSeats} seats',
                        style: const TextStyle(
                            color: kIndigo, fontWeight: FontWeight.bold)),
                  ),
                ),
              )),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: publishing ? null : onBack,
                    child: const Text('Back')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: publishing ? null : onPublish,
                  icon: publishing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.rocket_launch_outlined),
                  label: Text(publishing ? 'Publishing…' : 'Publish Venue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReviewRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kIndigo, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 2),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
