import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/contact.dart';
import 'package:mobile_project/core/format.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/explore/explore_controller.dart';
import 'package:mobile_project/features/explore/map_view.dart';
import 'package:mobile_project/features/listing/listing_screen.dart';
import 'package:mobile_project/features/listings/listings_repository.dart';
import 'package:mobile_project/features/listings/models.dart' hide Page;
import 'package:mobile_project/features/seller/manage_listing_screen.dart';

import '../helpers/fake_explore.dart';
import '../helpers/fake_launcher.dart';

ListingDetail sampleDetail({String sellerId = 's1', String? phone = '+2250700000001', String? whatsapp}) => ListingDetail(
      id: '1',
      title: 'Villa avec piscine',
      propertyType: 'villa',
      city: 'Abidjan',
      district: 'Riviera 3',
      offers: const Offers(
        monthly: MonthlyOffer(rent: 650000),
        nightly: NightlyOffer(price: 45000, minNights: 2),
      ),
      rooms: 4,
      bedrooms: 3,
      bathrooms: 2,
      surfaceM2: 180,
      amenities: const ['pool', 'parking'],
      description: 'Belle villa calme avec jardin.',
      location: const LatLng(5.36, -3.98),
      seller: PublicSeller(
        id: sellerId,
        name: 'Koffi Adjoumani',
        memberSince: DateTime(2024, 3, 10),
        onlineListingsCount: 3,
        phone: phone,
        whatsappPhone: whatsapp,
      ),
    );

class FakeDetailRepository extends Fake implements ListingsRepository {
  FakeDetailRepository({ListingDetail? value, this.error}) : value = value ?? sampleDetail();
  ListingDetail value;
  Object? error;
  Object? reportError;
  Object? clickError;
  int detailCalls = 0;
  final clicks = <(String, String)>[];
  final reports = <(String, String, String?)>[];

  @override
  Future<ListingDetail> detail(String id) async {
    detailCalls++;
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<void> recordContactClick(String id, {String channel = 'whatsapp'}) async {
    clicks.add((id, channel));
    if (clickError != null) throw clickError!;
  }

  @override
  Future<void> report(String id, String reason, {String? comment}) async {
    if (reportError != null) throw reportError!;
    reports.add((id, reason, comment));
  }
}

class FakeSession extends SessionController {
  FakeSession(this.me);
  final Me? me;

