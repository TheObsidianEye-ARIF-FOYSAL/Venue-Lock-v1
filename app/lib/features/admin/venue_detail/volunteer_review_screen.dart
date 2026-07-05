import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/volunteer_service.dart';

/// Lets an admin review pending volunteer applications for a venue and
/// approve or reject them. Approved volunteers gain scanning access via
/// venuelock_volunteer_checkin.php, scoped to just this venue.
class VolunteerReviewScreen extends StatefulWidget {
  final String venueId;
  const VolunteerReviewScreen({super.key, required this.venueId});

  @override
  State<VolunteerReviewScreen> createState() => _VolunteerReviewScreenState();
}

class _VolunteerReviewScreenState extends State<VolunteerReviewScreen> {
  List<VolunteerInfo>? _volunteers;
  bool _busyId(String id) => _busyIds.contains(id);
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<AppState>().listVolunteers(widget.venueId);
    if (!mounted) return;
    setState(() => _volunteers = list);
  }

  Future<void> _review(String volunteerId, bool approve) async {
    setState(() => _busyIds.add(volunteerId));
    final ok = await context.read<AppState>().reviewVolunteer(
          venueId: widget.venueId,
          volunteerId: volunteerId,
          approve: approve,
        );
    if (!mounted) return;
    setState(() => _busyIds.remove(volunteerId));
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update application'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final volunteers = _volunteers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Applications'),
        centerTitle: false,
      ),
      body: volunteers == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: volunteers.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No volunteer applications yet')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: volunteers.length,
                      itemBuilder: (ctx, i) {
                        final v = volunteers[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: kIndigo.withValues(alpha: 0.1),
                              child: Text(
                                v.name.isNotEmpty
                                    ? v.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: kIndigo,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(v.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(v.phone?.isNotEmpty == true
                                ? '${v.phone} · ${v.status}'
                                : v.status),
                            trailing: v.status == 'pending'
                                ? _busyId(v.id)
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.check_circle_outline,
                                                color: kSuccess),
                                            onPressed: () =>
                                                _review(v.id, true),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.cancel_outlined,
                                                color: kError),
                                            onPressed: () =>
                                                _review(v.id, false),
                                          ),
                                        ],
                                      )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (v.status == 'approved'
                                              ? kSuccess
                                              : kError)
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      v.status.toUpperCase(),
                                      style: TextStyle(
                                        color: v.status == 'approved'
                                            ? kSuccess
                                            : kError,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
