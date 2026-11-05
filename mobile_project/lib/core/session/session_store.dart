import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  @override
  Future<String?> readAccess() => _s.read(key: 'access');
  @override
  Future<String?> readRefresh() => _s.read(key: 'refresh');

  @override
  Future<void> save({required String access, required String refresh}) async {
    await _s.write(key: 'access', value: access);
    await _s.write(key: 'refresh', value: refresh);
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: 'access');
    await _s.delete(key: 'refresh');
  }
}

final sessionStoreProvider = Provider<SessionStore>((ref) => SecureSessionStore());
