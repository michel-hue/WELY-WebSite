import 'package:latlong2/latlong.dart';

enum OfferType { monthly, nightly, sale }

LatLng? _latLng(Object? j) => j is Map ? LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()) : null;

class MonthlyOffer {
  const MonthlyOffer({required this.rent, this.terms});
  final int rent;
  final String? terms;
  factory MonthlyOffer.fromJson(Map<String, dynamic> j) =>
      MonthlyOffer(rent: (j['rent'] as num).toInt(), terms: j['terms'] as String?);
}

class NightlyOffer {
  const NightlyOffer({required this.price, this.minNights});
  final int price;
  final int? minNights;
  factory NightlyOffer.fromJson(Map<String, dynamic> j) =>
      NightlyOffer(price: (j['price'] as num).toInt(), minNights: (j['minNights'] as num?)?.toInt());
}

class SaleOffer {
  const SaleOffer({required this.price});
  final int price;
  factory SaleOffer.fromJson(Map<String, dynamic> j) => SaleOffer(price: (j['price'] as num).toInt());
}

class Offers {
  const Offers({this.monthly, this.nightly, this.sale});
  final MonthlyOffer? monthly;
  final NightlyOffer? nightly;
  final SaleOffer? sale;

  factory Offers.fromJson(Map<String, dynamic> j) => Offers(
        monthly: j['monthly'] is Map ? MonthlyOffer.fromJson((j['monthly'] as Map).cast<String, dynamic>()) : null,
        nightly: j['nightly'] is Map ? NightlyOffer.fromJson((j['nightly'] as Map).cast<String, dynamic>()) : null,
        sale: j['sale'] is Map ? SaleOffer.fromJson((j['sale'] as Map).cast<String, dynamic>()) : null,
      );

  /// Même forme que l'API (stockage local des favoris).
  Map<String, dynamic> toJson() => {
        'monthly': monthly == null ? null : {'rent': monthly!.rent, 'terms': monthly!.terms},
        'nightly': nightly == null ? null : {'price': nightly!.price, 'minNights': nightly!.minNights},
        'sale': sale == null ? null : {'price': sale!.price},
      };

  List<OfferType> get types => [
        if (monthly != null) OfferType.monthly,
        if (nightly != null) OfferType.nightly,
        if (sale != null) OfferType.sale,
      ];

  int? priceOf(OfferType t) => switch (t) {
        OfferType.monthly => monthly?.rent,
        OfferType.nightly => nightly?.price,
        OfferType.sale => sale?.price,
      };

  /// Offre mise en avant : mensuel, puis nuitée, puis vente.
  ({OfferType type, int price})? get primary {
    for (final t in OfferType.values) {
      final p = priceOf(t);
      if (p != null) return (type: t, price: p);
    }
    return null;
  }
}

class Photo {
  const Photo({
    required this.id,
    required this.thumbUrl,
    required this.largeUrl,
    required this.width,
    required this.height,
    required this.position,
  });
  final String id;
  final String thumbUrl;
  final String largeUrl;
  final int width;
  final int height;
  final int position;

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        id: j['id'] as String,
        thumbUrl: j['thumbUrl'] as String,
        largeUrl: j['largeUrl'] as String,
        width: (j['width'] as num).toInt(),
        height: (j['height'] as num).toInt(),
        position: (j['position'] as num).toInt(),
      );
}

class PublicSeller {
  const PublicSeller({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.memberSince,
    required this.onlineListingsCount,
    this.phone,
    this.whatsappPhone,
  });
  final String id;
  final String name;
  final String? avatarUrl;
  final DateTime memberSince;
  final int onlineListingsCount;
  final String? phone;
  final String? whatsappPhone;

  factory PublicSeller.fromJson(Map<String, dynamic> j) => PublicSeller(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarUrl: j['avatarUrl'] as String?,
        memberSince: DateTime.parse(j['memberSince'] as String),
        onlineListingsCount: (j['onlineListingsCount'] as num? ?? 0).toInt(),
        phone: j['phone'] as String?,
        whatsappPhone: j['whatsappPhone'] as String?,
      );
}

