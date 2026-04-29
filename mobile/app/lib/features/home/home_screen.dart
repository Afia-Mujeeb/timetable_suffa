import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/api/api_exception.dart";
import "package:timetable_app/data/models/timetable_models.dart";

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(sectionsProvider);
    final selectedSectionCodeAsync = ref.watch(
      selectedSectionCodeControllerProvider,
    );
    final timetableAsync = ref.watch(selectedSectionTimetableProvider);

    ref.watch(selectedSectionBootstrapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Timetable"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sectionsProvider);
          ref.invalidate(selectedSectionTimetableProvider);
          await ref.read(sectionsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            const _HeroCard(),
            const SizedBox(height: 16),
            sectionsAsync.when(
              data: (snapshot) => _SectionSelectorCard(
                snapshot: snapshot,
                selectedSectionCode: selectedSectionCodeAsync.valueOrNull,
              ),
              loading: () => const _StateCard(
                title: "Loading sections",
                message:
                    "Fetching the current section list from the Worker API.",
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(minHeight: 6),
                ),
              ),
              error: (error, stackTrace) => _ErrorStateCard(
                title: "Could not load sections",
                error: error,
                onRetry: () => ref.invalidate(sectionsProvider),
              ),
            ),
            const SizedBox(height: 16),
            if (sectionsAsync.valueOrNull?.isStale == true)
              _CacheBanner(
                message: "Showing cached section data because the latest fetch failed.",
                cachedAt: sectionsAsync.valueOrNull?.cachedAt,
              ),
            if (timetableAsync.valueOrNull?.isStale == true)
              _CacheBanner(
                message: "Showing cached timetable data because the latest fetch failed.",
                cachedAt: timetableAsync.valueOrNull?.cachedAt,
              ),
            const SizedBox(height: 8),
            timetableAsync.when(
              data: (timetable) {
                if (timetable == null) {
                  return const _StateCard(
                    title: "Choose a section",
                    message:
                        "Pick a section above to load the timetable and warm the local cache.",
                  );
                }

                if (timetable.meetings.isEmpty) {
                  return _StateCard(
                    title: "No meetings scheduled",
                    message:
                        "The selected section is available, but it does not currently expose any class meetings.",
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        timetable.section.sectionCode,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  );
                }

                return _TimetableView(timetable: timetable);
              },
              loading: () => const _StateCard(
                title: "Loading timetable",
                message: "Fetching the latest meetings for the selected section.",
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(minHeight: 6),
                ),
              ),
              error: (error, stackTrace) => _ErrorStateCard(
                title: "Could not load timetable",
                error: error,
                onRetry: () => ref.invalidate(selectedSectionTimetableProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final selectedSection = ref.watch(selectedSectionSummaryProvider).valueOrNull;

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
              "Section-first mobile foundation",
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              "Sprint 3 wires navigation, API access, and cache-backed timetable loading without leaking transport details into the UI.",
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
                  label: "Flavor",
                  value: config.appFlavor,
                ),
                _HeroBadge(
                  label: "API",
                  value: config.apiBaseUrl,
                ),
                _HeroBadge(
                  label: "Section",
                  value: selectedSection?.sectionCode ?? "Awaiting selection",
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

class _SectionSelectorCard extends ConsumerWidget {
  const _SectionSelectorCard({
    required this.snapshot,
    required this.selectedSectionCode,
  });

  final SectionsSnapshot snapshot;
  final String? selectedSectionCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSection = snapshot.sections.where(
      (section) => section.sectionCode == selectedSectionCode,
    );
    final summary = selectedSection.isEmpty ? null : selectedSection.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Section selection",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Loaded ${snapshot.sections.length} sections from timetable version ${snapshot.timetableVersion.versionId}.",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(snapshot.timetableVersion.publishStatus),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: selectedSectionCode,
              items: snapshot.sections
                  .map(
                    (section) => DropdownMenuItem<String>(
                      value: section.sectionCode,
                      child: Text(section.sectionCode),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                ref
                    .read(selectedSectionCodeControllerProvider.notifier)
                    .selectSection(value);
              },
              decoration: const InputDecoration(
                labelText: "Active section",
                hintText: "Choose a section",
              ),
            ),
            if (summary != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InfoPill(
                    icon: Icons.badge_outlined,
                    label: summary.displayName,
                  ),
                  _InfoPill(
                    icon: Icons.calendar_month_outlined,
                    label: "${summary.meetingCount} meetings",
                  ),
                  _InfoPill(
                    icon: summary.active
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    label: summary.active ? "Active" : "Inactive",
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimetableView extends StatelessWidget {
  const _TimetableView({
    required this.timetable,
  });

  final SectionTimetable timetable;

  @override
  Widget build(BuildContext context) {
    final groupedMeetings = <DayKey, List<TimetableMeeting>>{};
    for (final meeting in timetable.meetings) {
      groupedMeetings.putIfAbsent(meeting.dayKey, () => <TimetableMeeting>[]);
      groupedMeetings[meeting.dayKey]!.add(meeting);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
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
                          "${timetable.timetableVersion.meetingCount} total meetings in version",
                    ),
                    _InfoPill(
                      icon: Icons.warning_amber_outlined,
                      label:
                          "${timetable.timetableVersion.warningCount} import warnings",
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
        ),
        const SizedBox(height: 16),
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
      if (meeting.room != null && meeting.room!.isNotEmpty)
        meeting.room!,
      if (meeting.online) "Online",
      if (meeting.meetingType != null && meeting.meetingType!.isNotEmpty)
        meeting.meetingType!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 86,
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text("Page ${meeting.sourcePage}"),
                      ),
                      Chip(
                        label: Text(meeting.confidenceClass),
                      ),
                      for (final warning in meeting.warnings)
                        Chip(
                          label: Text(warning),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _CacheBanner extends StatelessWidget {
  const _CacheBanner({
    required this.message,
    required this.cachedAt,
  });

  final String message;
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
                cachedAt == null ? message : "$message Cached at $cachedAt.",
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
    final message = error is ApiException
        ? (error as ApiException).message
        : "An unexpected error interrupted the request.";

    return _StateCard(
      title: title,
      message: message,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text("Retry"),
        ),
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
