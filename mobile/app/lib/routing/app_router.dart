import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:timetable_app/features/home/home_screen.dart";
import "package:timetable_app/features/settings/settings_screen.dart";

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return _AppScaffold(
            location: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: "/",
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: "/settings",
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class _AppScaffold extends StatelessWidget {
  const _AppScaffold({
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentIndex = location.startsWith("/settings") ? 1 : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.view_agenda_outlined),
            selectedIcon: Icon(Icons.view_agenda),
            label: "Schedule",
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: "Settings",
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go("/");
            return;
          }

          context.go("/settings");
        },
      ),
    );
  }
}
