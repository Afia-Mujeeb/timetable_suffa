import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/core/theme/app_theme.dart";
import "package:timetable_app/routing/app_router.dart";

class TimetableApp extends ConsumerWidget {
  const TimetableApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final bootstrapStatus = ref.watch(appBootstrapStatusProvider);

    return MaterialApp.router(
      title: "Timetable",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        if (!bootstrapStatus.isDegraded || child == null) {
          return child ?? const SizedBox.shrink();
        }

        return Stack(
          children: [
            child,
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Material(
                    color: const Color(0xFFFFF6E7),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              bootstrapStatus.message ??
                                  "The app started in a reduced-resilience mode.",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
