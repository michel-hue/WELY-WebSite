import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../listings/models.dart';
import 'models.dart';

/// Demandes (acheteur et vendeur). Les méthodes lèvent [ApiError].
class RequestsRepository {
  RequestsRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ApiError.of(e);
    }
  }

  Future<ListingRequest> _post(String path, [Map<String, dynamic>? data]) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(path, data: data ?? const <String, dynamic>{});
        return ListingRequest.fromJson(res.data!);
      });

  Future<Page<ListingRequest>> _page(String path, Map<String, String?> query) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(path, queryParameters: {
          for (final e in query.entries)
            if (e.value != null) e.key: e.value,
        });
        final body = res.data!;
        return Page(
          data: [for (final j in body['data'] as List) ListingRequest.fromJson((j as Map).cast<String, dynamic>())],
          nextCursor: body['nextCursor'] as String?,
        );
      });

  /// À la nuit : [checkIn] et [checkOut] obligatoires ; au mois : [moveInDate] facultative.
  Future<ListingRequest> create({
    required String listingId,
    required OfferType offerType,
    DateTime? checkIn,
    DateTime? checkOut,
    DateTime? moveInDate,
    String? message,
    bool wantsVisit = false,
  }) {
    final text = message?.trim();
    return _post('/requests', {
      'listingId': listingId,
      'offerType': offerType.name,
      if (checkIn != null) 'checkIn': isoDay(checkIn),
      if (checkOut != null) 'checkOut': isoDay(checkOut),
      if (moveInDate != null) 'moveInDate': isoDay(moveInDate),
      'wantsVisit': wantsVisit,
      if (text != null && text.isNotEmpty) 'message': text,
    });
  }

  /// Mes demandes (acheteur).
  Future<Page<ListingRequest>> mine({RequestStatus? status, String? cursor}) =>
      _page('/me/requests', {'status': status?.name, 'cursor': cursor});

  /// Demandes reçues sur mes annonces (vendeur), avec le contact de l'acheteur.
  Future<Page<ListingRequest>> received({RequestStatus? status, String? listingId, String? cursor}) =>
      _page('/me/received-requests', {'status': status?.name, 'listingId': listingId, 'cursor': cursor});

  Future<ListingRequest> accept(String id, {String? message}) => _post('/requests/$id/accept', _decision(message));

  Future<ListingRequest> refuse(String id, {String? message}) => _post('/requests/$id/refuse', _decision(message));

  Future<ListingRequest> cancel(String id) => _post('/requests/$id/cancel');

  Map<String, dynamic> _decision(String? message) {
    final text = message?.trim();
    return {if (text != null && text.isNotEmpty) 'message': text};
  }
}

final requestsRepositoryProvider = Provider<RequestsRepository>((ref) => RequestsRepository(ref.read(dioProvider)));
