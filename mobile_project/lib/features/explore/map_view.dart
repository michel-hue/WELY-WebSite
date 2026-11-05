import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/tokens.dart';
import '../listings/models.dart' hide Page;
import 'cluster.dart';

/// Surchargé en test pour ne charger aucune tuile réseau.
final tileProviderOverrideProvider = Provider<TileProvider?>((ref) => null);

const cartoPositronUrl = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
const mapAttribution = '© OpenStreetMap © CARTO';
const initialZoom = 13.0;
const _maxZoom = 18.0;
const _userBlue = Color(0xFF3D7BF0);

/// Carte claire plein écran : pastilles laiton regroupées et point bleu.
class ExploreMap extends ConsumerWidget {
  const ExploreMap({
    super.key,
    required this.controller,
    required this.initialCenter,
    required this.items,
    this.userLocation,
    required this.onListingTap,
    required this.onCameraMoved,
  });

  final MapController controller;
  final LatLng initialCenter;
  final List<ListingCard> items;
  final LatLng? userLocation;
  final ValueChanged<ListingCard> onListingTap;
  final void Function(MapCamera camera, bool hasGesture) onCameraMoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(tileProviderOverrideProvider);
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 5,
        maxZoom: _maxZoom,
        backgroundColor: WellyColors.ivoire,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onPositionChanged: onCameraMoved,
      ),
      children: [
        TileLayer(
          urlTemplate: cartoPositronUrl,
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: RetinaMode.isHighDensity(context),
          maxNativeZoom: 19,
          tileProvider: tiles,
        ),
        _ClusterLayer(items: items, onListingTap: onListingTap),
        if (userLocation != null)
          MarkerLayer(markers: [
            Marker(point: userLocation!, width: 40, height: 40, child: const _UserDot()),
          ]),
      ],
    );
  }
}

class _ClusterLayer extends StatelessWidget {
  const _ClusterLayer({required this.items, required this.onListingTap});

  final List<ListingCard> items;
  final ValueChanged<ListingCard> onListingTap;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final clusters = clusterPoints(items, zoom: camera.zoom.roundToDouble());
    return MarkerLayer(markers: [
      for (final c in clusters)
        if (c.items.length == 1)
          Marker(
            point: c.center,
            width: 36,
            height: 36,
            child: GestureDetector(
              key: ValueKey('dot-${c.items.single.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onListingTap(c.items.single),
              child: const Center(child: _Dot()),
            ),
          )
        else
          Marker(
            point: c.center,
            width: 44,
            height: 44,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Toucher un groupe zoome ; au zoom maximum, on montre la première annonce.
                if (camera.zoom >= _maxZoom - 0.5) {
                  onListingTap(c.items.first);
                } else {
                  MapController.of(context).move(c.center, math.min(camera.zoom + 2, _maxZoom));
                }
              },
              child: _Cluster(count: c.items.length),
            ),
          ),
    ]);
  }
}

const _softShadow = [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))];

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: WellyColors.laiton,
          shape: BoxShape.circle,
          border: Border.all(color: WellyColors.surface, width: 2.5),
          boxShadow: _softShadow,
        ),
      );
}

class _Cluster extends StatelessWidget {
  const _Cluster({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: WellyColors.laiton.withValues(alpha: 0.25), shape: BoxShape.circle),
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: WellyColors.laiton, shape: BoxShape.circle),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: WellyColors.ink),
            ),
          ),
        ),
      );
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: _userBlue.withValues(alpha: 0.16), shape: BoxShape.circle),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _userBlue,
              shape: BoxShape.circle,
              border: Border.all(color: WellyColors.surface, width: 3),
              boxShadow: _softShadow,
            ),
          ),
        ),
      );
}
