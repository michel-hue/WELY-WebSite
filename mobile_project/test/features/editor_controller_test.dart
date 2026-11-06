import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/features/listings/models.dart';
import 'package:mobile_project/features/seller/editor/editor_controller.dart';
import 'package:mobile_project/features/seller/seller_listings_repository.dart';

import '../helpers/fake_seller.dart';

/// Remplit les étapes 1 et 2 d'une nouvelle annonce.
void fillPropertyAndPlace(EditorController c) {
  c.propertyType = 'villa';
  c.title = '  Villa avec piscine ';
  c.rooms = '4';
  c.city = 'Abidjan';
  c.district = 'Riviera 3';
  c.location = const LatLng(5.36, -3.98);
}

void main() {
  test('step 1 does not call the API; finishing step 2 creates the draft once', () async {
    final repo = FakeEditorRepository();
    final c = EditorController(repo);
    expect(c.step, 0);
    expect(c.totalSteps, 5);

    fillPropertyAndPlace(c);
    expect(await c.next(), isTrue);
    expect(c.step, 1);
    expect(repo.created, isEmpty);

    expect(await c.next(), isTrue);
    expect(c.step, 2);
    expect(repo.created, hasLength(1));
    final body = repo.created.single;
    expect(body['title'], 'Villa avec piscine');
    expect(body['propertyType'], 'villa');
    expect(body['rooms'], 4);
    expect(body['city'], 'Abidjan');
    expect(body['district'], 'Riviera 3');
    expect(body['location'], {'lat': 5.36, 'lng': -3.98});
    expect(c.listingId, 'new1');

    // Revenir en arrière puis repasser l'étape 2 : modification, pas une seconde création.
    c.back();
    c.district = 'Riviera Palmeraie';
    expect(await c.next(), isTrue);
    expect(repo.created, hasLength(1));
    expect(repo.updates.single.$1, 'new1');
    expect(repo.updates.single.$2['district'], 'Riviera Palmeraie');
  });

  test('step 1 validation: type and title are required', () async {
    final repo = FakeEditorRepository();
    final c = EditorController(repo);
    c.title = 'ab';
    expect(await c.next(), isFalse);
    expect(c.step, 0);
    expect(c.fieldErrors['propertyType'], isNotNull);
    expect(c.fieldErrors['title'], isNotNull);
  });

  test('photos upload one by one; a failed photo can be retried without losing the others', () async {
    final repo = FakeEditorRepository()..failUploads.add('b.jpg');
    final c = EditorController(repo);
    fillPropertyAndPlace(c);
    await c.next();
    await c.next();

    // Pas de photo : l'étape 3 bloque.
    expect(await c.next(), isFalse);
    expect(c.fieldErrors['photos'], isNotNull);

    await c.addPhotos([fakeImage('a.jpg'), fakeImage('b.jpg'), fakeImage('c.jpg')]);
    expect(repo.uploaded, ['a.jpg', 'c.jpg']);
    expect(c.photos.where((p) => p.isUploaded), hasLength(2));
    final failed = c.photos.singleWhere((p) => p.failed);
    expect(failed.file!.name, 'b.jpg');

    await c.retryPhoto(failed);
    expect(repo.uploaded, ['a.jpg', 'c.jpg', 'b.jpg']);
    expect(c.photos.every((p) => p.isUploaded), isTrue);

    // Réordonner : la dernière devient la couverture.
    final ids = [for (final p in c.photos) p.photo!.id];
    await c.reorderPhotos(2, 0);
    expect(repo.reorders.single, [ids[2], ids[0], ids[1]]);

    expect(await c.next(), isTrue);
    expect(c.step, 3);
  });

  test('photos are capped at 15', () async {
    final repo = FakeEditorRepository();
    final c = EditorController(repo);
    fillPropertyAndPlace(c);
    await c.next();
    await c.next();
    await c.addPhotos([for (var i = 0; i < 17; i++) fakeImage('p$i.jpg')]);
    expect(c.photos, hasLength(EditorController.maxPhotos));
    expect(EditorController.maxPhotos, 15);
    expect(c.remainingPhotos, 0);
  });

  test('step 4 blocks without offer, then updates offers; step 5 publishes permanently', () async {
    final repo = FakeEditorRepository();
    final c = EditorController(repo);
    fillPropertyAndPlace(c);
    await c.next();
    await c.next();
    await c.addPhotos([fakeImage('a.jpg')]);
    await c.next();
    expect(c.step, 3);

    expect(await c.next(), isFalse);
    expect(c.step, 3);
    expect(c.fieldErrors['offers'], isNotNull);
    expect(repo.updates, isEmpty);

    c.monthlyEnabled = true;
    c.monthlyRent = '650 000';
    c.monthlyTerms = '3 mois de caution';
    c.nightlyEnabled = true;
    c.nightlyPrice = '';
    expect(await c.next(), isFalse, reason: 'nightly enabled without price');
    expect(c.fieldErrors['offers.nightly.price'], isNotNull);

    c.nightlyPrice = '30000';
    c.minNights = '2';
    expect(await c.next(), isTrue);
    expect(c.step, 4);
    expect(repo.updates.single.$1, 'new1');
    expect(repo.updates.single.$2, {
      'offers': {
        'monthly': {'rent': 650000, 'terms': '3 mois de caution'},
        'nightly': {'price': 30000, 'minNights': 2},
        'sale': null,
      },
    });

    c.permanent = true;
    expect(await c.next(), isTrue);
    expect(repo.calls, ['publish:new1:permanent']);
    expect(c.done, isTrue);
  });

  test('publish with an end date sends AAAA-MM-JJ; API error stays in place', () async {
    final repo = FakeEditorRepository(existing: editorListing(
      offers: const Offers(sale: SaleOffer(price: 85000000)),
      photos: [samplePhoto('p1')],
    ));
    final c = EditorController(repo, listingId: 'l1');
    await c.load();
    c.step = 4;
    c.permanent = false;
    c.until = DateTime(2026, 12, 31);
    repo.actionError = const ApiError(
      status: 422,
      code: 'INVALID_PUBLICATION_DATE',
      message: 'La date de fin doit être aujourd’hui ou plus tard.',
    );
    expect(await c.next(), isFalse);
    expect(c.error?.code, 'INVALID_PUBLICATION_DATE');
    expect(c.done, isFalse);

    expect(await c.next(), isTrue);
    expect(repo.calls.last, 'publish:l1:2026-12-31');
  });

  test('editing an existing draft prefills fields and saves step 1 with update', () async {
    final repo = FakeEditorRepository(existing: editorListing(
      offers: const Offers(monthly: MonthlyOffer(rent: 650000, terms: 'Caution')),
      photos: [samplePhoto('p1')],
    ));
    final c = EditorController(repo, listingId: 'l1');
    await c.load();
    expect(c.title, 'Villa avec piscine');
    expect(c.propertyType, 'villa');
    expect(c.rooms, '4');
    expect(c.amenities, {'pool'});
    expect(c.monthlyEnabled, isTrue);
    expect(c.monthlyRent, '650000');
    expect(c.photos.single.photo!.id, 'p1');

    c.title = 'Villa rénovée';
    expect(await c.next(), isTrue);
    expect(repo.created, isEmpty);
    expect(repo.updates.single.$2['title'], 'Villa rénovée');
  });

  test('an online listing has 4 steps: the last one saves offers and finishes', () async {
    final repo = FakeEditorRepository(existing: editorListing(
      status: ListingStatus.online,
      offers: const Offers(monthly: MonthlyOffer(rent: 650000)),
      photos: [samplePhoto('p1')],
    ));
    final c = EditorController(repo, listingId: 'l1');
    await c.load();
    expect(c.totalSteps, 4);
    c.step = 3;
    expect(await c.next(), isTrue);
    expect(c.done, isTrue);
    expect(repo.calls.where((x) => x.startsWith('publish')), isEmpty);
  });

  test('offline during create: soft error, still on step 2', () async {
    final repo = FakeEditorRepository()..actionError = const ApiError.network();
    final c = EditorController(repo);
    fillPropertyAndPlace(c);
    await c.next();
    expect(await c.next(), isFalse);
    expect(c.step, 1);
    expect(c.error?.isNetwork, isTrue);
    expect(c.saving, isFalse);
  });
}
