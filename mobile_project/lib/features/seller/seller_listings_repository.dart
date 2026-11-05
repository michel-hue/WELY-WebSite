import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';

/// Motif de clôture (`POST /listings/:id/close`).
enum ClosedReason { rented, sold }

/// Annonces du vendeur. Les méthodes lèvent [ApiError].
/// Amorcé par la Task 8 (clôture après acceptation) ; la Task 10 l'étend.
class SellerListingsRepository {
  SellerListingsRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ApiError.of(e);
    }
  }

  /// Marque l'annonce comme louée ou vendue (elle sort des recherches).
  Future<void> close(String listingId, ClosedReason reason) =>
      _guard(() => _dio.post<void>('/listings/$listingId/close', data: {'reason': reason.name}));
}

final sellerListingsRepositoryProvider =
    Provider<SellerListingsRepository>((ref) => SellerListingsRepository(ref.read(dioProvider)));
