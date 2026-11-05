import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';
import '../listings/models.dart' hide Page;

/// Panneau des filtres ; renvoie les nouveaux filtres, ou `null` si fermé.
Future<SearchFilters?> showFiltersSheet(BuildContext context, SearchFilters current) =>
    showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: WellyColors.ivoire,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(WellyRadii.sheet)),
      ),
      builder: (_) => FiltersSheet(initial: current),
    );

const _sortLabels = {
  SearchSort.distance: 'Distance',
  SearchSort.recent: 'Récentes',
  SearchSort.priceAsc: 'Prix ↑',
  SearchSort.priceDesc: 'Prix ↓',
};

bool _isPriceSort(SearchSort? s) => s == SearchSort.priceAsc || s == SearchSort.priceDesc;

class FiltersSheet extends StatefulWidget {
  const FiltersSheet({super.key, required this.initial});
  final SearchFilters initial;

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late SearchFilters _f = widget.initial;
  late final _min = TextEditingController(text: widget.initial.priceMin?.toString() ?? '');
  late final _max = TextEditingController(text: widget.initial.priceMax?.toString() ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  /// L'API exige un type d'offre pour le prix, le tri par prix et les dates
  /// (les dates : uniquement « à la nuit »).
  void _setOffer(OfferType? type) {
    setState(() {
      if (type == null) {
        _min.clear();
        _max.clear();
        _f = _f.copyWith(
          offerType: null,
          priceMin: null,
          priceMax: null,
          checkIn: null,
          checkOut: null,
          sort: _isPriceSort(_f.sort) ? null : _f.sort,
        );
      } else {
        _f = _f.copyWith(
          offerType: type,
          checkIn: type == OfferType.nightly ? _f.checkIn : null,
          checkOut: type == OfferType.nightly ? _f.checkOut : null,
        );
      }
    });
  }

  void _clear() {
    _min.clear();
    _max.clear();
    setState(() => _f = SearchFilters(q: _f.q));
  }

  Future<void> _pickDates() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _f.checkIn != null && _f.checkOut != null
          ? DateTimeRange(start: _f.checkIn!, end: _f.checkOut!)
          : null,
      helpText: 'Dates du séjour',
      saveText: 'Valider',
    );
    if (range == null || !mounted) return;
    // L'API exige un départ strictement après l'arrivée.
    final out = range.end.isAfter(range.start) ? range.end : range.start.add(const Duration(days: 1));
    setState(() => _f = _f.copyWith(checkIn: range.start, checkOut: out));
  }

  int? _int(String s) => int.tryParse(s.replaceAll(RegExp(r'\D'), ''));

  @override
  Widget build(BuildContext context) {
    final hasOffer = _f.offerType != null;
    final nightly = _f.offerType == OfferType.nightly;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 4),
          child: Row(children: [
            const Expanded(child: SerifTitle('', 'Filtres', size: 24)),
            TextButton(onPressed: _clear, child: const Text('Effacer')),
          ]),
        ),
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              const _Label("Type d'offre"),
              _Chips(children: [
                for (final t in OfferType.values)
                  _Chip(
                    label: offerTypeLabel(t),
                    selected: _f.offerType == t,
                    onTap: () => _setOffer(_f.offerType == t ? null : t),
                  ),
              ]),
              const _Label('Type de bien'),
              _Chips(children: [
                for (final e in propertyTypeLabels.entries)
                  _Chip(
                    label: e.value,
                    selected: _f.propertyTypes.contains(e.key),
                    onTap: () => setState(() => _f = _f.copyWith(propertyTypes: _toggle(_f.propertyTypes, e.key))),
                  ),
              ]),
              _Label(hasOffer ? 'Prix ${priceSuffix(_f.offerType!)}'.trim() : 'Prix'),
              if (!hasOffer) const _Hint("Choisissez d'abord un type d'offre."),
              Row(children: [
                Expanded(child: _priceField(_min, 'Min', hasOffer, (v) => _f = _f.copyWith(priceMin: v))),
                const SizedBox(width: 12),
                Expanded(child: _priceField(_max, 'Max', hasOffer, (v) => _f = _f.copyWith(priceMax: v))),
              ]),
              const _Label('Pièces minimum'),
              _counter(_f.roomsMin, (v) => _f = _f.copyWith(roomsMin: v)),
              const _Label('Chambres minimum'),
              _counter(_f.bedroomsMin, (v) => _f = _f.copyWith(bedroomsMin: v)),
              const _Label('Équipements'),
              _Chips(children: [
                for (final e in amenityLabels.entries)
                  _Chip(
                    label: e.value,
                    selected: _f.amenities.contains(e.key),
                    onTap: () => setState(() => _f = _f.copyWith(amenities: _toggle(_f.amenities, e.key))),
                  ),
              ]),
              const _Label('Dates'),
              if (!nightly) const _Hint('Disponible pour les offres « À la nuit ».'),
              OutlinedButton.icon(
                onPressed: nightly ? _pickDates : null,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(_f.checkIn != null && _f.checkOut != null
                    ? '${formatDate(_f.checkIn!)} → ${formatDate(_f.checkOut!)}'
                    : 'Choisir les dates'),
              ),
              const _Label('Trier par'),
              if (!hasOffer) const _Hint("Le tri par prix demande un type d'offre."),
              _Chips(children: [
                for (final e in _sortLabels.entries)
                  _Chip(
                    label: e.value,
                    selected: _f.sort == e.key,
                    enabled: hasOffer || !_isPriceSort(e.key),
                    onTap: () => setState(() => _f = _f.copyWith(sort: _f.sort == e.key ? null : e.key)),
                  ),
              ]),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_f),
                child: const Text('Afficher les logements'),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _priceField(TextEditingController c, String hint, bool enabled, void Function(int?) set) => TextField(
        controller: c,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(hintText: hint, suffixText: 'F'),
        onChanged: (v) => setState(() => set(_int(v))),
      );

  Widget _counter(int? value, void Function(int?) set) => _Chips(children: [
        for (final n in const [1, 2, 3, 4, 5])
          _Chip(
            label: n == 5 ? '5+' : '$n',
            selected: value == n,
            onTap: () => setState(() => set(value == n ? null : n)),
          ),
      ]);

  static List<String> _toggle(List<String> list, String key) =>
      list.contains(key) ? [...list.where((k) => k != key)] : [...list, key];
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: WellyColors.ink)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: WellyColors.muted)),
      );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.enabled = true});
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled ? WellyColors.muted.withValues(alpha: 0.5) : (selected ? WellyColors.ivoire : WellyColors.ink);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? WellyColors.ink : WellyColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? WellyColors.ink : WellyColors.line),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: fg)),
      ),
    );
  }
}
