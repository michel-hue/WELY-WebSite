import 'package:latlong2/latlong.dart';

import '../listings/models.dart';

/// État d'une annonce côté vendeur (`SellerListingDto.status`).
enum ListingStatus {
  draft,
  online,
  expired,
  deactivated,
  closed;

  static ListingStatus parse(Object? v) {
    for (final s in values) {
      if (s.name == v) return s;
    }
    return ListingStatus.deactivated;
  }
}

/// Motif de clôture (`POST /listings/:id/close`).
enum ClosedReason {
  rented,
  sold;

  static ClosedReason? parse(Object? v) {
    for (final r in values) {
      if (r.name == v) return r;
    }
    return null;
  }
}

/// Compteurs visibles du seul vendeur.
class ListingStats {
  const ListingStats({required this.views, required this.contactClicks, required this.requests});
  final int views;
  final int contactClicks;
  final int requests;

  factory ListingStats.fromJson(Map<String, dynamic> j) => ListingStats(
        views: (j['views'] as num? ?? 0).toInt(),
        contactClicks: (j['contactClicks'] as num? ?? 0).toInt(),
        requests: (j['requests'] as num? ?? 0).toInt(),
      );
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Annonce vue par son vendeur (`SellerListingDto`).
class SellerListing {
  const SellerListing({
    required this.id,
    required this.status,
    this.closedReason,
    required this.title,
    required this.description,
    required this.propertyType,
    required this.rooms,
    this.bedrooms,
    this.bathrooms,
    this.surfaceM2,
    required this.amenities,
    required this.city,
    required this.district,
    this.address,
    this.location,
    required this.offers,
    this.publishedUntil,
    this.publishedAt,
    required this.photos,
    required this.stats,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ListingStatus status;
  final ClosedReason? closedReason;
  final String title;
  final String description;
  final String propertyType;
  final int rooms;
  final int? bedrooms;
  final int? bathrooms;
  final int? surfaceM2;
  final List<String> amenities;
  final String city;
  final String district;
  final String? address;
  final LatLng? location;
  final Offers offers;

  /// Dernier jour de publication (inclus) ; `null` = permanente.
  final DateTime? publishedUntil;
  final DateTime? publishedAt;
  final List<Photo> photos;
  final ListingStats stats;
  final DateTime createdAt;
  final DateTime updatedAt;

  String? get coverThumbUrl => photos.isEmpty ? null : photos.first.thumbUrl;

  factory SellerListing.fromJson(Map<String, dynamic> j) {
    final loc = j['location'];
    return SellerListing(
      id: j['id'] as String,
      status: ListingStatus.parse(j['status']),
      closedReason: ClosedReason.parse(j['closedReason']),
      title: j['title'] as String,
      description: j['description'] as String? ?? '',
      propertyType: j['propertyType'] as String,
      rooms: (j['rooms'] as num? ?? 0).toInt(),
      bedrooms: (j['bedrooms'] as num?)?.toInt(),
      bathrooms: (j['bathrooms'] as num?)?.toInt(),
      surfaceM2: (j['surfaceM2'] as num?)?.toInt(),
      amenities: [for (final a in (j['amenities'] as List? ?? const [])) a.toString()],
      city: j['city'] as String,
      district: j['district'] as String,
      address: j['address'] as String?,
      location: loc is Map ? LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()) : null,
      offers: j['offers'] is Map ? Offers.fromJson((j['offers'] as Map).cast<String, dynamic>()) : const Offers(),
      publishedUntil: _date(j['publishedUntil']),
      publishedAt: _date(j['publishedAt']),
      photos: [for (final p in (j['photos'] as List? ?? const [])) Photo.fromJson((p as Map).cast<String, dynamic>())],
      stats: j['stats'] is Map ? ListingStats.fromJson((j['stats'] as Map).cast<String, dynamic>()) : const ListingStats(views: 0, contactClicks: 0, requests: 0),
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}
