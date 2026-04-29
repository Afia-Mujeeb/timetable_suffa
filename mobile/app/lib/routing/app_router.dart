import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/features/home/home_screen.dart";
import "package:timetable_app/features/sections/section_picker_screen.dart";
import "package:timetable_app/features/settings/settings_screen.dart";
import "package:timetable_app/features/week/week_timetable_screen.dart";

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/",
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const _LaunchScreen(),
      ),
      GoRoute(
        path: "/select-section",
        builder: (context, state) => SectionPickerScreen(
          onConfirmed: (_) => context.go("/home"),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return _AppScaffold(
            location: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: "/home",
            builder: (context, state) => const _SelectionRequired(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: "/week",
            builder: (context, state) => const _SelectionRequired(
              child: WeekTimetableScreen(),
            ),
          ),
          GoRoute(
            path: "/settings",
            builder: (context, state) => const _SelectionRequired(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

class _LaunchScreen extends ConsumerWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSectionCodeAsync = ref.watch(
      selectedSectionCodeControllerProvider,
    );

    return selectedSectionCodeAsync.when(
      data: (sectionCode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }

          context.go(sectionCode == null ? "/select-section" : "/home");
        });

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Could not restore the saved section. Open settings to clear local data if this persists.",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionRequired extends ConsumerWidget {
  const _SelectionRequired({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSectionCodeAsync = ref.watch(
      selectedSectionCodeControllerProvider,
    );

    return selectedSectionCodeAsync.when(
      data: (sectionCode) {
        if (sectionCode == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go("/select-section");
            }
          });

          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return child;
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Could not restore the saved section.",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppScaffold extends StatelessWidget {
  const _AppScaffold({
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentIndex = switch (location) {
      "/week" => 1,
      "/settings" => 2,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: "Today",
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: "Week",
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: "Settings",
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go("/home");
            return;
          }

          if (index == 1) {
            context.go("/week");
            return;
          }

          context.go("/settings");
        },
      ),
    );
  }
}