  @override
  Future<Me?> build() async => me;
}

Me me(String id) => Me(id: id, name: 'Moi', isSeller: true, createdAt: DateTime(2024));

Future<void> pumpListing(
  WidgetTester tester,
  FakeDetailRepository repo, {
  FakeUrlLauncher? launcher,
  Me? user,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/explore', routes: [
    GoRoute(path: '/explore', builder: (_, _) => const Scaffold(body: Text('Page Explorer'))),
    GoRoute(path: '/listing/:id', builder: (_, s) => ListingScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/seller/listings/:id', builder: (_, s) => ManageListingScreen(id: s.pathParameters['id']!)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      listingsRepositoryProvider.overrideWithValue(repo),
      urlLauncherProvider.overrideWithValue(launcher ?? FakeUrlLauncher()),
      sessionControllerProvider.overrideWith(() => FakeSession(user)),
      tileProviderOverrideProvider.overrideWithValue(BlankTileProvider()),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  ));
  router.push('/listing/1');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders title, price and facts from the detail', (tester) async {
    await pumpListing(tester, FakeDetailRepository());

    expect(find.text('Villa avec piscine'), findsOneWidget);
    expect(find.text(formatPrice(650000)), findsOneWidget);
    expect(find.text('/ mois'), findsOneWidget);
    expect(find.text('Riviera 3'), findsOneWidget);
    expect(find.text('pièces'), findsOneWidget);
    expect(find.text('chambres'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
    expect(find.text('Piscine'), findsOneWidget);
    expect(find.text('Koffi Adjoumani'), findsOneWidget);
    expect(find.text('3 annonces'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Faire une demande'), findsOneWidget);
  });

  testWidgets('« À la nuit » chip switches the price line', (tester) async {
    await pumpListing(tester, FakeDetailRepository());

    await tester.tap(find.text('À la nuit'));
    await tester.pumpAndSettle();

    expect(find.text(formatPrice(45000)), findsOneWidget);
    expect(find.text('/ nuit'), findsOneWidget);
    expect(find.text('/ mois'), findsNothing);
  });

  testWidgets('WhatsApp records the click and opens wa.me', (tester) async {
    final repo = FakeDetailRepository();
    final launcher = FakeUrlLauncher();
    await pumpListing(tester, repo, launcher: launcher);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    expect(launcher.launched.single, whatsappUri('+2250700000001', 'Villa avec piscine'));
    expect(repo.clicks, [('1', 'whatsapp')]);
  });

  testWidgets('without WhatsApp, offers the call and records channel call', (tester) async {
    final repo = FakeDetailRepository();
    final launcher = FakeUrlLauncher(failing: {'https'});
    await pumpListing(tester, repo, launcher: launcher);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text("WhatsApp n'est pas installé"), findsOneWidget);
    await tester.tap(find.text('Appeler'));
    await tester.pumpAndSettle();

    expect(launcher.launched.single.toString(), 'tel:+2250700000001');
    expect(repo.clicks, [('1', 'call')]);
  });

  testWidgets('seller without phone: WhatsApp disabled, request still possible', (tester) async {
    final repo = FakeDetailRepository(value: sampleDetail(phone: null));
    final launcher = FakeUrlLauncher();
    await pumpListing(tester, repo, launcher: launcher);

    await tester.tap(find.text('WhatsApp'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(launcher.launched, isEmpty);
    expect(repo.clicks, isEmpty);

    await tester.tap(find.text('Faire une demande'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('request-sheet')), findsOneWidget);
  });

  testWidgets('report flow sends the reason and returns to Explorer', (tester) async {
    final repo = FakeDetailRepository();
    await pumpListing(tester, repo);

    await tester.ensureVisible(find.text('Signaler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Signaler'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arnaque'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('report-comment')), 'Demande un acompte');
    await tester.tap(find.text('Envoyer le signalement'));
    await tester.pumpAndSettle();

    expect(repo.reports, [('1', 'scam', 'Demande un acompte')]);
    expect(find.text('Page Explorer'), findsOneWidget);
  });

  testWidgets('report failing offline keeps the sheet open with the message', (tester) async {
    final repo = FakeDetailRepository()..reportError = const ApiError.network();
    await pumpListing(tester, repo);

    await tester.ensureVisible(find.text('Signaler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Signaler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prix trompeur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer le signalement'));
    await tester.pumpAndSettle();

    expect(find.text(networkMessage), findsOneWidget);
    expect(find.text('Envoyer le signalement'), findsOneWidget);
    expect(find.text('Page Explorer'), findsNothing);
  });

  testWidgets('a failing click record does not disturb WhatsApp', (tester) async {
    final repo = FakeDetailRepository()..clickError = const ApiError.network();
    final launcher = FakeUrlLauncher();
    await pumpListing(tester, repo, launcher: launcher);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    expect(launcher.launched, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('own listing shows « Gérer l\'annonce » instead of the capsule', (tester) async {
    await pumpListing(tester, FakeDetailRepository(), user: me('s1'));

    expect(find.text("Gérer l'annonce"), findsOneWidget);
    expect(find.text('Faire une demande'), findsNothing);

    await tester.tap(find.text("Gérer l'annonce"));
    await tester.pumpAndSettle();
    expect(find.byType(ManageListingScreen), findsOneWidget);
  });

  testWidgets('someone else\'s listing keeps the capsule when signed in', (tester) async {
    await pumpListing(tester, FakeDetailRepository(), user: me('other'));
    expect(find.text("Gérer l'annonce"), findsNothing);
    expect(find.text('Faire une demande'), findsOneWidget);
  });

  testWidgets('404 shows « plus disponible » with a way back', (tester) async {
    final repo = FakeDetailRepository(
      error: const ApiError(status: 404, code: 'LISTING_NOT_FOUND', message: 'Annonce introuvable.'),
    );
    await pumpListing(tester, repo);

    expect(find.text("Cette annonce n'est plus disponible"), findsOneWidget);
    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Page Explorer'), findsOneWidget);
  });

  testWidgets('network error shows « Réessayer » and retries', (tester) async {
    final repo = FakeDetailRepository(error: const ApiError.network());
    await pumpListing(tester, repo);

    expect(find.text(networkMessage), findsOneWidget);
    repo.error = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Villa avec piscine'), findsOneWidget);
  });

  test('ExploreController.removeListing drops the reported listing', () async {
    final repo = FakeListingsRepository(result: [
      ListingCard(
        id: '1',
        title: 'A',
        propertyType: 'villa',
        city: 'Abidjan',
        district: 'Cocody',
        offers: const Offers(monthly: MonthlyOffer(rent: 1)),
        rooms: 1,
      ),
      ListingCard(
        id: '2',
        title: 'B',
        propertyType: 'villa',
        city: 'Abidjan',
        district: 'Cocody',
        offers: const Offers(monthly: MonthlyOffer(rent: 1)),
        rooms: 1,
      ),
    ]);
    final container = ProviderContainer(overrides: exploreOverrides(repo: repo));
    addTearDown(container.dispose);
    container.read(exploreControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(exploreControllerProvider).items, hasLength(2));

    container.read(exploreControllerProvider.notifier).removeListing('1');
    expect(container.read(exploreControllerProvider).items.map((c) => c.id), ['2']);
  });
}
