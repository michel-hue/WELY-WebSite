import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_error.dart';
import '../listings/listings_repository.dart';
import '../listings/models.dart';
import 'location_service.dart';

/// Rayon de la recherche initiale (autour de l'utilisateur ou d'Abidjan).
const defaultRadiusKm = 20.0;
const maxRadiusKm = 50.0;

const _unset = Object();

class ExploreState {
  const ExploreState({
    this.filters = const SearchFilters(),
    this.center = abidjan,
    this.radiusKm = defaultRadiusKm,
    this.userLocation,
    this.locating = true,
    this.showExplainer = false,
    this.items = const [],
    this.nextCursor,
    this.loading = true,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.error,
    this.focusedId,
  });

  final SearchFilters filters;

  /// Centre de la recherche en cours.
  final LatLng center;
  final double radiusKm;
  final LatLng? userLocation;
  final bool locating;
  final bool showExplainer;
  final List<ListingCard> items;
  final String? nextCursor;
  final bool loading;
  final bool loadingMore;
  final bool loadMoreFailed;
  final ApiError? error;

  /// Annonce dont la pastille a été touchée : affichée en tête du panneau.
  final String? focusedId;

  /// [items] avec l'annonce touchée en premier.
  List<ListingCard> get ordered {
    final i = items.indexWhere((c) => c.id == focusedId);
    if (i <= 0) return items;
    return [items[i], ...items.take(i), ...items.skip(i + 1)];
  }

  ExploreState copyWith({
    SearchFilters? filters,
    LatLng? center,
    double? radiusKm,
    Object? userLocation = _unset,
    bool? locating,
    bool? showExplainer,
    List<ListingCard>? items,
    Object? nextCursor = _unset,
    bool? loading,
    bool? loadingMore,
    bool? loadMoreFailed,
    Object? error = _unset,
    Object? focusedId = _unset,
  }) =>
      ExploreState(
        filters: filters ?? this.filters,
        center: center ?? this.center,
        radiusKm: radiusKm ?? this.radiusKm,
        userLocation: identical(userLocation, _unset) ? this.userLocation : userLocation as LatLng?,
        locating: locating ?? this.locating,
        showExplainer: showExplainer ?? this.showExplainer,
        items: items ?? this.items,
        nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
        error: identical(error, _unset) ? this.error : error as ApiError?,
        focusedId: identical(focusedId, _unset) ? this.focusedId : focusedId as String?,
      );
}

class ExploreController extends Notifier<ExploreState> {
  /// Numéro de la dernière recherche : les réponses plus anciennes sont ignorées.
  int _generation = 0;

  @override
  ExploreState build() {
    Future.microtask(_start);
    return const ExploreState();
  }

  LocationService get _location => ref.read(locationServiceProvider);

  Future<void> _start() async {
    if (!ref.mounted) return;
    if (!await _location.explainerSeen()) {
      // Premier lancement : on explique avant la demande système, et on
      // montre déjà les logements autour d'Abidjan.
      if (!ref.mounted) return;
      state = state.copyWith(showExplainer: true, locating: false);
      await _search();
      return;
    }
    final here = await _location.current();
    if (!ref.mounted) return;
    state = state.copyWith(locating: false, userLocation: here, center: here ?? abidjan);
    await _search();
  }

  /// Réponse à l'écran d'explication.
  Future<void> answerExplainer({required bool enable}) async {
    state = state.copyWith(showExplainer: false);
    await _location.markExplainerSeen();
    if (enable) await enableLocation();
  }

  /// Demande la position ; renvoie `false` si elle reste indisponible.
  Future<bool> enableLocation() async {
    state = state.copyWith(locating: true);
    final here = await _location.current(ask: true);
    if (!ref.mounted) return false;
    state = state.copyWith(locating: false, userLocation: here ?? state.userLocation);
    if (here == null) return false;
    state = state.copyWith(center: here, radiusKm: defaultRadiusKm);
    await _search();
    return true;
  }

  Future<void> openSettings() => _location.openSettings();

  Future<void> setQuery(String q) {
    final text = q.trim();
    state = state.copyWith(filters: state.filters.copyWith(q: text.isEmpty ? null : text));
    return _search();
  }

  Future<void> setFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters);
    return _search();
  }

  /// « Rechercher dans cette zone ».
  Future<void> searchArea(LatLng center, double radiusKm) {
    state = state.copyWith(center: center, radiusKm: radiusKm.clamp(0.5, maxRadiusKm).toDouble());
    return _search();
  }

  Future<void> retry() => _search();

  void focus(String? id) => state = state.copyWith(focusedId: id);

  /// Retire une annonce des résultats (ex. après l'avoir signalée).
  void removeListing(String id) => state = state.copyWith(
        items: [for (final c in state.items) if (c.id != id) c],
        focusedId: state.focusedId == id ? null : state.focusedId,
      );

  Future<void> _search() async {
    final gen = ++_generation;
    state = state.copyWith(loading: true, error: null, loadMoreFailed: false, loadingMore: false);
    try {
      final page = await ref
          .read(listingsRepositoryProvider)
          .search(state.filters, near: state.center, radiusKm: state.radiusKm);
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loading: false, items: page.data, nextCursor: page.nextCursor, focusedId: null);
    } catch (e) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loading: false, error: ApiError.of(e), items: const [], nextCursor: null);
    }
  }

  /// Page suivante ; après un échec, n'est relancée que par [retryMore].
  Future<void> loadMore() async {
    final s = state;
    if (s.nextCursor == null || s.loading || s.loadingMore || s.loadMoreFailed) return;
    final gen = _generation;
    state = s.copyWith(loadingMore: true);
    try {
      final page = await ref
          .read(listingsRepositoryProvider)
          .search(s.filters, near: s.center, radiusKm: s.radiusKm, cursor: s.nextCursor);
      if (!ref.mounted || gen != _generation) return;
      final known = {for (final c in state.items) c.id};
      state = state.copyWith(
        loadingMore: false,
        items: [...state.items, ...page.data.where((c) => !known.contains(c.id))],
        nextCursor: page.nextCursor,
      );
    } catch (_) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loadingMore: false, loadMoreFailed: true);
    }
  }

  Future<void> retryMore() {
    state = state.copyWith(loadMoreFailed: false);
    return loadMore();
  }
}

final exploreControllerProvider = NotifierProvider<ExploreController, ExploreState>(ExploreController.new);
