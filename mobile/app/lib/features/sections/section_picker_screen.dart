import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:http/http.dart" as http;
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/api/api_exception.dart";
import "package:timetable_app/data/models/timetable_models.dart";

class SectionPickerScreen extends ConsumerStatefulWidget {
  const SectionPickerScreen({
    super.key,
    this.onConfirmed,
    this.title = "Choose your section",
    this.subtitle =
        "Search once, confirm once, and keep the timetable available even when the network drops.",
  });

  final ValueChanged<String>? onConfirmed;
  final String title;
  final String subtitle;

  @override
  ConsumerState<SectionPickerScreen> createState() =>
      _SectionPickerScreenState();
}

class _SectionPickerScreenState extends ConsumerState<SectionPickerScreen> {
  String _searchQuery = "";
  String? _draftSectionCode;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionsProvider);
    final persistedSectionCodeAsync = ref.watch(
      selectedSectionCodeControllerProvider,
    );

    final snapshot = sectionsAsync.valueOrNull;
    final effectiveSelection = _resolveSelection(
      sections: snapshot?.sections ?? const [],
      persistedSectionCode: persistedSectionCodeAsync.valueOrNull,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Section picker"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sectionsProvider);
          await ref.read(sectionsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
          children: [
            _HeroCard(
              title: widget.title,
              subtitle: widget.subtitle,
            ),
            const SizedBox(height: 16),
            sectionsAsync.when(
              data: (loadedSnapshot) => _SectionPickerBody(
                snapshot: loadedSnapshot,
                searchQuery: _searchQuery,
                selectedSectionCode: effectiveSelection,
                onSearchChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                onSectionSelected: (sectionCode) {
                  setState(() {
                    _draftSectionCode = sectionCode;
                  });
                },
              ),
              loading: () => const _StateCard(
                title: "Loading sections",
                message:
                    "Pulling the latest section list so the first-run flow stays short.",
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(minHeight: 6),
                ),
              ),
              error: (error, stackTrace) => _ErrorState(
                error: error,
                hasSelection: persistedSectionCodeAsync.valueOrNull != null,
                onRetry: () => ref.invalidate(sectionsProvider),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: _ConfirmBar(
          selectedSectionCode: effectiveSelection,
          isSaving: _isSaving,
          isEnabled: snapshot != null && effectiveSelection != null,
          hasChanged: effectiveSelection != null &&
              effectiveSelection != persistedSectionCodeAsync.valueOrNull,
          onPressed: snapshot == null || effectiveSelection == null || _isSaving
              ? null
              : () => _confirmSelection(effectiveSelection),
        ),
      ),
    );
  }

  String? _resolveSelection({
    required List<SectionSummary> sections,
    required String? persistedSectionCode,
  }) {
    final candidate = _draftSectionCode ?? persistedSectionCode;
    if (candidate == null) {
      return null;
    }

    for (final section in sections) {
      if (section.sectionCode == candidate) {
        return candidate;
      }
    }

    return null;
  }

  Future<void> _confirmSelection(String sectionCode) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(selectedSectionCodeControllerProvider.notifier)
          .selectSection(sectionCode);
      widget.onConfirmed?.call(sectionCode);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF123E39),
              Color(0xFF1B665A),
              Color(0xFF8AC0A8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFF2FAF6),
                  ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _HeroPill(
                  icon: Icons.search_rounded,
                  label: "Searchable list",
                ),
                _HeroPill(
                  icon: Icons.wifi_off_rounded,
                  label: "Offline-aware",
                ),
                _HeroPill(
                  icon: Icons.check_circle_outline_rounded,
                  label: "Explicit confirm",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
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
        color: const Color(0x20FFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
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

class _SectionPickerBody extends StatelessWidget {
  const _SectionPickerBody({
    required this.snapshot,
    required this.searchQuery,
    required this.selectedSectionCode,
    required this.onSearchChanged,
    required this.onSectionSelected,
  });

  final SectionsSnapshot snapshot;
  final String searchQuery;
  final String? selectedSectionCode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();
    final shouldShowSearch = snapshot.sections.length >= 7 || query.isNotEmpty;
    if (snapshot.sections.isEmpty) {
      return const _StateCard(
        title: "No sections available",
        message:
            "The timetable is reachable, but no sections are currently published for selection.",
      );
    }

    final filteredSections = snapshot.sections.where((section) {
      if (query.isEmpty) {
        return true;
      }

      return section.sectionCode.toLowerCase().contains(query) ||
          section.displayName.toLowerCase().contains(query);
    }).toList(growable: false);

    final selectedSection =
        _findSection(filteredSections, selectedSectionCode) ??
            _findSection(snapshot.sections, selectedSectionCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snapshot.isStale)
          _StatusBanner(
            icon: Icons.wifi_off_rounded,
            title: "Offline mode",
            message: snapshot.cachedAt == null
                ? "Using the last downloaded section list because the latest fetch failed."
                : "Using the last downloaded section list from ${snapshot.cachedAt} because the latest fetch failed.",
            backgroundColor: const Color(0xFFFFF6E7),
          ),
        if (snapshot.isStale) const SizedBox(height: 12),
        Card(
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
                            "Pick a section first",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Loaded ${snapshot.sections.length} sections from version ${snapshot.timetableVersion.versionId}.",
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
                if (shouldShowSearch) ...[
                  const SizedBox(height: 18),
                  TextField(
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      labelText: "Search sections",
                      hintText: "Section code or display name",
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => onSearchChanged(""),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: "Clear search",
                            ),
                    ),
                  ),
                ],
                if (selectedSection != null) ...[
                  const SizedBox(height: 18),
                  _SelectionSummary(section: selectedSection),
                ],
                const SizedBox(height: 18),
                if (filteredSections.isEmpty)
                  _EmptySearchState(
                    query: searchQuery,
                    onClear: () => onSearchChanged(""),
                  )
                else
                  _SectionList(
                    sections: filteredSections,
                    selectedSectionCode: selectedSectionCode,
                    onSectionSelected: onSectionSelected,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.section,
  });

  final SectionSummary section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _MetaChip(
            icon: Icons.badge_outlined,
            label: section.sectionCode,
          ),
          _MetaChip(
            icon: Icons.event_note_outlined,
            label: "${section.meetingCount} meetings",
          ),
          _MetaChip(
            icon: section.active
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            label: section.active ? "Active" : "Inactive",
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.sections,
    required this.selectedSectionCode,
    required this.onSectionSelected,
  });

  final List<SectionSummary> sections;
  final String? selectedSectionCode;
  final ValueChanged<String> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: selectedSectionCode,
      onChanged: (value) {
        if (value != null) {
          onSectionSelected(value);
        }
      },
      child: ListView.separated(
        key: const ValueKey("section-list"),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sections.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final section = sections[index];
          final isSelected = section.sectionCode == selectedSectionCode;

          return Material(
            key: ValueKey("section-option-${section.sectionCode}"),
            color: isSelected ? const Color(0xFFEAF4EF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSectionSelected(section.sectionCode),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Radio<String>(
                      value: section.sectionCode,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.sectionCode,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            section.displayName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text("${section.meetingCount} meetings"),
                              ),
                              Chip(
                                label: Text(
                                  section.active ? "Active" : "Inactive",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.query,
    required this.onClear,
  });

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      title: "No matches",
      message:
          "No section matched \"$query\". Clear the search to browse the full list again.",
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded),
          label: const Text("Clear search"),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.hasSelection,
    required this.onRetry,
  });

  final Object error;
  final bool hasSelection;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (_isConnectivityError(error) && !hasSelection) {
      return _StateCard(
        title: "First run needs a connection",
        message:
            "The app cannot download sections yet. Connect once so the list can be cached for later offline use.",
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text("Try again"),
          ),
        ),
      );
    }

    final ApiException? apiError =
        error is ApiException ? error as ApiException : null;
    final message =
        apiError?.message ?? "The section list could not be loaded right now.";

    return _StateCard(
      title: "Could not load sections",
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

SectionSummary? _findSection(
  Iterable<SectionSummary> sections,
  String? sectionCode,
) {
  if (sectionCode == null) {
    return null;
  }

  for (final section in sections) {
    if (section.sectionCode == sectionCode) {
      return section;
    }
  }

  return null;
}

bool _isConnectivityError(Object error) {
  return error is SocketException || error is http.ClientException;
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.backgroundColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.selectedSectionCode,
    required this.isSaving,
    required this.isEnabled,
    required this.hasChanged,
    required this.onPressed,
  });

  final String? selectedSectionCode;
  final bool isSaving;
  final bool isEnabled;
  final bool hasChanged;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isSaving
        ? "Saving..."
        : hasChanged
            ? "Use this section"
            : "Continue";

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedSectionCode != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "Selected: $selectedSectionCode",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        FilledButton.icon(
          onPressed: isEnabled ? onPressed : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
      ],
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
