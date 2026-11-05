import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/phone.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/auth/login_sheet.dart';
import 'package:mobile_project/features/auth/otp_panel.dart';
import 'package:mobile_project/features/favorites/favorites_controller.dart';

import '../helpers/fake_auth.dart';

class PanelHost {
  PanelHost(this.session, this.log);
  final FakeAuthSession session;
  final List<String> log;
  int signedIn = 0;
}

Future<PanelHost> pumpPanel(WidgetTester tester, {bool askName = false, bool isNewUser = true}) async {
  final log = <String>[];
  final host = PanelHost(FakeAuthSession(isNewUser: isNewUser, log: log), log);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(() => host.session),
      favoritesProvider.overrideWith(() => FakeFavorites(log)),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: OtpPanel(askName: askName, onSignedIn: () => host.signedIn++),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return host;
}

Future<void> askCode(WidgetTester tester, {String phone = '07 12 34 56 78'}) async {
  await tester.enterText(find.byKey(const Key('otp-phone')), phone);
  await tester.tap(find.byKey(const Key('otp-send-code')));
  await tester.pumpAndSettle();
}

void main() {
  group('normalizePhone', () {
    test('Ivorian numbers become E.164', () {
      expect(normalizePhone('07 12 34 56 78'), '+2250712345678');
      expect(normalizePhone('+225 07 12 34 56 78'), '+2250712345678');
      expect(normalizePhone('00225 07.12.34.56.78'), '+2250712345678');
      expect(normalizePhone('+33 6 12 34 56 78'), '+33612345678');
    });

    test('rejects incomplete numbers', () {
      expect(normalizePhone('+225 07 12'), isNull);
      expect(normalizePhone(''), isNull);
      expect(normalizePhone('abc'), isNull);
    });
  });

  testWidgets('phone is prefilled with +225 and sent in E.164', (tester) async {
    final h = await pumpPanel(tester);
    final field = tester.widget<TextField>(find.byKey(const Key('otp-phone')));
    expect(field.controller!.text, startsWith('+225'));

    await askCode(tester);
    expect(h.session.otpRequests, ['+2250712345678']);
    expect(find.byKey(const Key('otp-code')), findsOneWidget);
  });

  testWidgets('invalid phone is reported under the field, no request', (tester) async {
    final h = await pumpPanel(tester);
    await askCode(tester, phone: '07 12');
    expect(h.session.otpRequests, isEmpty);
    expect(find.text('Numéro de téléphone invalide.'), findsOneWidget);
  });

  testWidgets('name appears only for a new user when askName is false', (tester) async {
    await pumpPanel(tester);
    expect(find.byKey(const Key('otp-name')), findsNothing);
    await askCode(tester);
    expect(find.byKey(const Key('otp-name')), findsOneWidget);
  });

  testWidgets('existing user: 6 digits verify without name, then signed in', (tester) async {
    final h = await pumpPanel(tester, isNewUser: false);
    await askCode(tester);
    expect(find.byKey(const Key('otp-name')), findsNothing);
    await tester.enterText(find.byKey(const Key('otp-code')), '123456');
    await tester.pumpAndSettle();
    expect(h.session.verifications.single, ('+2250712345678', '123456', null));
    expect(h.log, ['requestOtp', 'verify', 'favorites']);
    expect(h.signedIn, 1);
  });

  testWidgets('OTP_INVALID: message shown, code cleared, phone and name kept', (tester) async {
    final h = await pumpPanel(tester, askName: true);
    await tester.enterText(find.byKey(const Key('otp-name')), 'Awa Traoré');
    await askCode(tester);
    h.session.verifyErrors.add(otpInvalid);
    await tester.enterText(find.byKey(const Key('otp-code')), '000000');
    await tester.pumpAndSettle();

    expect(find.text('Code incorrect ou expiré.'), findsOneWidget);
    expect(h.signedIn, 0);
    expect(tester.widget<TextField>(find.byKey(const Key('otp-code'))).controller!.text, isEmpty);
    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(find.byKey(const Key('otp-code')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('otp-code')), '123456');
    await tester.pumpAndSettle();
    expect(h.signedIn, 1);
    expect(h.session.verifications.last.$3, 'Awa Traoré');
  });

  testWidgets('OTP_TOO_MANY_ATTEMPTS: message shown, still in the panel', (tester) async {
    final h = await pumpPanel(tester);
    await askCode(tester);
    h.session.verifyErrors.add(otpTooMany);
    await tester.enterText(find.byKey(const Key('otp-code')), '000000');
    await tester.pumpAndSettle();
    expect(find.text('Trop d’essais. Demandez un nouveau code.'), findsOneWidget);
    expect(h.signedIn, 0);
  });

  testWidgets('VALIDATION_ERROR on name: shown under the name, code kept', (tester) async {
    final h = await pumpPanel(tester, askName: true);
    await askCode(tester);
    h.session.verifyErrors.add(nameMissing);
    await tester.enterText(find.byKey(const Key('otp-code')), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Indiquez votre nom (2 caractères minimum).'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('otp-code'))).controller!.text, '123456');

    await tester.enterText(find.byKey(const Key('otp-name')), 'Awa Traoré');
    await tester.tap(find.byKey(const Key('otp-submit')));
    await tester.pumpAndSettle();
    expect(h.signedIn, 1);
    expect(h.session.verifications.last, ('+2250712345678', '123456', 'Awa Traoré'));
  });

  testWidgets('resend is enabled after 60 s; OTP_RESEND_TOO_SOON shows a soft message', (tester) async {
    final h = await pumpPanel(tester);
    await askCode(tester);
    TextButton resend() => tester.widget<TextButton>(find.byKey(const Key('otp-resend')));
    expect(resend().onPressed, isNull);

    await tester.pump(const Duration(seconds: 30));
    expect(resend().onPressed, isNull);
    await tester.pump(const Duration(seconds: 30));
    expect(resend().onPressed, isNotNull);

    h.session.requestErrors.add(otpTooSoon);
    await tester.tap(find.byKey(const Key('otp-resend')));
    await tester.pumpAndSettle();
    expect(h.session.otpRequests, hasLength(2));
    expect(find.text('Patientez une minute avant de demander un nouveau code.'), findsOneWidget);
    expect(find.byKey(const Key('otp-code')), findsOneWidget);

    await tester.tap(find.byKey(const Key('otp-resend')));
    await tester.pumpAndSettle();
    expect(h.session.otpRequests, hasLength(3));
    expect(resend().onPressed, isNull);
  });

  testWidgets('offline while asking the code: soft error, no exception', (tester) async {
    final h = await pumpPanel(tester);
    h.session.requestErrors.add(const ApiError.network());
    await askCode(tester);
    expect(find.text(networkMessage), findsOneWidget);
    expect(find.byKey(const Key('otp-code')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorites sync failure does not block sign-in', (tester) async {
    final log = <String>[];
    final session = FakeAuthSession(isNewUser: false, log: log);
    var signedIn = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        favoritesProvider.overrideWith(() => FakeFavorites(log, fail: true)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: SingleChildScrollView(child: OtpPanel(onSignedIn: () => signedIn++))),
      ),
    ));
    await askCode(tester);
    await tester.enterText(find.byKey(const Key('otp-code')), '123456');
    await tester.pumpAndSettle();
    expect(signedIn, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showLoginSheet resolves true once signed in', (tester) async {
    final session = FakeAuthSession(isNewUser: false);
    bool? result;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        favoritesProvider.overrideWith(() => FakeFavorites([])),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showLoginSheet(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otp-phone')), findsOneWidget);
    await askCode(tester);
    await tester.enterText(find.byKey(const Key('otp-code')), '123456');
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byKey(const Key('otp-phone')), findsNothing);
  });
}
