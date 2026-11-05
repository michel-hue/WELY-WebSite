import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repli quand la position est indisponible : le Plateau, Abidjan.
const abidjan = LatLng(5.3197, -4.0267);

/// Position de l'utilisateur et écran d'explication du premier lancement.
abstract class LocationService {
  /// Position actuelle, ou `null` si refusée, désactivée ou trop lente (6 s).
  /// La demande système n'est faite que si [ask] est vrai.
  Future<LatLng?> current({bool ask = false});

  /// L'écran d'explication a-t-il déjà été montré ?
  Future<bool> explainerSeen();
  Future<void> markExplainerSeen();

  /// Réglages de l'app (position refusée définitivement).
  Future<void> openSettings();
}

const _explainerKey = 'location_explainer_seen';
const locationTimeout = Duration(seconds: 6);

class GeolocatorLocationService implements LocationService {
  @override
  Future<LatLng?> current({bool ask = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        return null;
      }
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: locationTimeout),
        ).timeout(locationTimeout);
        return LatLng(p.latitude, p.longitude);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : LatLng(last.latitude, last.longitude);
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> explainerSeen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_explainerKey) ?? false;
    } catch (_) {
      return true; // stockage indisponible : on ne bloque pas l'accueil
    }
  }

  @override
  Future<void> markExplainerSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_explainerKey, true);
    } catch (_) {}
  }

  @override
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());
