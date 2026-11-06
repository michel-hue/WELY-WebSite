import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_project/core/api/api_client.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/session/session_store.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/favorites/favorites_controller.dart';
import 'package:mobile_project/features/listings/models.dart' hide Page;
import 'package:mobile_project/features/requests/models.dart';
import 'package:mobile_project/features/requests/request_sheet.dart';
import 'package:mobile_project/features/requests/requests_repository.dart';

import '../helpers/fake_adapter.dart';
import '../helpers/fake_auth.dart';
import 'listing_screen_test.dart' show sampleDetail;
import 'listings_models_test.dart' show cardJson;

Map<String, dynamic> requestJson({bool buyerSide = true}) => {
      'id': 'r1',
      'status': 'refused',
      'refusalReason': 'dates_unavailable',
      'sellerMessage': 'Désolé',
      'offerType': 'nightly',
      'checkIn': '2026-12-10',
      'checkOut': '2026-12-13',
      'moveInDate': null,
      'wantsVisit': true,
      'message': 'Bonjour',
      'createdAt': '2026-11-05T10:00:00.000Z',
      'decidedAt': '2026-11-06T09:00:00.000Z',
      'listing': cardJson,
      if (buyerSide)
        'seller': {'id': 's1', 'name': 'Koffi', 'phone': '+2250700000001', 'whatsappPhone': '+2250700000002'}
      else
        'buyer': {'id': 'b1', 'name': 'Awa Traoré', 'phone': '+2250712345678'},
    };

typedef CreateCall = ({
  String listingId,
  OfferType offerType,
  DateTime? checkIn,
  DateTime? checkOut,
  DateTime? moveInDate,
  String? message,
  bool wantsVisit,
});

class FakeRequestsRepository extends Fake implements RequestsRepository {
  FakeRequestsRepository(this.log);
  final List<String> log;
  final calls = <CreateCall>[];
  final errors = <Object>[];

  @override
  Future<ListingRequest> create({
    required String listingId,
    required OfferType offerType,
    DateTime? checkIn,
    DateTime? checkOut,
    DateTime? moveInDate,
    String? message,
    bool wantsVisit = false,
  }) async {
    log.add('create');
    calls.add((
      listingId: listingId,
      offerType: offerType,
      checkIn: checkIn,
      checkOut: checkOut,
      moveInDate: moveInDate,
      message: message,
      wantsVisit: wantsVisit,
    ));
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return ListingRequest.fromJson(requestJson());
  }
}

class FakePickers extends RequestDatePickers {
  int stayCalls = 0;
  DateTimeRange? stay = DateTimeRange(start: DateTime(2026, 12, 10), end: DateTime(2026, 12, 13));
  DateTime? day = DateTime(2027, 1, 1);

  @override
  Future<DateTimeRange?> pickStay(BuildContext context, {DateTimeRange? initial}) async {
    stayCalls++;
    return stay;
  }

  @override
  Future<DateTime?> pickDay(BuildContext context, {DateTime? initial}) async => day;
}

class Harness {
  Harness(this.session, this.repo, this.pickers, this.log);
  final FakeAuthSession session;
  final FakeRequestsRepository repo;
  final FakePickers pickers;
  final List<String> log;
}

