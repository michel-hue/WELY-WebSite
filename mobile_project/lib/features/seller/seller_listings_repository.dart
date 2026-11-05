import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../listings/models.dart';
import 'models.dart';

export 'models.dart' show ClosedReason, ListingStatus, ListingStats, SellerListing;

/// Annonces du vendeur. Les méthodes lèvent [ApiError].
class SellerListingsRepository {
  SellerListingsRepository(this._dio);
  final Dio _dio;

  /// L'API accepte 10 photos par envoi.
  static const photosPerUpload = 10;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ApiError.of(e);
    }
  }

  Future<SellerListing> _listing(Future<Response<Map<String, dynamic>>> Function() call) =>
      _guard(() async => SellerListing.fromJson((await call()).data!));

  Map<String, dynamic> _until(String? until) => {'until': ?until};

  /// Mes annonces, plus récentes d'abord.
  Future<Page<SellerListing>> mine({ListingStatus? status, String? cursor, int? limit}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/me/listings', queryParameters: {
          'status': ?status?.name,
          'cursor': ?cursor,
          'limit': ?limit,
        });
        final body = res.data!;
        return Page(
          data: [for (final j in body['data'] as List) SellerListing.fromJson((j as Map).cast<String, dynamic>())],
          nextCursor: body['nextCursor'] as String?,
        );
      });

  /// Une de mes annonces, avec ses compteurs.
  Future<SellerListing> one(String id) => _listing(() => _dio.get('/me/listings/$id'));

  /// Crée un brouillon (`CreateListingDto`).
  Future<SellerListing> create(Map<String, dynamic> body) => _listing(() => _dio.post('/listings', data: body));

  /// Modifie une annonce ; une offre à `null` est retirée.
  Future<SellerListing> update(String id, Map<String, dynamic> patch) =>
      _listing(() => _dio.patch('/listings/$id', data: patch));

  /// [until] : dernier jour inclus `AAAA-MM-JJ` ; `null` = permanente.
  Future<SellerListing> publish(String id, {String? until}) =>
      _listing(() => _dio.post('/listings/$id/publish', data: _until(until)));

  Future<SellerListing> extend(String id, {String? until}) =>
      _listing(() => _dio.post('/listings/$id/extend', data: _until(until)));

  Future<SellerListing> reactivate(String id, {String? until}) =>
      _listing(() => _dio.post('/listings/$id/reactivate', data: _until(until)));

  Future<SellerListing> deactivate(String id) =>
      _listing(() => _dio.post('/listings/$id/deactivate', data: const <String, dynamic>{}));

  /// Marque l'annonce comme louée ou vendue (elle sort des recherches).
  Future<void> close(String listingId, ClosedReason reason) =>
      _guard(() => _dio.post<void>('/listings/$listingId/close', data: {'reason': reason.name}));

  Future<void> remove(String id) => _guard(() => _dio.delete<void>('/listings/$id'));

  /// Envoie les photos (par lots de [photosPerUpload]) ; renvoie les photos créées.
  Future<List<Photo>> uploadPhotos(String id, List<XFile> files) => _guard(() async {
        final created = <Photo>[];
        for (var i = 0; i < files.length; i += photosPerUpload) {
          final batch = files.sublist(i, (i + photosPerUpload).clamp(0, files.length));
          final form = FormData();
          for (final f in batch) {
            form.files.add(MapEntry(
              'photos',
              MultipartFile.fromBytes(await f.readAsBytes(), filename: f.name, contentType: DioMediaType.parse(_mimeOf(f))),
            ));
          }
          final res = await _dio.post<List<dynamic>>('/listings/$id/photos', data: form);
          created.addAll([for (final j in res.data ?? const []) Photo.fromJson((j as Map).cast<String, dynamic>())]);
        }
        return created;
      });

  /// La première photo devient la couverture.
  Future<void> reorderPhotos(String id, List<String> photoIds) =>
      _guard(() => _dio.put<void>('/listings/$id/photos/order', data: {'photoIds': photoIds}));

  Future<void> deletePhoto(String id, String photoId) => _guard(() => _dio.delete<void>('/listings/$id/photos/$photoId'));

  static String _mimeOf(XFile f) {
    final known = f.mimeType;
    if (known != null && known.startsWith('image/')) return known;
    final name = f.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

final sellerListingsRepositoryProvider =
    Provider<SellerListingsRepository>((ref) => SellerListingsRepository(ref.read(dioProvider)));
