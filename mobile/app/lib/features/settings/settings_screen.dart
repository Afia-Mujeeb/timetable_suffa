import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:timetable_app/core/providers/app_providers.dart";

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final selectedSectionCode = ref.watch(
      selectedSectionCodeControllerProvider,
    );
    final lastSeenVersionId = ref.watch(lastSeenVersionIdProvider);

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
                    onPressed: () async {
                      await ref.read(appStorageProvider).clear();
                      ref.invalidate(selectedSectionCodeControllerProvider);
                      ref.invalidate(lastSeenVersionIdProvider);
                      ref.invalidate(sectionsProvider);
                      ref.invalidate(selectedSectionTimetableProvider);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Local cache cleared."),
                          ),
                        );
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
