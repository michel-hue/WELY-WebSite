import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../listings/models.dart';

/// Groupe de pastilles affiché à un même endroit de la carte.
class MapCluster {
  const MapCluster({required this.center, required this.items});
  final LatLng center;
  final List<ListingCard> items;
}

/// Taille d'une case de la grille, en pixels logiques.
const clusterCellPx = 60.0;

/// Regroupement par grille (Web Mercator, tuiles de 256 px) : les annonces
/// tombant dans la même case de [clusterCellPx] au [zoom] donné forment un
/// groupe centré sur la moyenne de leurs positions. Les cartes sans
/// `approxLocation` sont ignorées.
List<MapCluster> clusterPoints(List<ListingCard> cards, {required double zoom}) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final cells = <(int, int), List<ListingCard>>{};
  for (final c in cards) {
    final p = c.approxLocation;
    if (p == null) continue;
    final x = (p.longitude + 180) / 360 * scale;
    final lat = p.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * scale;
    final key = ((x / clusterCellPx).floor(), (y / clusterCellPx).floor());
    (cells[key] ??= []).add(c);
  }
  return [
    for (final items in cells.values)
      MapCluster(
        center: LatLng(
          items.fold(0.0, (s, c) => s + c.approxLocation!.latitude) / items.length,
          items.fold(0.0, (s, c) => s + c.approxLocation!.longitude) / items.length,
        ),
        items: items,
      ),
  ];
}
