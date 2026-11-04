/// Centralized API base URL configuration.
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000
class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}