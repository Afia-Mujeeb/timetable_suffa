import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:timetable_app/core/refresh/app_refresh.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/api/api_exception.dart";
import "package:timetable_app/data/models/timetable_models.dart";

class WeekTimetableScreen extends ConsumerWidget {
  const WeekTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetableAsync = ref.watch(selectedSectionTimetableProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Week"),
        actions: [
          IconButton(
            tooltip: "Change section",
            onPressed: () => context.go("/select-section"),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            tooltip: "Refresh",
            onPressed: () => _refreshData(context, ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshData(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            timetableAsync.when(
              data: (timetable) {
                if (timetable == null) {
                  return const _StateCard(
                    title: "Choose a section",
                    message:
                        "Select a section first to load the weekly timetable.",
                  );
                }

                return _HeaderCard(timetable: timetable);
              },
              loading: () => const _LoadingCard(
                title: "Loading week view",
                message: "Fetching the selected section timetable.",
              ),
              error: (error, stackTrace) => _ErrorStateCard(
                error: error,
                onRetry: () => _refreshData(context, ref),
              ),
            ),
            const SizedBox(height: 16),
            if (timetableAsync.valueOrNull?.isStale == true) ...[
              _CacheBanner(cachedAt: timetableAsync.valueOrNull?.cachedAt),
              const SizedBox(height: 16),
            ],
            timetableAsync.when(
              data: (timetable) {
                if (timetable == null) {
                  return const SizedBox.shrink();
                }

                if (timetable.meetings.isEmpty) {
                  return const _StateCard(
                    title: "No meetings scheduled",
                    message:
                        "The selected section exists, but there are no timetable meetings to render.",
                  );
                }

                final groupedMeetings = <DayKey, List<TimetableMeeting>>{};
                for (final meeting in timetable.meetings) {
                  groupedMeetings.putIfAbsent(
                    meeting.dayKey,
                    () => <TimetableMeeting>[],
                  );
                  groupedMeetings[meeting.dayKey]!.add(meeting);
                }

                for (final meetings in groupedMeetings.values) {
                  meetings.sort(
                    (left, right) =>
                        _parseMinutes(left.startTime) -
                        _parseMinutes(right.startTime),
                  );
                }

                return Column(
                  children: [
                    for (final day in DayKey.values)
                      if (groupedMeetings.containsKey(day)) ...[
                        _DayScheduleCard(
                          day: day,
                          meetings: groupedMeetings[day]!,
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _refreshData(BuildContext context, WidgetRef ref) async {
  final result = await refreshSelectedSectionData(ref);
  if (!context.mounted || !result.hadFailures) {
    return;
  }

  final message = result.usedCachedData
      ? "Refresh failed, so cached timetable data is still being shown."
      : "Refresh failed. Try again when the timetable service is reachable.";

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
    ),
  );
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.timetable,
  });

  final SectionTimetable timetable;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timetable.section.sectionCode,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              timetable.section.displayName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  icon: Icons.event_note_outlined,
                  label:
                      "${timetable.timetableVersion.meetingCount} meetings in version",
                ),
                _InfoPill(
                  icon: Icons.publish_outlined,
                  label: timetable.timetableVersion.versionId,
                ),
                _InfoPill(
                  icon: Icons.inventory_2_outlined,
                  label: timetable.timetableVersion.sourceFileName,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayScheduleCard extends StatelessWidget {
  const _DayScheduleCard({
    required this.day,
    required this.meetings,
  });

  final DayKey day;
  final List<TimetableMeeting> meetings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text("${meetings.length} classes"),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < meetings.length; index++) ...[
              _MeetingTile(meeting: meetings[index]),
              if (index < meetings.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({
    required this.meeting,
  });

  final TimetableMeeting meeting;

  @override
  Widget build(BuildContext context) {
    final subtitleBits = <String>[
      if (meeting.instructor != null && meeting.instructor!.isNotEmpty)
        meeting.instructor!,
      if (meeting.room != null && meeting.room!.isNotEmpty) meeting.room!,
      if (meeting.online) "Online",
      if (meeting.meetingType != null && meeting.meetingType!.isNotEmpty)
        meeting.meetingType!,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 94,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2EE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meeting.startTime,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                meeting.endTime,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meeting.courseName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (subtitleBits.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitleBits.join(" • "),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CacheBanner extends StatelessWidget {
  const _CacheBanner({
    required this.cachedAt,
  });

  final String? cachedAt;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF6E7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cachedAt == null
                    ? "Showing cached timetable data because the latest refresh failed."
                    : "Showing cached timetable data from $cachedAt because the latest refresh failed.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorStateCard extends StatelessWidget {
  const _ErrorStateCard({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      ApiException(statusCode: _, code: "not_found", message: _) =>
        "The selected section is not present in the published timetable anymore.",
      ApiException(statusCode: _, code: _, message: final message) => message,
      _ => "An unexpected error interrupted the request.",
    };

    return _StateCard(
      title: "Could not load timetable",
      message: message,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
            FilledButton.tonalIcon(
              onPressed: () => context.go("/select-section"),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text("Change section"),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      title: title,
      message: message,
      child: const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(minHeight: 6),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.message,
    this.child,
  });

  final String title;
  final String message;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

int _parseMinutes(String hhmm) {
  final parts = hhmm.split(":");
  if (parts.length != 2) {
    return 0;
  }

  final hours = int.tryParse(parts[0]) ?? 0;
  final minutes = int.tryParse(parts[1]) ?? 0;
  return (hours * 60) + minutes;
}
