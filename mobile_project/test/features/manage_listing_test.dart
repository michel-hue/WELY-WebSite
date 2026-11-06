import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/listings/models.dart' hide Page;
import 'package:mobile_project/features/seller/manage_listing_screen.dart';
import 'package:mobile_project/features/seller/seller_listings_repository.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_seller.dart';

Future<void> pumpManage(WidgetTester tester, FakeEditorRepository repo, {String id = 'l1'}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/home', routes: [
    GoRoute(
      path: '/home',
      builder: (context, _) => Scaffold(
        body: TextButton(onPressed: () => context.push('/seller/listings/$id'), child: const Text('Accueil')),
      ),
    ),
    GoRoute(path: '/seller/listings/:id', builder: (_, s) => ManageListingScreen(id: s.pathParameters['id']!)),
    GoRoute(
      path: '/seller/listings/:id/edit',
      builder: (_, s) => Scaffold(body: Text('Éditeur ${s.pathParameters['id']}')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(() => FakeAuthSession()),
      sellerListingsRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Accueil'));
  await tester.pumpAndSettle();
}

const _offers = Offers(monthly: MonthlyOffer(rent: 650000));

void main() {
  testWidgets('online listing: stats, « Prolonger » calls extend (permanent)', (tester) async {
    final repo = FakeEditorRepository(existing: editorListing(
      status: ListingStatus.online,
      offers: _offers,
      publishedUntil: DateTime(2026, 11, 30),
      stats: const ListingStats(views: 120, contactClicks: 14, requests: 3),
    ));
    await pumpManage(tester, repo);

    expect(find.text('Villa avec piscine'), findsOneWidget);
    expect(find.text('En ligne'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Prolonger'), findsOneWidget);
    expect(find.text('Désactiver'), findsOneWidget);
    expect(find.text('Marquer louée'), findsOneWidget);
    expect(find.text('Réactiver'), findsNothing);

    await tester.tap(find.text('Prolonger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sans date de fin'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('extend:l1:permanent'));
    expect(find.text('Sans date de fin'), findsWidgets);
  });

  testWidgets('expired listing shows « Réactiver » and no « Prolonger »', (tester) async {
    final repo = FakeEditorRepository(existing: editorListing(status: ListingStatus.expired, offers: _offers));
    await pumpManage(tester, repo);

    expect(find.text('Réactiver'), findsOneWidget);
    expect(find.text('Prolonger'), findsNothing);
    expect(find.text('Désactiver'), findsNothing);

    await tester.tap(find.text('Réactiver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sans date de fin'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('reactivate:l1:permanent'));
    expect(find.text('En ligne'), findsOneWidget);
  });

  testWidgets('API error is shown in place (SELLER_MODE_REQUIRED)', (tester) async {
    final repo = FakeEditorRepository(existing: editorListing(status: ListingStatus.deactivated, offers: _offers))
      ..actionError = const ApiError(
        status: 403,
        code: 'SELLER_MODE_REQUIRED',
        message: 'Activez le mode vendeur pour publier.',
      );
    await pumpManage(tester, repo);
    await tester.tap(find.text('Réactiver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sans date de fin'));
    await tester.pumpAndSettle();
    expect(find.text('Activez le mode vendeur pour publier.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Supprimer » asks for confirmation, then removes and goes back', (tester) async {
    final repo = FakeEditorRepository(existing: editorListing(status: ListingStatus.draft));
    await pumpManage(tester, repo);
    expect(find.text('Continuer la saisie'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Supprimer l’annonce'), 200);
    await tester.tap(find.text('Supprimer l’annonce'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('remove')), isEmpty);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('remove:l1'));
    expect(find.text('Accueil'), findsOneWidget);
  });

  testWidgets('offline load: soft error with « Réessayer »', (tester) async {
    final repo = FakeEditorRepository(existing: editorListing())..loadError = const ApiError.network();
    await pumpManage(tester, repo);
    expect(find.text(networkMessage), findsOneWidget);
    expect(tester.takeException(), isNull);

    repo.loadError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Villa avec piscine'), findsOneWidget);
  });
}
