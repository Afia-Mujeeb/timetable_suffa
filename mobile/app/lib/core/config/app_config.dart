class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.appFlavor,
  });

  final String apiBaseUrl;
  final String appFlavor;

  static AppConfig fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        "API_BASE_URL",
        defaultValue: "http://127.0.0.1:8787",
      ),
      appFlavor: String.fromEnvironment(
        "APP_FLAVOR",
        defaultValue: "local",
      ),
    );
  }
}
