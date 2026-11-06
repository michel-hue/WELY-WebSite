import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/explore/location_service.dart';
import 'package:mobile_project/features/explore/map_view.dart';
import 'package:mobile_project/features/listings/listings_repository.dart';
import 'package:mobile_project/features/seller/editor/editor_screen.dart';
import 'package:mobile_project/features/seller/seller_listings_repository.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_explore.dart';
import '../helpers/fake_seller.dart';

Future<void> pumpEditor(WidgetTester tester, FakeEditorRepository repo, {String? id}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: id == null ? '/seller/listings/new' : '/seller/listings/$id/edit',
    routes: [
      GoRoute(path: '/seller/listings/new', builder: (_, _) => const ListingEditorScreen()),
      GoRoute(path: '/seller/listings/:id', builder: (_, s) => Text('Gérer ${s.pathParameters['id']}')),
      GoRoute(path: '/seller/listings/:id/edit', builder: (_, s) => ListingEditorScreen(id: s.pathParameters['id'])),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(() => FakeAuthSession()),
      sellerListingsRepositoryProvider.overrideWithValue(repo),
      listingsRepositoryProvider.overrideWithValue(FakeListingsRepository()),
      locationServiceProvider.overrideWithValue(FakeLocationService()),
      tileProviderOverrideProvider.overrideWithValue(BlankTileProvider()),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('new listing: progress, validation in place, then step 2 with the map', (tester) async {
    final repo = FakeEditorRepository();
    await pumpEditor(tester, repo);
    expect(find.text('Étape 1 sur 5 · Le bien'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editor-next')));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez le type de bien.'), findsOneWidget);
    expect(find.text('Étape 1 sur 5 · Le bien'), findsOneWidget);

    await tester.tap(find.byKey(const Key('type-villa')));
    await tester.enterText(find.descendant(of: find.byKey(const Key('field-title')), matching: find.byType(TextField)),
        'Villa avec piscine');
    await tester.tap(find.byKey(const Key('editor-next')));
    await tester.pumpAndSettle();

    expect(find.text('Étape 2 sur 5 · Où'), findsOneWidget);
    expect(find.text('Ma position'), findsOneWidget);
    expect(repo.created, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing: offline load shows « Réessayer », then the prefilled form', (tester) async {
    final repo = FakeEditorRepository(existing: editorListing())..loadError = const ApiError.network();
    await pumpEditor(tester, repo, id: 'l1');
    expect(find.text(networkMessage), findsOneWidget);

    repo.loadError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Villa avec piscine'), findsOneWidget);
    expect(find.text('Étape 1 sur 5 · Le bien'), findsOneWidget);
  });
}
