import '../listings/models.dart';

enum RequestStatus { pending, accepted, refused, cancelled }

enum RefusalReason {
  seller('seller'),
  datesUnavailable('dates_unavailable'),
  listingUnavailable('listing_unavailable');

  const RefusalReason(this.wire);
  final String wire;

  static RefusalReason? parse(Object? v) {
    for (final r in values) {
      if (r.wire == v) return r;
    }
    return null;
  }
}

/// Contact du vendeur, côté acheteur (même une fois l'annonce close).
class RequestSeller {
  const RequestSeller({required this.id, required this.name, this.phone, this.whatsappPhone});
  final String id;
  final String name;
  final String? phone;
  final String? whatsappPhone;

  factory RequestSeller.fromJson(Map<String, dynamic> j) => RequestSeller(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        whatsappPhone: j['whatsappPhone'] as String?,
      );
}

/// Contact de l'acheteur, côté vendeur.
class RequestBuyer {
  const RequestBuyer({required this.id, required this.name, this.phone});
  final String id;
  final String name;
  final String? phone;

  factory RequestBuyer.fromJson(Map<String, dynamic> j) =>
      RequestBuyer(id: j['id'] as String, name: j['name'] as String, phone: j['phone'] as String?);
}

DateTime? _day(Object? v) => v is String ? DateTime.parse(v) : null;

/// `RequestDto` de l'API.
class ListingRequest {
  const ListingRequest({
    required this.id,
    required this.status,
    this.refusalReason,
    this.sellerMessage,
    required this.offerType,
    this.checkIn,
    this.checkOut,
    this.moveInDate,
    required this.wantsVisit,
    this.message,
    required this.createdAt,
    this.decidedAt,
    required this.listing,
    this.buyer,
    this.seller,
  });

  final String id;
  final RequestStatus status;
  final RefusalReason? refusalReason;
  final String? sellerMessage;
  final OfferType offerType;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final DateTime? moveInDate;
  final bool wantsVisit;
  final String? message;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final ListingCard listing;
  final RequestBuyer? buyer;
  final RequestSeller? seller;

  factory ListingRequest.fromJson(Map<String, dynamic> j) => ListingRequest(
        id: j['id'] as String,
        status: RequestStatus.values.byName(j['status'] as String),
        refusalReason: RefusalReason.parse(j['refusalReason']),
        sellerMessage: j['sellerMessage'] as String?,
        offerType: OfferType.values.byName(j['offerType'] as String),
        checkIn: _day(j['checkIn']),
        checkOut: _day(j['checkOut']),
        moveInDate: _day(j['moveInDate']),
        wantsVisit: j['wantsVisit'] as bool? ?? false,
        message: j['message'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        decidedAt: _day(j['decidedAt']),
        listing: ListingCard.fromJson((j['listing'] as Map).cast<String, dynamic>()),
        buyer: j['buyer'] is Map ? RequestBuyer.fromJson((j['buyer'] as Map).cast<String, dynamic>()) : null,
        seller: j['seller'] is Map ? RequestSeller.fromJson((j['seller'] as Map).cast<String, dynamic>()) : null,
      );
}

/// `2026-12-10` (date locale, sans fuseau).
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
