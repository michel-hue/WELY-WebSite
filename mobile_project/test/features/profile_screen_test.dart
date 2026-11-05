import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/notifications/notifications_repository.dart';
import 'package:mobile_project/features/profile/profile_screen.dart';
import 'package:mobile_project/features/requests/requests_repository.dart';
import 'package:mobile_project/features/seller/seller_listings_repository.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_notifications.dart';
import '../helpers/fake_profile.dart';
import '../helpers/fake_requests.dart';

class Harness {
  Harness(this.session, this.sellerRepo, this.requestsRepo, this.notificationsRepo);
  final FakeProfileSession session;
  final FakeSellerListingsRepository sellerRepo;
  final FakeRequestsRepository requestsRepo;
  final FakeNotificationsRepository notificationsRepo;
}

Future<Harness> pumpProfile(
  WidgetTester tester, {
  Me? user,
  FakeSellerListingsRepository? sellerRepo,
  FakeRequestsRepository? requestsRepo,
  FakeNotificationsRepository? notificationsRepo,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final h = Harness(
    FakeProfileSession(initial: user),
    sellerRepo ?? FakeSellerListingsRepository(),
    requestsRepo ?? FakeRequestsRepository(),
    notificationsRepo ?? FakeNotificationsRepository(),
  );
  final router = GoRouter(initialLocation: '/profile', routes: [
    GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen(key: Key('tab-profile'))),
    GoRoute(path: '/notifications', builder: (_, _) => const Scaffold(body: Text('Écran notifications'))),
    GoRoute(path: '/seller/listings/new', builder: (_, _) => const Scaffold(body: Text('Éditeur'))),
    GoRoute(path: '/seller/listings/:id', builder: (_, s) => Scaffold(body: Text('Gérer ${s.pathParameters['id']}'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(() => h.session),
      sellerListingsRepositoryProvider.overrideWithValue(h.sellerRepo),
      requestsRepositoryProvider.overrideWithValue(h.requestsRepo),
      notificationsRepositoryProvider.overrideWithValue(h.notificationsRepo),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return h;
}

Me sellerUser() => copyMe(signedInUser(), isSeller: true);

void main() {
  testWidgets('anonymous: welcome, « Se connecter » and « Proposer un logement »', (tester) async {
    final h = await pumpProfile(tester);
    expect(find.text('Bienvenue sur WELLY'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Proposer un logement'), findsOneWidget);
    expect(h.sellerRepo.mineCalls, 0);
    expect(h.notificationsRepo.unreadCalls, 0);

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-sheet')), findsOneWidget);
  });

  testWidgets('buyer: initial avatar, name, phone and unread badge on notifications', (tester) async {
    await pumpProfile(
      tester,
      user: signedInUser(),
      notificationsRepo: FakeNotificationsRepository(unread: 3),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(find.text('+225 07 12 34 56 78'), findsOneWidget);
    expect(find.text('Acheteur'), findsOneWidget);
    expect(find.text('Vendeur'), findsOneWidget);
    expect(find.byKey(const Key('notifications-badge')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('toggling « Vendeur » calls setSellerMode(true) and shows the seller space', (tester) async {
    final h = await pumpProfile(
      tester,
      user: signedInUser(),
      sellerRepo: FakeSellerListingsRepository(listings: [
        sampleSellerListing(id: 'l1', title: 'Villa avec piscine', views: 100, requests: 2, publishedUntil: DateTime(2026, 11, 30)),
        sampleSellerListing(id: 'l2', title: 'Studio lumineux', status: ListingStatus.expired, views: 42),
        sampleSellerListing(
          id: 'l3',
          title: 'Appartement 2 pièces',
          status: ListingStatus.closed,
          closedReason: ClosedReason.rented,
        ),
      ]),
      requestsRepo: FakeRequestsRepository(receivedList: [
        sampleRequest(id: 'r1', received: true),
        sampleRequest(id: 'r2', received: true),
      ]),
    );
    expect(find.text('Mes annonces'), findsNothing);

    await tester.tap(find.text('Vendeur'));
    await tester.pumpAndSettle();

    expect(h.session.log, ['seller:true']);
    expect(find.text('Mes annonces'), findsOneWidget);
    expect(find.text('Villa avec piscine'), findsOneWidget);
    expect(find.text('Studio lumineux'), findsOneWidget);
    expect(find.text('Appartement 2 pièces'), findsOneWidget);
    expect(find.text('En ligne'), findsOneWidget);
    expect(find.text('Expirée'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Réactiver ›'), findsOneWidget);
    // Chiffres clés : 2 demandes en attente, 142 vues au total.
    expect(find.byKey(const Key('stat-pending')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('stat-pending')), matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('stat-views')), matching: find.text('142')), findsOneWidget);

    await tester.tap(find.text('Villa avec piscine'));
    await tester.pumpAndSettle();
    expect(find.text('Gérer l1'), findsOneWidget);
  });

  testWidgets('seller: « Réactiver › » on an expired listing reactivates it', (tester) async {
    final h = await pumpProfile(
      tester,
      user: sellerUser(),
      sellerRepo: FakeSellerListingsRepository(listings: [
        sampleSellerListing(id: 'l2', title: 'Studio lumineux', status: ListingStatus.expired),
      ]),
    );
    await tester.tap(find.text('Réactiver ›'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sans date de fin'));
    await tester.pumpAndSettle();

    expect(h.sellerRepo.calls, ['reactivate:l2:permanent']);
    expect(find.text('En ligne'), findsOneWidget);
    expect(find.text('Réactiver ›'), findsNothing);
  });

  testWidgets('seller: laiton « + » opens the editor', (tester) async {
    await pumpProfile(tester, user: sellerUser());
    await tester.tap(find.byKey(const Key('new-listing')));
    await tester.pumpAndSettle();
    expect(find.text('Éditeur'), findsOneWidget);
  });

  testWidgets('seller: offline shows a soft error with « Réessayer »', (tester) async {
    final repo = FakeSellerListingsRepository(
      listings: [sampleSellerListing()],
      error: const ApiError.network(),
    );
    await pumpProfile(
      tester,
      user: sellerUser(),
      sellerRepo: repo,
      requestsRepo: FakeRequestsRepository(error: const ApiError.network()),
    );
    expect(find.text(networkMessage), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(tester.takeException(), isNull);

    repo.error = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Villa avec piscine'), findsOneWidget);
  });

  testWidgets('delete account requires typing SUPPRIMER before deleteAccount is called', (tester) async {
    final h = await pumpProfile(tester, user: signedInUser());
    await tester.scrollUntilVisible(find.text('Supprimer mon compte'), 200);
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('delete-account-confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('delete-account-field')), 'supprimer');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(confirm);
    await tester.pump();
    expect(h.session.log, isEmpty);

    await tester.enterText(find.byKey(const Key('delete-account-field')), 'SUPPRIMER');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(h.session.log, ['delete']);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('edit profile updates the name', (tester) async {
    final h = await pumpProfile(tester, user: signedInUser());
    await tester.tap(find.text('Modifier mon profil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Awa K.');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(h.session.log.single, startsWith('update:Awa K.'));
    expect(find.text('Awa K.'), findsOneWidget);
  });
}
