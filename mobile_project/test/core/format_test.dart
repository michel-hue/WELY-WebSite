import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/core/format.dart';
import 'package:mobile_project/core/labels.dart';
import 'package:mobile_project/features/listings/models.dart';

void main() {
  test('formatPrice uses narrow no-break space and F suffix', () {
    expect(formatPrice(650000), '650 000 F');
    expect(formatPrice(1200000), '1 200 000 F');
    expect(formatPrice(500), '500 F');
  });

  test('priceSuffix', () {
    expect(priceSuffix(OfferType.monthly), '/ mois');
    expect(priceSuffix(OfferType.nightly), '/ nuit');
    expect(priceSuffix(OfferType.sale), '');
  });

  test('formatDistance', () {
    expect(formatDistance(800), '800 m');
    expect(formatDistance(1234), '1,2 km');
    expect(formatDistance(2000), '2 km');
  });

  test('formatDate french', () {
    expect(formatDate(DateTime(2026, 12, 1)), '1 déc.');
    expect(formatDate(DateTime(2026, 12, 1), long: true), '1er décembre');
    expect(formatDate(DateTime(2026, 2, 14), long: true, withYear: true), '14 février 2026');
  });

  test('labels cover API enums', () {
    expect(propertyTypeLabels['apartment'], 'Appartement');
    expect(propertyTypeLabels.length, 7);
    expect(amenityLabels.length, 10);
    expect(reportReasonLabels.length, 5);
    expect(refusalReasonLabels.length, 3);
    expect(listingStatusLabels['online'], 'En ligne');
  });
}
