import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/core/contact.dart';

import '../helpers/fake_launcher.dart';

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
