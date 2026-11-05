import 'package:flutter_test/flutter_test.dart';
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

void main() {
  const message = 'Bonjour, je suis intéressé par « Villa » vu sur WELLY';

  test('whatsappUri keeps only the digits and encodes the message', () {
    final uri = whatsappUri('+2250700000001', 'Villa');
    expect(uri.toString(), 'https://wa.me/2250700000001?text=${Uri.encodeComponent(message)}');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/2250700000001');
    expect(uri.queryParameters['text'], message);
    expect(uri.toString(), isNot(contains('+')));
  });

  test('telUri keeps the leading +', () {
    expect(telUri('+225 07 00 00 00 01').toString(), 'tel:+2250700000001');
  });

  test('openWhatsAppOrCall opens wa.me when WhatsApp is available', () async {
    final launcher = FakeUrlLauncher();
    final used = await openWhatsAppOrCall(launcher, '+2250700000001', 'Villa');
    expect(used, ContactChannel.whatsapp);
    expect(launcher.launched.single, whatsappUri('+2250700000001', 'Villa'));
  });

  test('openWhatsAppOrCall falls back to tel: when wa.me cannot open', () async {
    final launcher = FakeUrlLauncher(failing: {'https'});
    final used = await openWhatsAppOrCall(launcher, '+2250700000001', 'Villa', callPhone: '+2250700000002');
    expect(used, ContactChannel.call);
    expect(launcher.launched.single.toString(), 'tel:+2250700000002');
  });

  test('openWhatsAppOrCall asks before calling and respects a refusal', () async {
    final launcher = FakeUrlLauncher(failing: {'https'});
    final used = await openWhatsAppOrCall(launcher, '+2250700000001', 'Villa', confirmCall: () async => false);
    expect(used, isNull);
    expect(launcher.launched, isEmpty);
  });

  test('openWhatsAppOrCall returns null when nothing can open', () async {
    final launcher = FakeUrlLauncher(failing: {'https', 'tel'});
    expect(await openWhatsAppOrCall(launcher, '+2250700000001', 'Villa'), isNull);
  });
}