Future<Harness> openSheet(
  WidgetTester tester, {
  Me? user,
  ListingDetail? listing,
  OfferType offer = OfferType.nightly,
  bool favoritesFail = false,
  FakeAuthSession? session,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final log = <String>[];
  final h = Harness(session ?? FakeAuthSession(initial: user, log: log), FakeRequestsRepository(log), FakePickers(), log);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(() => h.session),
      favoritesProvider.overrideWith(() => FakeFavorites(log, fail: favoritesFail)),
      requestsRepositoryProvider.overrideWithValue(h.repo),
      requestDatePickersProvider.overrideWithValue(h.pickers),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRequestSheet(context, listing ?? sampleDetail(), offer),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> fillAnonymous(WidgetTester tester, {String name = 'Awa Traoré'}) async {
  await tapKey(tester, 'request-dates');
  await tester.enterText(find.byKey(const Key('request-message')), 'Bonjour, est-ce libre ?');
  await tapKey(tester, 'request-visit');
  await tester.enterText(find.byKey(const Key('otp-name')), name);
  await tester.enterText(find.byKey(const Key('otp-phone')), '07 12 34 56 78');
  await tapKey(tester, 'otp-send-code');
}

void main() {
  testWidgets('anonymous: name + phone, code, then verify (with name) -> favorites -> create', (tester) async {
    final h = await openSheet(tester);
    expect(find.text('Votre nom et votre numéro seront transmis au vendeur'), findsOneWidget);

    await fillAnonymous(tester);
    expect(h.session.otpRequests, ['+2250712345678']);

    await tester.enterText(find.byKey(const Key('otp-code')), '481516');
    await tester.pumpAndSettle();

    expect(h.session.verifications.single, ('+2250712345678', '481516', 'Awa Traoré'));
    expect(h.log, ['requestOtp', 'verify', 'favorites', 'create']);
    final call = h.repo.calls.single;
    expect(call.listingId, '1');
    expect(call.offerType, OfferType.nightly);
    expect(call.checkIn, DateTime(2026, 12, 10));
    expect(call.checkOut, DateTime(2026, 12, 13));
    expect(call.message, 'Bonjour, est-ce libre ?');
    expect(call.wantsVisit, isTrue);

    expect(find.byKey(const Key('request-sheet')), findsNothing);
    expect(find.textContaining('Demande envoyée'), findsOneWidget);
  });

  testWidgets('nightly without dates: asks for dates before sending the code', (tester) async {
    final h = await openSheet(tester);
    await tester.enterText(find.byKey(const Key('otp-name')), 'Awa Traoré');
    await tester.enterText(find.byKey(const Key('otp-phone')), '07 12 34 56 78');
    await tapKey(tester, 'otp-send-code');
    expect(h.session.otpRequests, isEmpty);
    expect(find.text('Choisissez vos dates.'), findsOneWidget);
  });

  testWidgets('stay shorter than minNights is refused locally', (tester) async {
    final h = await openSheet(tester);
    h.pickers.stay = DateTimeRange(start: DateTime(2026, 12, 10), end: DateTime(2026, 12, 11));
    await tapKey(tester, 'request-dates');
    expect(find.text('Ce logement demande au moins 2 nuits.'), findsOneWidget);
  });

  testWidgets('OTP_INVALID: message in the sheet, sheet stays open, data kept', (tester) async {
    final h = await openSheet(tester);
    await fillAnonymous(tester);
    h.session.verifyErrors.add(otpInvalid);
    await tester.enterText(find.byKey(const Key('otp-code')), '000000');
    await tester.pumpAndSettle();

    expect(find.text('Code incorrect ou expiré.'), findsOneWidget);
    expect(find.byKey(const Key('request-sheet')), findsOneWidget);
    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(find.text('Bonjour, est-ce libre ?'), findsOneWidget);
    expect(h.repo.calls, isEmpty);
  });

  testWidgets('VALIDATION_ERROR on name is shown under the name field', (tester) async {
    final h = await openSheet(tester);
    await fillAnonymous(tester, name: '');
    h.session.verifyErrors.add(nameMissing);
    await tester.enterText(find.byKey(const Key('otp-code')), '123456');
    await tester.pumpAndSettle();

    expect(find.text('Indiquez votre nom (2 caractères minimum).'), findsOneWidget);
    expect(find.byKey(const Key('request-sheet')), findsOneWidget);
    expect(h.repo.calls, isEmpty);
  });

  testWidgets('favorites sync failure does not block the request', (tester) async {
    final h = await openSheet(tester, favoritesFail: true);
    await fillAnonymous(tester);
    await tester.enterText(find.byKey(const Key('otp-code')), '123456');
    await tester.pumpAndSettle();
    expect(h.repo.calls, hasLength(1));
    expect(find.byKey(const Key('request-sheet')), findsNothing);
  });

  testWidgets('account unreachable: « Réessayer » instead of a new SMS code, then the signed-in form', (tester) async {
    final session = OfflineSession();
    await openSheet(tester, session: session);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byKey(const Key('otp-phone')), findsNothing);

    session.offline = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsNothing);
    expect(find.byKey(const Key('otp-phone')), findsNothing);
    expect(find.byKey(const Key('request-submit')), findsOneWidget);
  });

  testWidgets('signed in: no phone/code fields, create directly', (tester) async {
    final h = await openSheet(tester, user: signedInUser());
    expect(find.byKey(const Key('otp-phone')), findsNothing);
    expect(find.byKey(const Key('otp-code')), findsNothing);
    expect(find.byKey(const Key('otp-name')), findsNothing);

    await tapKey(tester, 'request-dates');
    await tapKey(tester, 'request-submit');
    expect(h.session.verifications, isEmpty);
    expect(h.repo.calls.single.offerType, OfferType.nightly);
    expect(find.byKey(const Key('request-sheet')), findsNothing);
  });

  testWidgets('STAY_DATES_UNAVAILABLE shows under the dates and keeps the sheet', (tester) async {
    final h = await openSheet(tester, user: signedInUser());
    h.repo.errors.add(const ApiError(status: 409, code: 'STAY_DATES_UNAVAILABLE', message: 'Ces dates ne sont plus disponibles.'));
    await tapKey(tester, 'request-dates');
    await tester.enterText(find.byKey(const Key('request-message')), 'Merci');
    await tapKey(tester, 'request-submit');

    expect(find.byKey(const Key('request-dates-error')), findsOneWidget);
    expect(find.text('Ces dates ne sont plus disponibles.'), findsOneWidget);
    expect(find.byKey(const Key('request-sheet')), findsOneWidget);
    expect(find.text('Merci'), findsOneWidget);
  });

  testWidgets('other errors (already pending, offline) show in a soft banner', (tester) async {
    final h = await openSheet(tester, user: signedInUser(), offer: OfferType.monthly);
    h.repo.errors
      ..add(const ApiError(status: 409, code: 'REQUEST_ALREADY_PENDING', message: 'Vous avez déjà une demande en attente pour ce bien.'))
      ..add(const ApiError.network());
    await tapKey(tester, 'request-submit');
    expect(find.text('Vous avez déjà une demande en attente pour ce bien.'), findsOneWidget);
    await tapKey(tester, 'request-submit');
    expect(find.text(networkMessage), findsOneWidget);
    expect(find.byKey(const Key('request-sheet')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('monthly: optional move-in date, no stay dates', (tester) async {
    final h = await openSheet(tester, user: signedInUser(), offer: OfferType.monthly);
    expect(find.byKey(const Key('request-dates')), findsNothing);
    await tapKey(tester, 'request-move-in');
    await tapKey(tester, 'request-submit');
    final call = h.repo.calls.single;
    expect(call.offerType, OfferType.monthly);
    expect(call.moveInDate, DateTime(2027, 1, 1));
    expect(call.checkIn, isNull);
  });

  testWidgets('offer chips: only the listing offers; switching changes the fields', (tester) async {
    await openSheet(tester, user: signedInUser(), offer: OfferType.sale);
    // sampleDetail : mois + nuit, pas de vente -> on retombe sur la première offre.
    expect(find.text('À vendre'), findsNothing);
    expect(find.byKey(const Key('request-move-in')), findsOneWidget);
    await tester.tap(find.text('À la nuit'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('request-dates')), findsOneWidget);
  });

  testWidgets('listing without offers: short message, no send button', (tester) async {
    final base = sampleDetail();
    final noOffers = ListingDetail(
      id: base.id,
      title: base.title,
      propertyType: base.propertyType,
      city: base.city,
      district: base.district,
      offers: const Offers(),
      rooms: base.rooms,
      description: base.description,
      seller: base.seller,
    );
    await openSheet(tester, user: signedInUser(), listing: noOffers, offer: OfferType.monthly);
    expect(find.text('Aucune offre n’est proposée pour ce logement.'), findsOneWidget);
    expect(find.byKey(const Key('request-submit')), findsNothing);
    expect(find.byKey(const Key('otp-send-code')), findsNothing);
  });

  group('RequestsRepository', () {
    RequestsRepository repo(FakeAdapter a) {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWithValue(MemorySessionStore(access: 'tok')),
        httpAdapterProvider.overrideWithValue(a),
      ]);
      addTearDown(c.dispose);
      return c.read(requestsRepositoryProvider);
    }

    test('create posts the nightly body with ISO dates', () async {
      final a = FakeAdapter((o) async => jsonBody(requestJson(), 201));
      final r = await repo(a).create(
        listingId: 'l1',
        offerType: OfferType.nightly,
        checkIn: DateTime(2026, 12, 10),
        checkOut: DateTime(2026, 12, 13),
        message: '  Bonjour  ',
        wantsVisit: true,
      );
      final req = a.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/requests');
      expect(req.data, {
        'listingId': 'l1',
        'offerType': 'nightly',
        'checkIn': '2026-12-10',
        'checkOut': '2026-12-13',
        'wantsVisit': true,
        'message': 'Bonjour',
      });
      expect(r.status, RequestStatus.refused);
      expect(r.refusalReason, RefusalReason.datesUnavailable);
      expect(r.seller!.whatsappPhone, '+2250700000002');
      expect(r.buyer, isNull);
      expect(r.checkIn, DateTime(2026, 12, 10));
      expect(r.listing.title, 'Appartement lumineux à Cocody');
    });

    test('mine / received paginate with status and cursor; seller side has buyer', () async {
      final a = FakeAdapter((o) async => jsonBody({
            'data': [requestJson(buyerSide: o.path != '/me/received-requests')],
            'nextCursor': 'c2',
          }));
      final r = repo(a);
      final mine = await r.mine(status: RequestStatus.pending, cursor: 'c1');
      expect(a.requests.last.path, '/me/requests');
      expect(a.requests.last.queryParameters, {'status': 'pending', 'cursor': 'c1'});
      expect(mine.nextCursor, 'c2');
      final received = await r.received();
      expect(a.requests.last.path, '/me/received-requests');
      expect(a.requests.last.queryParameters, isEmpty);
      expect(received.data.single.buyer!.name, 'Awa Traoré');
    });

    test('accept / refuse / cancel hit their endpoints; errors become ApiError', () async {
      final a = FakeAdapter((o) async => o.path.endsWith('/cancel')
          ? jsonBody({'error': {'code': 'REQUEST_NOT_CANCELLABLE', 'message': 'Cette demande ne peut plus être annulée.'}}, 422)
          : jsonBody(requestJson(buyerSide: false)));
      final r = repo(a);
      await r.accept('r1');
      expect(a.requests.last.path, '/requests/r1/accept');
      await r.refuse('r1', message: 'Plus disponible');
      expect(a.requests.last.path, '/requests/r1/refuse');
      expect(a.requests.last.data, {'message': 'Plus disponible'});
      await expectLater(
        r.cancel('r1'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'REQUEST_NOT_CANCELLABLE')),
      );
    });
  });
}
