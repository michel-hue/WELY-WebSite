import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/contact.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/listings/models.dart' hide Page;
import 'package:mobile_project/features/requests/models.dart';
import 'package:mobile_project/features/requests/requests_repository.dart';
import 'package:mobile_project/features/requests/requests_screen.dart';
import 'package:mobile_project/features/seller/seller_listings_repository.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_launcher.dart';
import '../helpers/fake_requests.dart';

Me seller() => Me(id: 'u9', name: 'Koffi', phone: '+2250700000001', isSeller: true, createdAt: DateTime(2026));

class Harness {
  Harness(this.repo, this.sellerRepo, this.launcher, this.session);
  final FakeRequestsRepository repo;
  final FakeSellerListingsRepository sellerRepo;
  final FakeUrlLauncher launcher;
  final FakeAuthSession session;
}

Future<Harness> pumpRequests(
  WidgetTester tester, {
  Me? user,
  FakeRequestsRepository? repo,
  FakeUrlLauncher? launcher,
  FakeAuthSession? session,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final h = Harness(
    repo ?? FakeRequestsRepository(),
    FakeSellerListingsRepository(),
    launcher ?? FakeUrlLauncher(),
    session ?? FakeAuthSession(initial: user),
  );
  final router = GoRouter(initialLocation: '/requests', routes: [
    GoRoute(path: '/requests', builder: (_, _) => const RequestsScreen(key: Key('tab-requests'))),
    GoRoute(path: '/listing/:id', builder: (_, s) => Scaffold(body: Text('Fiche ${s.pathParameters['id']}'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      requestsRepositoryProvider.overrideWithValue(h.repo),
      sellerListingsRepositoryProvider.overrideWithValue(h.sellerRepo),
      urlLauncherProvider.overrideWithValue(h.launcher),
      sessionControllerProvider.overrideWith(() => h.session),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('anonymous: soft invitation with « Se connecter » opening the login sheet', (tester) async {
    final h = await pumpRequests(tester);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(h.repo.mineCalls, 0);

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-sheet')), findsOneWidget);
  });

  testWidgets('account unreachable at startup: « Réessayer » (no « Se connecter »), then the list', (tester) async {
    final session = OfflineSession();
    final h = await pumpRequests(tester, session: session, repo: FakeRequestsRepository(sent: [sampleRequest()]));
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Se connecter'), findsNothing);
    expect(h.repo.mineCalls, 0);

    session.offline = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Villa avec piscine'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('buyer: « En attente » pill, « Annuler » calls cancel', (tester) async {
    final h = await pumpRequests(
      tester,
      user: signedInUser(),
      repo: FakeRequestsRepository(sent: [sampleRequest()]),
    );
    expect(find.text('Villa avec piscine'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Reçues'), findsNothing, reason: 'no segments for a buyer');

    await tester.tap(find.byKey(const Key('request-cancel-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, annuler'));
    await tester.pumpAndSettle();

    expect(h.repo.calls, ['cancel:r1']);
    expect(find.text('Annulée'), findsOneWidget);
    expect(find.byKey(const Key('request-cancel-r1')), findsNothing);
  });

  testWidgets('buyer: refused request shows the refusal reason label', (tester) async {
    await pumpRequests(
      tester,
      user: signedInUser(),
      repo: FakeRequestsRepository(sent: [
        sampleRequest(
          status: RequestStatus.refused,
          refusalReason: RefusalReason.datesUnavailable,
          sellerMessage: 'Désolé, déjà réservé',
          offerType: OfferType.nightly,
        ),
      ]),
    );
    expect(find.text('Refusée'), findsOneWidget);
    expect(find.textContaining('Dates indisponibles'), findsOneWidget);
    expect(find.textContaining('Désolé, déjà réservé'), findsOneWidget);
    expect(find.byKey(const Key('request-cancel-r1')), findsNothing);
  });

  testWidgets('buyer: WhatsApp to the seller falls back to tel: when WhatsApp is missing', (tester) async {
    final launcher = FakeUrlLauncher(failing: {'https'});
    await pumpRequests(
      tester,
      user: signedInUser(),
      repo: FakeRequestsRepository(sent: [sampleRequest()]),
      launcher: launcher,
    );
    await tester.tap(find.byKey(const Key('request-whatsapp-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appeler'));
    await tester.pumpAndSettle();
    expect(launcher.launched.single.toString(), 'tel:+2250700000001');
  });

  testWidgets('offline: soft error with « Réessayer » that reloads', (tester) async {
    final repo = FakeRequestsRepository(sent: [sampleRequest()], error: const ApiError.network());
    await pumpRequests(tester, user: signedInUser(), repo: repo);
    expect(find.text(networkMessage), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    repo.error = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('En attente'), findsOneWidget);
  });

  testWidgets('seller: « Accepter » on a monthly request calls accept then offers « Marquer comme loué »',
      (tester) async {
    final h = await pumpRequests(
      tester,
      user: seller(),
      repo: FakeRequestsRepository(receivedList: [sampleRequest(id: 'r7', received: true)]),
    );
    expect(find.text('Reçues'), findsOneWidget);
    expect(find.text('Envoyées'), findsOneWidget);
    expect(find.text('Awa Koné'), findsOneWidget);
    expect(find.textContaining('+225 07 07 07 07 07'), findsOneWidget);

    await tester.tap(find.byKey(const Key('request-accept-r7')));
    await tester.pumpAndSettle();

    expect(h.repo.calls, ['accept:r7']);
    expect(find.text('Marquer comme loué ?'), findsOneWidget);
    await tester.tap(find.text('Marquer comme loué'));
    await tester.pumpAndSettle();
    expect(h.sellerRepo.closed, [('l1', ClosedReason.rented)]);
    expect(find.text('Acceptée'), findsOneWidget);
  });

  testWidgets('seller: accepting a nightly request does not offer to close the listing', (tester) async {
    final h = await pumpRequests(
      tester,
      user: seller(),
      repo: FakeRequestsRepository(
        receivedList: [sampleRequest(id: 'r8', received: true, offerType: OfferType.nightly)],
      ),
    );
    await tester.tap(find.byKey(const Key('request-accept-r8')));
    await tester.pumpAndSettle();
    expect(h.repo.calls, ['accept:r8']);
    expect(find.textContaining('Marquer comme'), findsNothing);
  });

  testWidgets('seller: « Refuser » sends the optional message', (tester) async {
    final h = await pumpRequests(
      tester,
      user: seller(),
      repo: FakeRequestsRepository(receivedList: [sampleRequest(id: 'r7', received: true)]),
    );
    await tester.tap(find.byKey(const Key('request-refuse-r7')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('refuse-message')), 'Déjà loué');
    await tester.tap(find.byKey(const Key('refuse-confirm')));
    await tester.pumpAndSettle();
    expect(h.repo.calls, ['refuse:r7:Déjà loué']);
    expect(find.text('Refusée'), findsOneWidget);
  });

  testWidgets('seller: « Envoyées » shows the buyer-side list', (tester) async {
    final h = await pumpRequests(
      tester,
      user: seller(),
      repo: FakeRequestsRepository(
        sent: [sampleRequest(id: 's1', title: 'Studio Cocody')],
        receivedList: [sampleRequest(id: 'r7', received: true)],
      ),
    );
    await tester.tap(find.text('Envoyées'));
    await tester.pumpAndSettle();
    expect(find.text('Studio Cocody'), findsOneWidget);
    expect(h.repo.mineCalls, greaterThan(0));
  });

  testWidgets('offline action: message in a SnackBar, the request stays pending', (tester) async {
    final repo = FakeRequestsRepository(sent: [sampleRequest()])..actionError = const ApiError.network();
    await pumpRequests(tester, user: signedInUser(), repo: repo);
    await tester.tap(find.byKey(const Key('request-cancel-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, annuler'));
    await tester.pumpAndSettle();
    expect(find.text(networkMessage), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
  });

  testWidgets('reloads when the tab becomes visible again (new request from the sheet)', (tester) async {
    final repo = FakeRequestsRepository();
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        requestsRepositoryProvider.overrideWithValue(repo),
        sessionControllerProvider.overrideWith(() => FakeAuthSession(initial: signedInUser())),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, on, _) => TickerMode(enabled: on, child: const RequestsScreen()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Aucune demande pour l’instant'), findsOneWidget);

    visible.value = false;
    await tester.pumpAndSettle();
    repo.sent = [sampleRequest()];
    visible.value = true;
    await tester.pumpAndSettle();
    expect(find.text('En attente'), findsOneWidget);
  });

  testWidgets('session expiry turns the tab into the anonymous invitation', (tester) async {
    final h = await pumpRequests(
      tester,
      user: signedInUser(),
      repo: FakeRequestsRepository(sent: [sampleRequest()]),
    );
    expect(find.text('En attente'), findsOneWidget);
    h.session.state = const AsyncData(null);
    await tester.pumpAndSettle();
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('En attente'), findsNothing);
  });
}
