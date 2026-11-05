import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_project/features/explore/cluster.dart';
import 'package:mobile_project/features/listings/models.dart';

ListingCard card(String id, LatLng? at) => ListingCard(
      id: id,
      title: 'Logement $id',
      propertyType: 'apartment',
      city: 'Abidjan',
      district: 'Plateau',
      offers: const Offers(monthly: MonthlyOffer(rent: 100000)),
      rooms: 2,
      approxLocation: at,
    );

void main() {
  // ~50 m au nord l'un de l'autre.
  const a = LatLng(5.3197, -4.0267);
  const b = LatLng(5.31925, -4.0267);

  test('merges two points 50 m apart at zoom 12', () {
    final clusters = clusterPoints([card('a', a), card('b', b)], zoom: 12);
    expect(clusters, hasLength(1));
    expect(clusters.single.items.map((c) => c.id), unorderedEquals(['a', 'b']));
    expect(clusters.single.center.latitude, closeTo((a.latitude + b.latitude) / 2, 1e-9));
  });

  test('keeps them separate at zoom 18', () {
    final clusters = clusterPoints([card('a', a), card('b', b)], zoom: 18);
    expect(clusters, hasLength(2));
    expect(clusters.every((c) => c.items.length == 1), isTrue);
  });

  test('ignores cards without approxLocation', () {
    final clusters = clusterPoints([card('a', a), card('x', null)], zoom: 12);
    expect(clusters, hasLength(1));
    expect(clusters.single.items.single.id, 'a');
    expect(clusterPoints([card('x', null)], zoom: 12), isEmpty);
  });
}
