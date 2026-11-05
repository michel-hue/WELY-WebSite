import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'models.dart';

/// Consultation publique des annonces. Les méthodes lèvent [ApiError].
class ListingsRepository {
  ListingsRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ApiError.of(e);
    }
  }

  Future<Page<ListingCard>> search(
    SearchFilters filters, {
    LatLng? near,
    double? radiusKm,
    String? cursor,
  }) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/listings', queryParameters: {
          ...filters.toQuery(),
          if (near != null) ...{'lat': '${near.latitude}', 'lng': '${near.longitude}'},
          'radiusKm': ?radiusKm?.toString(),
          'cursor': ?cursor,
        });
        final body = res.data!;
        return Page(
          data: [for (final j in body['data'] as List) ListingCard.fromJson((j as Map).cast<String, dynamic>())],
          nextCursor: body['nextCursor'] as String?,
        );
      });

  Future<ListingDetail> detail(String id) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/listings/$id');
        return ListingDetail.fromJson(res.data!);
      });

  /// [channel] : `whatsapp` ou `call`.
  Future<void> recordContactClick(String id, {String channel = 'whatsapp'}) =>
      _guard(() => _dio.post<void>('/listings/$id/contact-clicks', data: {'channel': channel}));

  Future<void> report(String id, String reason, {String? comment}) => _guard(() => _dio.post<void>(
        '/listings/$id/reports',
        data: {'reason': reason, if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim()},
      ));

  Future<List<LocationCity>> locations() => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/locations');
        return [
          for (final c in res.data!['cities'] as List)
            LocationCity(
              city: (c as Map)['city'] as String,
              districts: [for (final d in c['districts'] as List) d as String],
            ),
        ];
      });
}

final listingsRepositoryProvider = Provider<ListingsRepository>((ref) => ListingsRepository(ref.read(dioProvider)));
