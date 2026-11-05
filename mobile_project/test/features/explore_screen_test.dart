import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/explore/explore_screen.dart';
import 'package:mobile_project/features/explore/location_service.dart';
import 'package:mobile_project/features/listings/models.dart' hide Page;

import '../helpers/fake_explore.dart';

ListingCard card(String id, String title, {LatLng at = const LatLng(5.32, -4.02)}) => ListingCard(
      id: id,
      title: title,
      propertyType: 'apartment',
      city: 'Abidjan',
      district: 'Plateau',
      offers: const Offers(monthly: MonthlyOffer(rent: 650000)),
      rooms: 3,
      distanceMeters: 1200,
      approxLocation: at,
    );

Future<void> pumpExplore(WidgetTester tester, FakeListingsRepository repo, {FakeLocationService? location}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: exploreOverrides(repo: repo, location: location ?? FakeLocationService()),
    child: MaterialApp(theme: buildAppTheme(), home: const Scaffold(body: ExploreScreen())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without location, shows listings around Abidjan', (tester) async {
    final repo = FakeListingsRepository(result: [card('1', 'Studio lumineux'), card('2', 'Villa avec piscine')]);
    await pumpExplore(tester, repo);

    expect(repo.calls, isNotEmpty);
    expect(repo.calls.first.near, abidjan);
    expect(find.text('Studio lumineux'), findsOneWidget);
    expect(find.text('Autour de vous'), findsOneWidget);
    expect(find.text('Activer la position'), findsOneWidget);
  });

  testWidgets('typing in search and submitting searches with q', (tester) async {
    final repo = FakeListingsRepository(result: [card('1', 'Studio lumineux')]);
    await pumpExplore(tester, repo);

    await tester.enterText(find.byKey(const Key('search-field')), 'Cocody');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repo.calls.last.filters.q, 'Cocody');
    expect(repo.calls.last.filters.toQuery()['q'], 'Cocody');
  });

  testWidgets('filters sheet « À la nuit » sets offerType=nightly', (tester) async {
    final repo = FakeListingsRepository(result: [card('1', 'Studio lumineux')]);
    await pumpExplore(tester, repo);

    await tester.tap(find.byKey(const Key('filters-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('À la nuit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Afficher les logements'));
    await tester.pumpAndSettle();

    expect(repo.calls.last.filters.offerType, OfferType.nightly);
    expect(repo.calls.last.filters.toQuery()['offerType'], 'nightly');
    expect(find.text('1'), findsWidgets); // compteur de filtres actifs
  });

  testWidgets('empty result shows the soft empty state', (tester) async {
    await pumpExplore(tester, FakeListingsRepository());
    expect(find.text("Aucun logement ici pour l'instant"), findsOneWidget);
  });

  testWidgets('network error shows « Réessayer » and retries', (tester) async {
    final repo = FakeListingsRepository(error: const ApiError.network());
    await pumpExplore(tester, repo);

    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text(networkMessage), findsOneWidget);

    repo
      ..error = null
      ..result = [card('1', 'Studio lumineux')];
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Studio lumineux'), findsOneWidget);
  });

  testWidgets('with a location, searches around the user and hides the link', (tester) async {
    const here = LatLng(5.36, -3.98);
    final repo = FakeListingsRepository(result: [card('1', 'Studio lumineux')]);
    await pumpExplore(tester, repo, location: FakeLocationService(position: here));

    expect(repo.calls.single.near, here);
    expect(find.text('Activer la position'), findsNothing);
  });

  testWidgets('first launch: explainer over listings around Abidjan, « Plus tard » dismisses it', (tester) async {
    final location = FakeLocationService(explained: false);
    final repo = FakeListingsRepository(result: [card('1', 'Studio lumineux')]);
    await pumpExplore(tester, repo, location: location);

    expect(find.text('Plus tard'), findsOneWidget);
    expect(repo.calls.single.near, abidjan);

    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(find.text('Plus tard'), findsNothing);
    expect(location.explained, isTrue);
    expect(location.asks, 0);
    expect(find.text('Activer la position'), findsOneWidget);
  });

  testWidgets('tapping a dot puts its listing first', (tester) async {
    final repo = FakeListingsRepository(result: [
      card('1', 'Studio lumineux', at: const LatLng(5.20, -4.0267)),
      card('2', 'Villa avec piscine', at: const LatLng(5.335, -4.0267)),
    ]);
    await pumpExplore(tester, repo);

    await tester.tap(find.byKey(const ValueKey('dot-2')));
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.byKey(const ValueKey('card-2')));
    final other = find.byKey(const ValueKey('card-1'));
    if (other.evaluate().isNotEmpty) {
      expect(first.dy, lessThan(tester.getTopLeft(other).dy));
    }
  });
}
