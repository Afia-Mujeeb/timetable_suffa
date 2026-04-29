import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:timetable_app/core/bootstrap/app_bootstrap.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/core/monitoring/app_error_event.dart";
import "package:timetable_app/data/models/reminder_models.dart";

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final selectedSectionCode = ref.watch(
      selectedSectionCodeControllerProvider,
    );
    final lastSeenVersionId = ref.watch(lastSeenVersionIdProvider);
    final reminderPreferences = ref.watch(
      reminderPreferencesControllerProvider,
    );
    final reminderPermissionStatus = ref.watch(
      reminderPermissionStatusProvider,
    );
    final bootstrapStatus = ref.watch(appBootstrapStatusProvider);
    final recentAppErrors = ref.watch(recentAppErrorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Runtime configuration",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _SettingRow(
                    label: "Flavor",
                    value: config.appFlavor,
                  ),
                  _SettingRow(
                    label: "API base URL",
                    value: config.apiBaseUrl,
                  ),
                  _SettingRow(
                    label: "Selected section",
                    value:
                        selectedSectionCode.valueOrNull ?? "None selected yet",
                  ),
                  _SettingRow(
                    label: "Last seen version",
                    value: lastSeenVersionId.valueOrNull ?? "Not cached yet",
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Stability diagnostics",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Beta builds keep a lightweight local error log so startup, storage, and reminder issues can be inspected without blocking timetable use.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _SettingRow(
                    label: "Startup mode",
                    value: bootstrapStatus.isDegraded
                        ? "Degraded startup"
                        : "Normal startup",
                  ),
                  _SettingRow(
                    label: "Error capture",
                    value: ref.watch(appErrorMonitorProvider).isPersistent
                        ? "Persistent local log"
                        : "Session-only log",
                  ),
                  if (bootstrapStatus.message case final message?)
                    _SettingRow(
                      label: "Startup note",
                      value: message,
                    ),
                  recentAppErrors.when(
                    data: (events) => _DiagnosticsSummary(
                      events: events,
                      bootstrapStatus: bootstrapStatus,
                    ),
                    loading: () => const LinearProgressIndicator(minHeight: 4),
                    error: (error, stackTrace) => Text(
                      "Recent diagnostic events could not be loaded.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: reminderPreferences.when(
                data: (preferences) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Class reminders",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Keep one weekly reminder per meeting for the selected section, with rescheduling handled after section and timetable changes.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Enable reminders"),
                      subtitle: Text(
                        _permissionSummary(
                          permissionStatus:
                              reminderPermissionStatus.valueOrNull,
                          enabled: preferences.enabled,
                        ),
                      ),
                      trailing: Switch.adaptive(
                        value: preferences.enabled,
                        onChanged: (value) async {
                          final status = await ref
                              .read(
                                reminderPreferencesControllerProvider.notifier,
                              )
                              .setRemindersEnabled(value);

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _toggleMessage(
                                  enabled: value,
                                  permissionStatus: status,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ReminderLeadTime>(
                      initialValue: preferences.leadTime,
                      decoration: const InputDecoration(
                        labelText: "Lead time",
                        border: OutlineInputBorder(),
                      ),
                      items: ReminderLeadTime.values
                          .map(
                            (leadTime) => DropdownMenuItem<ReminderLeadTime>(
                              value: leadTime,
                              child: Text(leadTime.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        ref
                            .read(
                              reminderPreferencesControllerProvider.notifier,
                            )
                            .setLeadTime(value);
                      },
                    ),
                    if (_shouldPromptForPermission(
                      permissionStatus: reminderPermissionStatus.valueOrNull,
                      enabled: preferences.enabled,
                    )) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final status = await ref
                              .read(
                                reminderPreferencesControllerProvider.notifier,
                              )
                              .requestPermissions();

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _permissionRequestMessage(status),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text("Allow notifications"),
                      ),
                    ],
                    if (reminderPermissionStatus.isLoading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 4),
                    ],
                  ],
                ),
                loading: () => const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Class reminders"),
                    SizedBox(height: 16),
                    LinearProgressIndicator(minHeight: 6),
                  ],
                ),
                error: (error, stackTrace) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Class reminders",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Reminder preferences could not be loaded from local storage.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Local cache",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Selections and fetched payloads are cached so later offline and notification work can build on a stable storage boundary.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go("/select-section"),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text("Change section"),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      await ref.read(appStorageProvider).clear();
                      await ref
                          .read(reminderSyncCoordinatorProvider)
                          .clearScheduledReminders();
                      ref.invalidate(selectedSectionCodeControllerProvider);
                      ref.invalidate(lastSeenVersionIdProvider);
                      ref.invalidate(reminderPreferencesControllerProvider);
                      ref.invalidate(sectionsProvider);
                      ref.invalidate(selectedSectionTimetableProvider);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Local cache cleared."),
                          ),
                        );
                        context.go("/select-section");
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text("Clear local cache"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSummary extends StatelessWidget {
  const _DiagnosticsSummary({
    required this.events,
    required this.bootstrapStatus,
  });

  final List<AppErrorEvent> events;
  final AppBootstrapStatus bootstrapStatus;

  @override
  Widget build(BuildContext context) {
    final latestEvent = events.isEmpty ? null : events.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingRow(
          label: "Recent issues",
          value: events.isEmpty
              ? "No recent issues captured"
              : events.length.toString(),
        ),
        if (latestEvent != null)
          _SettingRow(
            label: "Latest issue",
            value:
                "${latestEvent.source} at ${_formatDiagnosticsTimestamp(latestEvent.timestamp)}",
          ),
        if (latestEvent != null)
          Text(
            latestEvent.message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}

String _permissionSummary({
  required ReminderPermissionStatus? permissionStatus,
  required bool enabled,
}) {
  if (!enabled) {
    return "Off until you explicitly enable class reminders.";
  }

  return switch (permissionStatus) {
    ReminderPermissionStatus.granted =>
      "Notifications are allowed and reminders will stay in sync.",
    ReminderPermissionStatus.denied =>
      "Notifications are blocked. Allow them so scheduled reminders can fire.",
    ReminderPermissionStatus.unsupported =>
      "This build does not support local reminder notifications.",
    _ => "Checking notification permission status.",
  };
}

String _permissionRequestMessage(ReminderPermissionStatus permissionStatus) {
  return switch (permissionStatus) {
    ReminderPermissionStatus.granted =>
      "Notification permission granted. Reminders were resynced.",
    ReminderPermissionStatus.denied =>
      "Notifications are still blocked. You can try the prompt again from settings.",
    ReminderPermissionStatus.unsupported =>
      "This build does not support local reminder notifications.",
    ReminderPermissionStatus.unknown =>
      "Notification permission status is still unknown.",
  };
}

bool _shouldPromptForPermission({
  required ReminderPermissionStatus? permissionStatus,
  required bool enabled,
}) {
  return enabled &&
      (permissionStatus == ReminderPermissionStatus.denied ||
          permissionStatus == ReminderPermissionStatus.unknown);
}

String _toggleMessage({
  required bool enabled,
  required ReminderPermissionStatus permissionStatus,
}) {
  if (!enabled) {
    return "Class reminders turned off.";
  }

  return switch (permissionStatus) {
    ReminderPermissionStatus.granted => "Class reminders enabled and synced.",
    ReminderPermissionStatus.denied =>
      "Reminders were enabled, but notifications are still blocked.",
    ReminderPermissionStatus.unsupported =>
      "Reminders were saved, but this build does not support local notifications.",
    ReminderPermissionStatus.unknown =>
      "Reminders were enabled. Notification permission is still being resolved.",
  };
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

String _formatDiagnosticsTimestamp(String iso8601) {
  final timestamp = DateTime.tryParse(iso8601);
  if (timestamp == null) {
    return iso8601;
  }

  final local = timestamp.toLocal();
  final minute = local.minute.toString().padLeft(2, "0");
  final hour = local.hour.toString().padLeft(2, "0");
  final month = local.month.toString().padLeft(2, "0");
  final day = local.day.toString().padLeft(2, "0");

  return "$day/$month $hour:$minute";
}
