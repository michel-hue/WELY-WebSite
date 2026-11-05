import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

const _apiUrlOverride = String.fromEnvironment('API_URL');

/// Base URL de l'API (`--dart-define=API_URL=...`). Par défaut : émulateur
/// Android -> 10.0.2.2, ailleurs -> localhost.
String get apiBaseUrl {
  if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000/v1';
  return 'http://localhost:3000/v1';
}
