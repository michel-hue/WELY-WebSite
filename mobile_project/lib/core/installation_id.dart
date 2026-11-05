import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _key = 'installation_id';

/// UUID v4 généré une seule fois puis conservé.
Future<String> loadInstallationId(SharedPreferences prefs) async {
  final existing = prefs.getString(_key);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = const Uuid().v4();
  await prefs.setString(_key, id);
  return id;
}

final installationIdProvider = FutureProvider<String>((ref) async {
  return loadInstallationId(await SharedPreferences.getInstance());
});
