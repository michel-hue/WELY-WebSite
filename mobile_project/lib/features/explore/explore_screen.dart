import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/tokens.dart';
import '../listings/models.dart' hide Page;
import 'explore_controller.dart';
import 'filters_sheet.dart';
import 'listings_sheet.dart';
import 'location_explainer.dart';
import 'location_service.dart';
import 'map_view.dart';

/// Onglet Explorer (C3) : carte plein écran, recherche flottante, panneau d'annonces.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

const _pillShadow = [BoxShadow(color: Color(0x1413161B), blurRadius: 18, offset: Offset(0, 6))];

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  MapCamera? _camera;
  bool _moved = false;

  @override
  void dispose() {
    _map.dispose();
    _sheet.dispose();
    _search.dispose();
    super.dispose();
  }

  void _moveMap(LatLng to, [double? zoom]) {
    try {
      _map.move(to, zoom ?? _camera?.zoom ?? initialZoom);
    } catch (_) {
      // Carte pas encore affichée : elle s'ouvrira sur le centre initial.
    }
  }

  void _onCamera(MapCamera camera, bool hasGesture) {
    _camera = camera;
    if (hasGesture && !_moved) setState(() => _moved = true);
  }

  void _searchHere() {
    final camera = _camera;
    if (camera == null) return;
    final b = camera.visibleBounds;
    final halfHeight = const Distance().as(LengthUnit.Kilometer, camera.center, LatLng(b.north, camera.center.longitude));
    final halfWidth = const Distance().as(LengthUnit.Kilometer, camera.center, LatLng(camera.center.latitude, b.east));
    setState(() => _moved = false);
    ref.read(exploreControllerProvider.notifier).searchArea(camera.center, math.max(halfHeight, halfWidth));
  }

  void _recenter() {
    final s = ref.read(exploreControllerProvider);
    final target = s.userLocation ?? abidjan;
    _moveMap(target, initialZoom);
    setState(() => _moved = false);
    if (s.center != target) {
      ref.read(exploreControllerProvider.notifier).searchArea(target, defaultRadiusKm);
    }
  }

  Future<void> _enableLocation() async {
    final ctrl = ref.read(exploreControllerProvider.notifier);
    if (await ctrl.enableLocation() || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Position indisponible. Vérifiez les autorisations.'),
      action: SnackBarAction(label: 'Réglages', onPressed: ctrl.openSettings),
    ));
  }

  Future<void> _openFilters() async {
    final current = ref.read(exploreControllerProvider).filters;
    final next = await showFiltersSheet(context, current);
    if (next != null && mounted) ref.read(exploreControllerProvider.notifier).setFilters(next);
  }

  void _focus(ListingCard card) => ref.read(exploreControllerProvider.notifier).focus(card.id);

  void _open(ListingCard card) => context.push('/listing/${card.id}');

  @override
  Widget build(BuildContext context) {
    // Position trouvée ou zone changée : la carte suit le centre de recherche.
    ref.listen(exploreControllerProvider.select((s) => s.center), (prev, next) {
      if (prev != next) _moveMap(next);
    });
    final state = ref.watch(exploreControllerProvider);
    final ctrl = ref.read(exploreControllerProvider.notifier);
    final top = MediaQuery.paddingOf(context).top;
    final showLocationLink = !state.locating && state.userLocation == null && !state.showExplainer;

    return LayoutBuilder(builder: (context, box) {
      // Plein écran, le panneau s'arrête sous la barre de recherche.
      final maxSheet = math.min(sheetMax, 1 - (top + 68) / box.maxHeight).clamp(sheetMid + 0.05, sheetMax);
      return Stack(fit: StackFit.expand, children: [
        ExploreMap(
          controller: _map,
          initialCenter: state.center,
          items: state.items,
          userLocation: state.userLocation,
          onListingTap: _focus,
          onCameraMoved: _onCamera,
        ),
        Positioned(
          top: top + 66,
          left: 14,
          right: 14,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                if (_moved) _Chip(label: 'Rechercher dans cette zone', icon: Icons.refresh, onTap: _searchHere),
                if (showLocationLink) _Chip(label: 'Activer la position', icon: Icons.near_me_outlined, onTap: _enableLocation),
              ]),
            ),
            _RoundButton(icon: Icons.my_location, tooltip: 'Recentrer', onTap: _recenter),
          ]),
        ),
        ListingsSheet(controller: _sheet, maxSize: maxSheet.toDouble(), onOpen: _open),
        Positioned(
          top: top + 10,
          left: 14,
          right: 14,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _SearchPill(
              controller: _search,
              activeFilters: state.filters.activeCount,
              onSubmit: ctrl.setQuery,
              onFilters: _openFilters,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 3, right: 12),
              child: Text(mapAttribution, style: TextStyle(fontSize: 9, color: WellyColors.muted)),
            ),
          ]),
        ),
        if (state.showExplainer)
          LocationExplainer(
            onEnable: () => ctrl.answerExplainer(enable: true),
            onLater: () => ctrl.answerExplainer(enable: false),
          ),
      ]);
    });
  }
}

class _SearchPill extends StatefulWidget {
  const _SearchPill({
    required this.controller,
    required this.activeFilters,
    required this.onSubmit,
    required this.onFilters,
  });

  final TextEditingController controller;
  final int activeFilters;
  final ValueChanged<String> onSubmit;
  final VoidCallback onFilters;

  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill> {
  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.only(left: 16, right: 6),
        decoration: BoxDecoration(
          color: WellyColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: WellyColors.line),
          boxShadow: _pillShadow,
        ),
        child: Row(children: [
          const Icon(Icons.search, size: 20, color: WellyColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('search-field'),
              controller: widget.controller,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmit,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: WellyColors.ink),
              decoration: const InputDecoration(
                hintText: 'Quartier, ville, type de bien…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Effacer',
              icon: const Icon(Icons.close, size: 18, color: WellyColors.muted),
              onPressed: () {
                widget.controller.clear();
                setState(() {});
                widget.onSubmit('');
              },
            ),
          _FilterButton(count: widget.activeFilters, onTap: widget.onFilters),
        ]),
      );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Filtres',
        child: GestureDetector(
          key: const Key('filters-button'),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: WellyColors.ink, shape: BoxShape.circle),
                child: const Icon(Icons.tune, size: 18, color: WellyColors.ivoire),
              ),
              if (count > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: WellyColors.laiton,
                      shape: BoxShape.circle,
                      border: Border.all(color: WellyColors.surface, width: 1.5),
                    ),
                    child: Text('$count',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: WellyColors.ink)),
                  ),
                ),
            ]),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: WellyColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: WellyColors.line)),
        elevation: 0,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: WellyColors.laitonText),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: WellyColors.ink)),
            ]),
          ),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: WellyColors.surface,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: const Color(0x3313161B),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 19, color: WellyColors.ink)),
          ),
        ),
      );
}
