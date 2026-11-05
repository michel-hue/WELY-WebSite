import 'package:mobile_project/core/contact.dart';

/// Lanceur factice : enregistre les URI ouvertes ; [failing] ne s'ouvrent pas.
class FakeUrlLauncher implements UrlLauncher {
  FakeUrlLauncher({this.failing = const {}});
  final Set<String> failing;
  final launched = <Uri>[];

  @override
  Future<bool> canLaunch(Uri uri) async => !failing.contains(uri.scheme);

  @override
  Future<bool> launch(Uri uri, {bool appOnly = false}) async {
    if (failing.contains(uri.scheme)) return false;
    launched.add(uri);
    return true;
  }
}
