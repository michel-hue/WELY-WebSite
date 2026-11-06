import 'dart:typed_data';

import 'package:dio/dio.dart' show ProgressCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/features/listings/models.dart';
import 'package:mobile_project/features/seller/seller_listings_repository.dart';

Photo samplePhoto(String id, {int position = 0}) => Photo(
      id: id,
      thumbUrl: 'https://img.test/$id-thumb.jpg',
      largeUrl: 'https://img.test/$id.jpg',
      width: 1200,
      height: 800,
      position: position,
    );

SellerListing editorListing({
  String id = 'l1',
  ListingStatus status = ListingStatus.draft,
  String title = 'Villa avec piscine',
  Offers offers = const Offers(),
  List<Photo> photos = const [],
  ListingStats stats = const ListingStats(views: 0, contactClicks: 0, requests: 0),
  DateTime? publishedUntil,
  String? address,
}) =>
    SellerListing(
      id: id,
      status: status,
      title: title,
      description: 'Belle villa.',
      propertyType: 'villa',
      rooms: 4,
      bedrooms: 3,
      amenities: const ['pool'],
      city: 'Abidjan',
      district: 'Riviera 3',
      address: address,
      location: const LatLng(5.36, -3.98),
      offers: offers,
      publishedUntil: publishedUntil,
      photos: photos,
      stats: stats,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 2),
    );

XFile fakeImage(String name) => XFile.fromData(Uint8List(4), name: name, path: name, mimeType: 'image/jpeg');

/// Faux dépôt pour l'éditeur et l'écran de gestion : appels enregistrés,
/// erreurs programmables par méthode.
class FakeEditorRepository extends Fake implements SellerListingsRepository {
  FakeEditorRepository({SellerListing? existing}) : current = existing;

  SellerListing? current;
  final created = <Map<String, dynamic>>[];
  final updates = <(String, Map<String, dynamic>)>[];
  final calls = <String>[];

  /// Noms de fichiers dont l'envoi échoue (une fois chacun).
  final failUploads = <String>{};
  final uploaded = <String>[];
  final reorders = <List<String>>[];

  /// Erreur levée par la prochaine action (publish, extend, reactivate…).
  Object? actionError;
  Object? loadError;
  var _photoSeq = 0;

  SellerListing _require() => current ?? (throw StateError('no listing'));

  Object? _takeError() {
    final e = actionError;
    actionError = null;
    return e;
  }

  @override
  Future<SellerListing> one(String id) async {
    calls.add('one:$id');
    if (loadError != null) throw loadError!;
    return _require();
  }

  @override
  Future<SellerListing> create(Map<String, dynamic> body) async {
    created.add(body);
    final e = _takeError();
    if (e != null) throw e;
    current = editorListing(id: 'new1', title: body['title'] as String);
    return current!;
  }

  @override
  Future<SellerListing> update(String id, Map<String, dynamic> patch) async {
    updates.add((id, patch));
    final e = _takeError();
    if (e != null) throw e;
    return _require();
  }

  SellerListing _withStatus(ListingStatus s, {DateTime? until}) {
    final l = _require();
    current = editorListing(
      id: l.id,
      status: s,
      title: l.title,
      offers: l.offers,
      photos: l.photos,
      stats: l.stats,
      publishedUntil: until,
    );
    return current!;
  }

  @override
  Future<SellerListing> publish(String id, {String? until}) async {
    calls.add('publish:$id:${until ?? 'permanent'}');
    final e = _takeError();
    if (e != null) throw e;
    return _withStatus(ListingStatus.online);
  }

  @override
  Future<SellerListing> extend(String id, {String? until}) async {
    calls.add('extend:$id:${until ?? 'permanent'}');
    final e = _takeError();
    if (e != null) throw e;
    return _withStatus(ListingStatus.online);
  }

  @override
  Future<SellerListing> reactivate(String id, {String? until}) async {
    calls.add('reactivate:$id:${until ?? 'permanent'}');
    final e = _takeError();
    if (e != null) throw e;
    return _withStatus(ListingStatus.online);
  }

  @override
  Future<SellerListing> deactivate(String id) async {
    calls.add('deactivate:$id');
    final e = _takeError();
    if (e != null) throw e;
    return _withStatus(ListingStatus.deactivated);
  }

  @override
  Future<void> close(String listingId, ClosedReason reason) async {
    calls.add('close:$listingId:${reason.name}');
    final e = _takeError();
    if (e != null) throw e;
    _withStatus(ListingStatus.closed);
  }

  @override
  Future<void> remove(String id) async {
    calls.add('remove:$id');
    final e = _takeError();
    if (e != null) throw e;
  }

  @override
  Future<List<Photo>> uploadPhotos(String id, List<XFile> files, {ProgressCallback? onProgress}) async {
    final name = files.single.name;
    onProgress?.call(2, 4);
    if (failUploads.remove(name)) throw const ApiError.network();
    uploaded.add(name);
    return [samplePhoto('p${_photoSeq++}')];
  }

  @override
  Future<void> reorderPhotos(String id, List<String> photoIds) async => reorders.add(photoIds);

  @override
  Future<void> deletePhoto(String id, String photoId) async => calls.add('deletePhoto:$photoId');
}
