import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/session/session_controller.dart';
import '../listings/models.dart';
import 'models.dart';
import 'requests_repository.dart';

class RequestsState {
  const RequestsState({this.items = const [], this.nextCursor, this.loadingMore = false, this.moreError});

  final List<ListingRequest> items;
  final String? nextCursor;
  final bool loadingMore;

  /// Échec du chargement de la page suivante (la liste reste affichée).
  final ApiError? moreError;

  RequestsState copyWith({List<ListingRequest>? items, String? nextCursor, bool? loadingMore, ApiError? moreError}) =>
      RequestsState(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        loadingMore: loadingMore ?? this.loadingMore,
        moreError: moreError,
      );
}

/// Liste paginée de demandes ; vide sans session, rechargée quand
/// l'utilisateur change (connexion, session expirée).
abstract class RequestsController extends AsyncNotifier<RequestsState> {
  RequestsRepository get repo => ref.read(requestsRepositoryProvider);

  Future<Page<ListingRequest>> fetch(String? cursor);

  @override
  Future<RequestsState> build() async {
    String? userId;
    try {
      userId = await ref.watch(sessionControllerProvider.selectAsync((me) => me?.id));
    } catch (_) {
      userId = null;
    }
    if (userId == null) return const RequestsState();
    final page = await fetch(null);
    return RequestsState(items: page.data, nextCursor: page.nextCursor);
  }

  /// Rechargement (tirer pour rafraîchir, retour sur l'onglet). Ne lève pas :
  /// une erreur reste dans l'état.
  Future<void> reload() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {}
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.nextCursor == null || s.loadingMore || state.isLoading) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await fetch(s.nextCursor);
      final now = state.value ?? s;
      state = AsyncData(RequestsState(items: [...now.items, ...page.data], nextCursor: page.nextCursor));
    } catch (e) {
      final now = state.value ?? s;
      state = AsyncData(now.copyWith(loadingMore: false, moreError: ApiError.of(e)));
    }
  }

  ListingRequest _replace(ListingRequest r) {
    final s = state.value;
    if (s != null) {
      state = AsyncData(s.copyWith(items: [for (final x in s.items) x.id == r.id ? r : x]));
    }
    return r;
  }

  /// Les actions lèvent [ApiError] ; en cas de succès la demande est remplacée dans la liste.
  Future<ListingRequest> cancel(String id) async => _replace(await repo.cancel(id));

  Future<ListingRequest> accept(String id) async => _replace(await repo.accept(id));

  Future<ListingRequest> refuse(String id, {String? message}) async => _replace(await repo.refuse(id, message: message));
}

/// Demandes envoyées (acheteur).
class SentRequestsController extends RequestsController {
  @override
  Future<Page<ListingRequest>> fetch(String? cursor) => repo.mine(cursor: cursor);
}

/// Demandes reçues sur mes annonces (vendeur).
class ReceivedRequestsController extends RequestsController {
  @override
  Future<Page<ListingRequest>> fetch(String? cursor) => repo.received(cursor: cursor);
}

final sentRequestsProvider = AsyncNotifierProvider<SentRequestsController, RequestsState>(
  SentRequestsController.new,
  retry: (_, _) => null,
);

final receivedRequestsProvider = AsyncNotifierProvider<ReceivedRequestsController, RequestsState>(
  ReceivedRequestsController.new,
  retry: (_, _) => null,
);