class ListingCard {
  const ListingCard({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.city,
    required this.district,
    this.coverThumbUrl,
    required this.offers,
    required this.rooms,
    this.distanceMeters,
    this.publishedAt,
    this.approxLocation,
  });

  final String id;
  final String title;
  final String propertyType;
  final String city;
  final String district;
  final String? coverThumbUrl;
  final Offers offers;
  final int rooms;
  final int? distanceMeters;
  final DateTime? publishedAt;
  final LatLng? approxLocation;

  factory ListingCard.fromJson(Map<String, dynamic> j) => ListingCard(
        id: j['id'] as String,
        title: j['title'] as String,
        propertyType: j['propertyType'] as String,
        city: j['city'] as String,
        district: j['district'] as String,
        coverThumbUrl: j['coverThumbUrl'] as String?,
        offers: Offers.fromJson((j['offers'] as Map?)?.cast<String, dynamic>() ?? const {}),
        rooms: (j['rooms'] as num? ?? 0).toInt(),
        distanceMeters: (j['distanceMeters'] as num?)?.toInt(),
        publishedAt: j['publishedAt'] == null ? null : DateTime.parse(j['publishedAt'] as String),
        approxLocation: _latLng(j['approxLocation']),
      );

  /// Champs de carte seulement, au format de l'API (relu par [ListingCard.fromJson]).
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'propertyType': propertyType,
        'city': city,
        'district': district,
        'coverThumbUrl': coverThumbUrl,
        'offers': offers.toJson(),
        'rooms': rooms,
        'distanceMeters': distanceMeters,
        'publishedAt': publishedAt?.toIso8601String(),
        'approxLocation': approxLocation == null
            ? null
            : {'lat': approxLocation!.latitude, 'lng': approxLocation!.longitude},
      };
}

class ListingDetail extends ListingCard {
  const ListingDetail({
    required super.id,
    required super.title,
    required super.propertyType,
    required super.city,
    required super.district,
    super.coverThumbUrl,
    required super.offers,
    required super.rooms,
    super.distanceMeters,
    super.publishedAt,
    super.approxLocation,
    required this.description,
    this.bedrooms,
    this.bathrooms,
    this.surfaceM2,
    this.amenities = const [],
    this.address,
    this.location,
    this.photos = const [],
    required this.seller,
  });

  final String description;
  final int? bedrooms;
  final int? bathrooms;
  final int? surfaceM2;
  final List<String> amenities;
  final String? address;
  final LatLng? location;
  final List<Photo> photos;
  final PublicSeller seller;

  factory ListingDetail.fromJson(Map<String, dynamic> j) {
    final c = ListingCard.fromJson(j);
    return ListingDetail(
      id: c.id,
      title: c.title,
      propertyType: c.propertyType,
      city: c.city,
      district: c.district,
      coverThumbUrl: c.coverThumbUrl,
      offers: c.offers,
      rooms: c.rooms,
      distanceMeters: c.distanceMeters,
      publishedAt: c.publishedAt,
      approxLocation: c.approxLocation,
      description: (j['description'] ?? '') as String,
      bedrooms: (j['bedrooms'] as num?)?.toInt(),
      bathrooms: (j['bathrooms'] as num?)?.toInt(),
      surfaceM2: (j['surfaceM2'] as num?)?.toInt(),
      amenities: [for (final a in (j['amenities'] as List? ?? const [])) a as String],
      address: j['address'] as String?,
      location: _latLng(j['location']),
      photos: [
        for (final p in (j['photos'] as List? ?? const [])) Photo.fromJson((p as Map).cast<String, dynamic>()),
      ],
      seller: PublicSeller.fromJson((j['seller'] as Map).cast<String, dynamic>()),
    );
  }
}

class Page<T> {
  const Page({required this.data, this.nextCursor});
  final List<T> data;
  final String? nextCursor;
}

class LocationCity {
  const LocationCity({required this.city, required this.districts});
  final String city;
  final List<String> districts;
}

