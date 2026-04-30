/// Where the Flutter app sends recipe-extraction requests.
///
/// The default is the production host. Override at build/run time when
/// pointing at a local dev server:
///
///   flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.42:8000
///   flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000  # Android emulator
class BackendConfig {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://receipt.prompt-in.com',
  );
}
