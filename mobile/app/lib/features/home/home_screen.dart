import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:timetable_app/core/refresh/app_refresh.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/api/api_exception.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/features/home/home_schedule_summary.dart";
import "package:timetable_app/features/schedule/schedule_occurrences.dart";

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetableAsync = ref.watch(selectedSectionTimetableProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today"),
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
                        "Pick a section to unlock the timetable, offline cache, and current class view.",
                  );
                }

                final now = DateTime.now();
                final summary = buildHomeScheduleSummary(
                  timetable: timetable,
                  now: now,
                );

                return _HeroCard(
                  timetable: timetable,
                  summary: summary,
                  dayLabel: _dayLabelForWeekday(now.weekday),
                );
              },
              loading: () => const _LoadingCard(
                title: "Loading timetable",
                message:
                    "Checking the latest schedule for the selected section.",
              ),
              error: (error, stackTrace) => _ErrorStateCard(
                title: "Could not load timetable",
                error: error,
                onRetry: () => _refreshData(context, ref),
              ),
            ),
            const SizedBox(height: 16),
            if (timetableAsync.valueOrNull?.isStale == true)
              _CacheBanner(
                icon: Icons.wifi_off_rounded,
                message:
                    "Showing the last successful timetable sync because the backend is unreachable.",
                cachedAt: timetableAsync.valueOrNull?.cachedAt,
              ),
            if (timetableAsync.valueOrNull?.isStale == true)
              const SizedBox(height: 16),
            timetableAsync.when(
              data: (timetable) {
                if (timetable == null) {
                  return const SizedBox.shrink();
                }

                final now = DateTime.now();
                final summary = buildHomeScheduleSummary(
                  timetable: timetable,
                  now: now,
                );
                final dayLabel = _dayLabelForWeekday(now.weekday);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CurrentAndNextCard(
                      summary: summary,
                      dayLabel: dayLabel,
                    ),
                    const SizedBox(height: 16),
                    _TodayScheduleCard(
                      summary: summary,
                      dayLabel: dayLabel,
                    ),
                    const SizedBox(height: 16),
                    _QuickActionsCard(
                        sectionCode: timetable.section.sectionCode),
                  ],
                );
              },
              loading: () => const _LoadingCard(
                title: "Preparing today",
                message: "Building the current and upcoming class view.",
              ),
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
      ? "Refresh failed, so cached data is still being shown where available."
      : "Refresh failed. Try again when the timetable service is reachable.";

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
    ),
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.timetable,
    required this.summary,
    required this.dayLabel,
  });

  final SectionTimetable timetable;
  final HomeScheduleSummary summary;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final version = timetable.timetableVersion;
    final freshness = timetable.cachedAt == null
        ? "Ready to sync"
        : "Last sync ${_formatTimestamp(timetable.cachedAt!)}";

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF174A41),
              Color(0xFF24695D),
              Color(0xFF6BB89A),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timetable.section.sectionCode,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _heroHeadline(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFF4FAF7),
                  ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroBadge(
                  label: "Today",
                  value:
                      "${summary.todayMeetings.length} ${summary.todayMeetings.length == 1 ? "class" : "classes"}",
                ),
                _HeroBadge(
                  label: "Version",
                  value: version.versionId,
                ),
                _HeroBadge(
                  label: "Sync",
                  value: freshness,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _heroHeadline() {
    if (summary.currentMeeting != null) {
      return "You are currently in ${summary.currentMeeting!.meeting.courseName}.";
    }

    if (summary.nextMeeting != null) {
      return "Next up: ${summary.nextMeeting!.meeting.courseName} at ${summary.nextMeeting!.meeting.startTime}.";
    }

    if (summary.todayMeetings.isEmpty) {
      return "No classes scheduled for $dayLabel.";
    }

    return "All classes for $dayLabel are complete.";
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xCCFFFFFF),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CurrentAndNextCard extends StatelessWidget {
  const _CurrentAndNextCard({
    required this.summary,
    required this.dayLabel,
  });

  final HomeScheduleSummary summary;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Current and next",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatusPanel(
                    title: "Current",
                    emptyLabel: summary.todayMeetings.isEmpty
                        ? "No class today"
                        : "No class right now",
                    emptyDescription: summary.todayMeetings.isEmpty
                        ? "No meetings are scheduled for $dayLabel."
                        : "No active class in this slot.",
                    meeting: summary.currentMeeting,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusPanel(
                    title: "Next",
                    emptyLabel: summary.todayMeetings.isEmpty
                        ? "Nothing upcoming today"
                        : "Done for today",
                    emptyDescription: summary.todayMeetings.isEmpty
                        ? "No meetings are scheduled for $dayLabel."
                        : "No additional classes remain today.",
                    meeting: summary.nextMeeting,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    required this.emptyLabel,
    required this.emptyDescription,
    required this.meeting,
  });

  final String title;
  final String emptyLabel;
  final String emptyDescription;
  final ScheduleMeetingOccurrence? meeting;

  @override
  Widget build(BuildContext context) {
    final subtitleBits = <String>[
      if (meeting?.meeting.room case final room? when room.isNotEmpty) room,
      if (meeting?.meeting.online == true) "Online",
      if (meeting?.meeting.meetingType case final type? when type.isNotEmpty)
        type,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            meeting?.meeting.courseName ?? emptyLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            meeting == null
                ? emptyDescription
                : "${meeting!.meeting.startTime} - ${meeting!.meeting.endTime}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (subtitleBits.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitleBits.join(" • "),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayScheduleCard extends StatelessWidget {
  const _TodayScheduleCard({
    required this.summary,
    required this.dayLabel,
  });

  final HomeScheduleSummary summary;
  final String dayLabel;

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
                    "$dayLabel schedule",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(
                    "${summary.todayMeetings.length} ${summary.todayMeetings.length == 1 ? "class" : "classes"}",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (summary.todayMeetings.isEmpty)
              const _StateMessage(
                message:
                    "No classes are scheduled today. Use the week view to scan the rest of the timetable.",
              )
            else
              for (var index = 0;
                  index < summary.todayMeetings.length;
                  index++) ...[
                _MeetingTile(
                  occurrence: summary.todayMeetings[index],
                  highlightCurrent:
                      summary.currentMeeting == summary.todayMeetings[index],
                  highlightNext:
                      summary.nextMeeting == summary.todayMeetings[index],
                ),
                if (index < summary.todayMeetings.length - 1)
                  const Divider(height: 24),
              ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.sectionCode,
  });

  final String sectionCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Next steps",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "Review the full week, switch sections, or refresh when the department publishes a new timetable version.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => context.go("/week"),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text("Open week view"),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.go("/select-section"),
                  icon: const Icon(Icons.swap_horizontal_circle_outlined),
                  label: Text("Change $sectionCode"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({
    required this.occurrence,
    required this.highlightCurrent,
    required this.highlightNext,
  });

  final ScheduleMeetingOccurrence occurrence;
  final bool highlightCurrent;
  final bool highlightNext;

  @override
  Widget build(BuildContext context) {
    final subtitleBits = <String>[
      if (occurrence.meeting.instructor != null &&
          occurrence.meeting.instructor!.isNotEmpty)
        occurrence.meeting.instructor!,
      if (occurrence.meeting.room != null &&
          occurrence.meeting.room!.isNotEmpty)
        occurrence.meeting.room!,
      if (occurrence.meeting.online) "Online",
      if (occurrence.meeting.meetingType != null &&
          occurrence.meeting.meetingType!.isNotEmpty)
        occurrence.meeting.meetingType!,
    ];

    final accent = highlightCurrent
        ? const Color(0xFF174A41)
        : highlightNext
            ? const Color(0xFF6B4E16)
            : const Color(0xFFEAF2EE);
    final textColor = highlightCurrent || highlightNext
        ? Colors.white
        : Theme.of(context).textTheme.titleMedium?.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 94,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                occurrence.meeting.startTime,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textColor,
                    ),
              ),
              Text(
                occurrence.meeting.endTime,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: highlightCurrent || highlightNext
                          ? const Color(0xFFF7FBF9)
                          : null,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    occurrence.meeting.courseName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (highlightCurrent)
                    const Chip(
                      label: Text("Current"),
                    ),
                  if (highlightNext)
                    const Chip(
                      label: Text("Next"),
                    ),
                ],
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

class _CacheBanner extends StatelessWidget {
  const _CacheBanner({
    required this.icon,
    required this.message,
    required this.cachedAt,
  });

  final IconData icon;
  final String message;
  final String? cachedAt;

  @override
  Widget build(BuildContext context) {
    final freshness = cachedAt == null ? null : _formatTimestamp(cachedAt!);

    return Card(
      color: const Color(0xFFFFF6E7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                freshness == null ? message : "$message Cached at $freshness.",
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
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
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
      title: title,
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

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

String _dayLabelForWeekday(int weekday) {
  return switch (weekday) {
    DateTime.monday => "Monday",
    DateTime.tuesday => "Tuesday",
    DateTime.wednesday => "Wednesday",
    DateTime.thursday => "Thursday",
    DateTime.friday => "Friday",
    DateTime.saturday => "Saturday",
    _ => "Sunday",
  };
}

String _formatTimestamp(String iso8601) {
  final timestamp = DateTime.tryParse(iso8601);
  if (timestamp == null) {
    return iso8601;
  }

  final local = timestamp.toLocal();
  final month = switch (local.month) {
    1 => "Jan",
    2 => "Feb",
    3 => "Mar",
    4 => "Apr",
    5 => "May",
    6 => "Jun",
    7 => "Jul",
    8 => "Aug",
    9 => "Sep",
    10 => "Oct",
    11 => "Nov",
    _ => "Dec",
  };

  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, "0");
  final suffix = local.hour >= 12 ? "PM" : "AM";

  return "${local.day} $month, $hour:$minute $suffix";
}
