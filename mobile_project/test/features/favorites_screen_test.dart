import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/favorites/favorite_button.dart';
import 'package:mobile_project/features/favorites/favorites_repository.dart';
import 'package:mobile_project/features/favorites/favorites_screen.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_favorites.dart';

Future<MemoryFavoritesStore> pumpFavorites(WidgetTester tester, List<LocalFavorite> initial) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = MemoryFavoritesStore(initial);
  final router = GoRouter(initialLocation: '/favorites', routes: [
    GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
    GoRoute(path: '/listing/:id', builder: (_, s) => Scaffold(body: Text('Fiche ${s.pathParameters['id']}'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(() => FakeAuthSession()),
      favoritesLocalStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('empty state invites to tap ♡', (tester) async {
    await pumpFavorites(tester, const []);
    expect(find.text('Touchez ♡ sur un logement pour le retrouver ici'), findsOneWidget);
  });

  testWidgets('grid of local favorites; unavailable ones are greyed « plus disponible »', (tester) async {
    await pumpFavorites(tester, [
      LocalFavorite(favoriteCard('l1')),
      LocalFavorite(favoriteCard('l2', title: 'Studio Cocody'), unavailable: true),
      LocalFavorite(favoriteCard('l3', title: 'Duplex Marcory')),
    ]);
    expect(find.text('Villa avec piscine'), findsOneWidget);
    expect(find.text('Studio Cocody'), findsOneWidget);
    expect(find.text('Duplex Marcory'), findsOneWidget);
    expect(find.text('plus disponible'), findsOneWidget);
    // Deux colonnes : les deux premières cartes sont sur la même ligne.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('favorite-card-l1'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('favorite-card-l2'))).dy,
    );

    await tester.tap(find.text('Villa avec piscine'));
    await tester.pumpAndSettle();
    expect(find.text('Fiche l1'), findsOneWidget);
  });

  testWidgets('♡ on a favorite card removes it and persists locally', (tester) async {
    final store = await pumpFavorites(tester, [LocalFavorite(favoriteCard('l1'))]);
    expect(find.byType(FavoriteButton), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('favorite-l1')));
    await tester.pumpAndSettle();
    expect(find.text('Villa avec piscine'), findsNothing);
    expect(store.entries, isEmpty);
  });
}
