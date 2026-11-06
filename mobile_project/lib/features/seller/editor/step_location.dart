import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/serif_title.dart';
import '../../../core/widgets/soft_banner.dart';
import '../../explore/location_service.dart';
import '../../explore/map_view.dart' show cartoPositronUrl, mapAttribution, tileProviderOverrideProvider;
import '../../listings/listings_repository.dart';
import '../../listings/models.dart' show LocationCity;
import 'editor_controller.dart';
import 'editor_widgets.dart';

/// Villes et quartiers connus, pour les suggestions (vide en cas d'erreur).
final editorLocationsProvider = FutureProvider.autoDispose<List<LocationCity>>((ref) async {
  try {
    return await ref.read(listingsRepositoryProvider).locations();
  } catch (_) {
    return const [];
  }
}, retry: (_, _) => null);

/// Étape 2 : ville, quartier, adresse facultative et épingle sur la carte.
class StepLocation extends ConsumerStatefulWidget {
  const StepLocation({super.key, required this.c});
  final EditorController c;

  @override
  ConsumerState<StepLocation> createState() => _StepLocationState();
}

class _StepLocationState extends ConsumerState<StepLocation> {
  final _map = MapController();
  bool _moved = false;
  bool _locating = false;

  EditorController get c => widget.c;

  @override
  void initState() {
    super.initState();
    if (c.location == null) {
      // Épingle par défaut à Abidjan, puis à la position actuelle si elle est connue.
      c.location = abidjan;
      _locating = true;
      _centerOnUser(ask: false);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _centerOnUser({required bool ask}) async {
    LatLng? here;
    try {
      here = await ref.read(locationServiceProvider).current(ask: ask);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _locating = false);
    if (here == null) {
      if (ask) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Position indisponible. Placez l’épingle à la main.')));
      }
      return;
    }
    if (!ask && _moved) return; // ne pas déplacer une épingle déjà posée
    _place(here, move: true);
  }

  void _place(LatLng p, {bool move = false}) {
    _moved = true;
    c.edit(() => c.location = p);
    if (move) {
      try {
        _map.move(p, _map.camera.zoom < 15 ? 16 : _map.camera.zoom);
      } catch (_) {} // carte pas encore prête
    }
  }

  List<String> _districts(List<LocationCity> all) {
    final city = c.city.trim().toLowerCase();
    final match = all.where((x) => x.city.toLowerCase() == city);
    return {for (final x in (match.isEmpty ? all : match)) ...x.districts}.toList();
  }

  @override
  Widget build(BuildContext context) {
    final e = c.fieldErrors;
    final known = ref.watch(editorLocationsProvider).value ?? const <LocationCity>[];
    final tiles = ref.watch(tileProviderOverrideProvider);

    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      const SerifTitle('', 'Où', after: ' se trouve-t-il ?', size: 26),
      const EditorLabel('Ville'),
      _Suggest(
        key: const Key('field-city'),
        initial: c.city,
        hint: 'Ex. : Abidjan',
        options: [for (final x in known) x.city],
        onChanged: (v) => c.edit(() => c.city = v),
        error: e['city'],
      ),
      const EditorLabel('Quartier'),
      _Suggest(
        key: const Key('field-district'),
        initial: c.district,
        hint: 'Ex. : Cocody, Riviera 3',
        options: _districts(known),
        onChanged: (v) => c.district = v,
        error: e['district'],
      ),
      const EditorLabel('Adresse', optional: true),
      EditorField(
        key: const Key('field-address'),
        initialValue: c.address,
        hint: 'Rue, repère…',
        maxLength: 200,
        onChanged: (v) => c.address = v,
        error: e['address'],
      ),
      const EditorLabel('Position sur la carte'),
      const EditorHint('Déplacez la carte ou touchez-la pour placer l’épingle sur le logement. '
          'Les visiteurs ne voient qu’une zone approximative.'),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(WellyRadii.card),
        child: SizedBox(
          height: 260,
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: c.location ?? abidjan,
                initialZoom: 15,
                minZoom: 5,
                maxZoom: 18,
                backgroundColor: WellyColors.ivoire,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onPositionChanged: (camera, hasGesture) {
                  if (!hasGesture) return;
                  _moved = true;
                  c.location = camera.center;
                },
                onTap: (_, p) => _place(p, move: true),
              ),
              children: [
                TileLayer(
                  urlTemplate: cartoPositronUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  maxNativeZoom: 19,
                  tileProvider: tiles,
                ),
                const Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(mapAttribution, style: TextStyle(fontSize: 9, color: WellyColors.muted)),
                  ),
                ),
              ],
            ),
            // L'épingle reste au centre : c'est la carte qui bouge.
            const IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 34),
                  child: Icon(Icons.location_on, size: 40, color: WellyColors.laitonText),
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Material(
                color: WellyColors.surface,
                shape: const StadiumBorder(),
                elevation: 1,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _locating
                      ? null
                      : () {
                          setState(() => _locating = true);
                          _centerOnUser(ask: true);
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _locating
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.laiton))
                          : const Icon(Icons.my_location, size: 16, color: WellyColors.ink),
                      const SizedBox(width: 6),
                      const Text('Ma position', style: TextStyle(fontSize: 12.5, color: WellyColors.ink)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
      if (e['location'] != null) FieldErrorText(e['location']!),
    ]);
  }
}

/// Champ libre avec suggestions (villes, quartiers connus).
class _Suggest extends StatelessWidget {
  const _Suggest({
    super.key,
    required this.initial,
    required this.options,
    required this.onChanged,
    this.hint,
    this.error,
  });

  final String initial;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Autocomplete<String>(
          initialValue: TextEditingValue(text: initial),
          optionsBuilder: (v) {
            final q = v.text.trim().toLowerCase();
            if (q.isEmpty) return const Iterable<String>.empty();
            return options.where((o) => o.toLowerCase().contains(q) && o.toLowerCase() != q).take(6);
          },
          onSelected: onChanged,
          fieldViewBuilder: (context, controller, focus, submit) => TextField(
            controller: controller,
            focusNode: focus,
            onChanged: onChanged,
            onSubmitted: (_) => submit(),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: hint, isDense: true),
          ),
        ),
        if (error != null) FieldErrorText(error!),
      ]);
}
