import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/listings/models.dart';
import 'package:mobile_project/features/requests/models.dart';
import 'package:mobile_project/features/requests/requests_repository.dart';
import 'package:mobile_project/features/seller/seller_listings_repository.dart';

ListingRequest sampleRequest({
  String id = 'r1',
  RequestStatus status = RequestStatus.pending,
  OfferType offerType = OfferType.monthly,
  RefusalReason? refusalReason,
  String? sellerMessage,
  String listingId = 'l1',
  String title = 'Villa avec piscine',
  bool received = false,
}) =>
    ListingRequest(
      id: id,
      status: status,
      refusalReason: refusalReason,
      sellerMessage: sellerMessage,
      offerType: offerType,
      checkIn: offerType == OfferType.nightly ? DateTime(2026, 12, 10) : null,
      checkOut: offerType == OfferType.nightly ? DateTime(2026, 12, 13) : null,
      moveInDate: offerType == OfferType.monthly ? DateTime(2026, 12, 1) : null,
      wantsVisit: false,
      message: 'Bonjour, toujours disponible ?',
      createdAt: DateTime(2026, 11, 5),
      listing: ListingCard(
        id: listingId,
        title: title,
        propertyType: 'villa',
        city: 'Abidjan',
        district: 'Riviera 3',
        offers: const Offers(monthly: MonthlyOffer(rent: 650000)),
        rooms: 4,
      ),
      buyer: received ? const RequestBuyer(id: 'b1', name: 'Awa Koné', phone: '+2250707070707') : null,
      seller: received
          ? null
          : const RequestSeller(id: 's1', name: 'Koffi Adjoumani', phone: '+2250700000001', whatsappPhone: '+2250700000002'),
    );

ListingRequest withStatus(ListingRequest r, RequestStatus status) => ListingRequest(
      id: r.id,
      status: status,
      refusalReason: r.refusalReason,
      sellerMessage: r.sellerMessage,
      offerType: r.offerType,
      checkIn: r.checkIn,
      checkOut: r.checkOut,
      moveInDate: r.moveInDate,
      wantsVisit: r.wantsVisit,
      message: r.message,
      createdAt: r.createdAt,
      listing: r.listing,
      buyer: r.buyer,
      seller: r.seller,
    );

/// Faux dépôt de demandes : listes programmables, appels enregistrés.
class FakeRequestsRepository extends Fake implements RequestsRepository {
  FakeRequestsRepository({this.sent = const [], this.receivedList = const [], this.error});
  List<ListingRequest> sent;
  List<ListingRequest> receivedList;
  Object? error;
  Object? actionError;
  int mineCalls = 0;
  int receivedCalls = 0;
  final calls = <String>[];

  ListingRequest _find(String id) => [...sent, ...receivedList].firstWhere((r) => r.id == id);

  /// Comme le serveur : le nouvel état est conservé pour les rechargements.
  ListingRequest _set(String id, RequestStatus status) {
    final updated = withStatus(_find(id), status);
    sent = [for (final r in sent) r.id == id ? updated : r];
    receivedList = [for (final r in receivedList) r.id == id ? updated : r];
    return updated;
  }

  @override
  Future<Page<ListingRequest>> mine({RequestStatus? status, String? cursor}) async {
    mineCalls++;
    if (error != null) throw error!;
    return Page(data: sent);
  }

  @override
  Future<Page<ListingRequest>> received({RequestStatus? status, String? listingId, String? cursor}) async {
    receivedCalls++;
    if (error != null) throw error!;
    return Page(data: receivedList);
  }

  @override
  Future<ListingRequest> cancel(String id) async {
    calls.add('cancel:$id');
    if (actionError != null) throw actionError!;
    return _set(id, RequestStatus.cancelled);
  }

  @override
  Future<ListingRequest> accept(String id, {String? message}) async {
    calls.add('accept:$id');
    if (actionError != null) throw actionError!;
    return _set(id, RequestStatus.accepted);
  }

  @override
  Future<ListingRequest> refuse(String id, {String? message}) async {
    calls.add('refuse:$id:${message ?? ''}');
    if (actionError != null) throw actionError!;
    return _set(id, RequestStatus.refused);
  }
}

SellerListing sampleSellerListing({
  String id = 'l1',
  ListingStatus status = ListingStatus.online,
  String title = 'Villa avec piscine',
  int views = 0,
  int requests = 0,
  ClosedReason? closedReason,
  DateTime? publishedUntil,
}) =>
    SellerListing(
      id: id,
      status: status,
      closedReason: closedReason,
      title: title,
      description: '',
      propertyType: 'villa',
      rooms: 4,
      amenities: const [],
      city: 'Abidjan',
      district: 'Riviera 3',
      offers: const Offers(monthly: MonthlyOffer(rent: 650000)),
      publishedUntil: publishedUntil,
      photos: const [],
      stats: ListingStats(views: views, contactClicks: 0, requests: requests),
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 2),
    );

/// Faux dépôt des annonces du vendeur : liste programmable, appels enregistrés.
class FakeSellerListingsRepository extends Fake implements SellerListingsRepository {
  FakeSellerListingsRepository({this.listings = const [], this.error});
  List<SellerListing> listings;
  Object? error;
  Object? actionError;
  int mineCalls = 0;
  final closed = <(String, ClosedReason)>[];
  final calls = <String>[];

  @override
  Future<void> close(String listingId, ClosedReason reason) async => closed.add((listingId, reason));

  @override
  Future<Page<SellerListing>> mine({ListingStatus? status, String? cursor, int? limit}) async {
    mineCalls++;
    if (error != null) throw error!;
    return Page(data: listings);
  }

  @override
  Future<SellerListing> reactivate(String id, {String? until}) async {
    calls.add('reactivate:$id:${until ?? 'permanent'}');
    if (actionError != null) throw actionError!;
    final l = listings.firstWhere((x) => x.id == id);
    final updated = sampleSellerListing(id: l.id, title: l.title, status: ListingStatus.online);
    listings = [for (final x in listings) x.id == id ? updated : x];
    return updated;
  }
}