enum SearchSort {
  distance,
  recent,
  priceAsc('price_asc'),
  priceDesc('price_desc');

  const SearchSort([this._wire]);
  final String? _wire;
  String get wire => _wire ?? name;
}

const _unset = Object();

class SearchFilters {
  const SearchFilters({
    this.q,
    this.offerType,
    this.propertyTypes = const [],
    this.city,
    this.district,
    this.priceMin,
    this.priceMax,
    this.roomsMin,
    this.bedroomsMin,
    this.amenities = const [],
    this.checkIn,
    this.checkOut,
    this.sort,
  });

  final String? q;
  final OfferType? offerType;
  final List<String> propertyTypes;
  final String? city;
  final String? district;
  final int? priceMin;
  final int? priceMax;
  final int? roomsMin;
  final int? bedroomsMin;
  final List<String> amenities;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final SearchSort? sort;

  /// Passer `null` explicitement efface le champ.
  SearchFilters copyWith({
    Object? q = _unset,
    Object? offerType = _unset,
    List<String>? propertyTypes,
    Object? city = _unset,
    Object? district = _unset,
    Object? priceMin = _unset,
    Object? priceMax = _unset,
    Object? roomsMin = _unset,
    Object? bedroomsMin = _unset,
    List<String>? amenities,
    Object? checkIn = _unset,
    Object? checkOut = _unset,
    Object? sort = _unset,
  }) =>
      SearchFilters(
        q: identical(q, _unset) ? this.q : q as String?,
        offerType: identical(offerType, _unset) ? this.offerType : offerType as OfferType?,
        propertyTypes: propertyTypes ?? this.propertyTypes,
        city: identical(city, _unset) ? this.city : city as String?,
        district: identical(district, _unset) ? this.district : district as String?,
        priceMin: identical(priceMin, _unset) ? this.priceMin : priceMin as int?,
        priceMax: identical(priceMax, _unset) ? this.priceMax : priceMax as int?,
        roomsMin: identical(roomsMin, _unset) ? this.roomsMin : roomsMin as int?,
        bedroomsMin: identical(bedroomsMin, _unset) ? this.bedroomsMin : bedroomsMin as int?,
        amenities: amenities ?? this.amenities,
        checkIn: identical(checkIn, _unset) ? this.checkIn : checkIn as DateTime?,
        checkOut: identical(checkOut, _unset) ? this.checkOut : checkOut as DateTime?,
        sort: identical(sort, _unset) ? this.sort : sort as SearchSort?,
      );

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Paramètres de requête de `GET /v1/listings` (listes jointes par des virgules).
  Map<String, String> toQuery() => {
        if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
        if (offerType != null) 'offerType': offerType!.name,
        if (propertyTypes.isNotEmpty) 'propertyType': propertyTypes.join(','),
        'city': ?city,
        'district': ?district,
        if (priceMin != null) 'priceMin': '$priceMin',
        if (priceMax != null) 'priceMax': '$priceMax',
        if (roomsMin != null) 'roomsMin': '$roomsMin',
        if (bedroomsMin != null) 'bedroomsMin': '$bedroomsMin',
        if (amenities.isNotEmpty) 'amenities': amenities.join(','),
        if (checkIn != null) 'checkIn': _ymd(checkIn!),
        if (checkOut != null) 'checkOut': _ymd(checkOut!),
        if (sort != null) 'sort': sort!.wire,
      };

  /// Nombre de filtres actifs (prix min/max et dates comptent chacun pour un ; ni `q` ni le tri).
  int get activeCount =>
      (offerType != null ? 1 : 0) +
      (propertyTypes.isNotEmpty ? 1 : 0) +
      (city != null ? 1 : 0) +
      (district != null ? 1 : 0) +
      (priceMin != null || priceMax != null ? 1 : 0) +
      (roomsMin != null ? 1 : 0) +
      (bedroomsMin != null ? 1 : 0) +
      (amenities.isNotEmpty ? 1 : 0) +
      (checkIn != null || checkOut != null ? 1 : 0);
}
