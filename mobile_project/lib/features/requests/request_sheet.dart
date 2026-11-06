import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_unreachable.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';
import '../../core/widgets/soft_banner.dart';
import '../auth/otp_panel.dart';
import '../listings/models.dart' hide Page;
import 'requests_controller.dart';
import 'requests_repository.dart';

const _dateErrorCodes = {'STAY_DATES_UNAVAILABLE', 'INVALID_STAY_DATES', 'MIN_NIGHTS_NOT_MET'};

/// Calendriers du panneau (remplaçables dans les tests).
class RequestDatePickers {
  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  Future<DateTimeRange?> pickStay(BuildContext context, {DateTimeRange? initial}) => showDateRangePicker(
        context: context,
        firstDate: _today,
        lastDate: _today.add(const Duration(days: 365)),
        initialDateRange: initial,
        helpText: 'Vos dates de séjour',
        saveText: 'Valider',
      );

  Future<DateTime?> pickDay(BuildContext context, {DateTime? initial}) => showDatePicker(
        context: context,
        firstDate: _today,
        lastDate: _today.add(const Duration(days: 365)),
        initialDate: initial,
        helpText: 'Entrée souhaitée',
      );
}

final requestDatePickersProvider = Provider<RequestDatePickers>((ref) => RequestDatePickers());

/// Panneau « Votre demande » : offre, dates, message, visite ; sans compte,
/// connexion par code dans le même panneau. Confirmation douce à l'envoi.
Future<void> showRequestSheet(BuildContext context, ListingDetail listing, OfferType offer) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: WellyColors.ivoire,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(WellyRadii.sheet))),
    builder: (_) => RequestSheet(listing: listing, initialOffer: offer),
  );
  if (sent ?? false) {
    messenger?.showSnackBar(const SnackBar(
      content: Text('Demande envoyée. Le vendeur va vous recontacter.'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class RequestSheet extends ConsumerStatefulWidget {
  const RequestSheet({super.key, required this.listing, required this.initialOffer});
  final ListingDetail listing;
  final OfferType initialOffer;

  @override
  ConsumerState<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<RequestSheet> {
  final _message = TextEditingController();
  late OfferType? _offer;
  DateTimeRange? _stay;
  DateTime? _moveIn;
  bool _wantsVisit = false;

  /// Figé à l'ouverture : le panneau de code reste en place jusqu'à la fin de la connexion.
  bool? _anonymous;
  bool _sending = false;
  String? _datesError;
  String? _moveInError;
  String? _messageError;
  String? _banner;

  List<OfferType> get _offers => widget.listing.offers.types;
  int? get _minNights => widget.listing.offers.nightly?.minNights;

  @override
  void initState() {
    super.initState();
    final offers = _offers;
    _offer = offers.contains(widget.initialOffer) ? widget.initialOffer : (offers.isEmpty ? null : offers.first);
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  static int _nights(DateTimeRange r) =>
      DateTime.utc(r.end.year, r.end.month, r.end.day).difference(DateTime.utc(r.start.year, r.start.month, r.start.day)).inDays;

  /// Problème local sur les dates, sinon `null`.
  String? _localDatesProblem() {
    if (_offer != OfferType.nightly) return null;
    final stay = _stay;
    if (stay == null) return 'Choisissez vos dates.';
    final min = _minNights ?? 1;
    if (_nights(stay) < (min < 1 ? 1 : min)) {
      return min > 1 ? 'Ce logement demande au moins $min nuits.' : 'Choisissez au moins une nuit.';
    }
    return null;
  }

  bool _validate() {
    final problem = _localDatesProblem();
    setState(() => _datesError = problem);
    return problem == null;
  }

  Future<void> _pickStay() async {
    final range = await ref.read(requestDatePickersProvider).pickStay(context, initial: _stay);
    if (range == null || !mounted) return;
    setState(() {
      _stay = range;
      _datesError = _localDatesProblem();
    });
  }

  Future<void> _pickMoveIn() async {
    final day = await ref.read(requestDatePickersProvider).pickDay(context, initial: _moveIn);
    if (day == null || !mounted) return;
    setState(() {
      _moveIn = day;
      _moveInError = null;
    });
  }

  void _onSignedIn() {
    if (!mounted) return;
    setState(() => _anonymous = false);
    _send();
  }

  Future<void> _send() async {
    final offer = _offer;
    if (offer == null || _sending || !_validate()) return;
    final repo = ref.read(requestsRepositoryProvider);
    final nightly = offer == OfferType.nightly;
    setState(() {
      _sending = true;
      _datesError = null;
      _moveInError = null;
      _messageError = null;
      _banner = null;
    });
    try {
      await repo.create(
        listingId: widget.listing.id,
        offerType: offer,
        checkIn: nightly ? _stay!.start : null,
        checkOut: nightly ? _stay!.end : null,
        moveInDate: offer == OfferType.monthly ? _moveIn : null,
        message: _message.text,
        wantsVisit: _wantsVisit,
      );
      if (!mounted) return;
      // L'onglet Demandes affichera la nouvelle demande.
      ref.invalidate(sentRequestsProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showError(ApiError.of(e));
    }
  }

  void _showError(ApiError err) {
    setState(() {
      _sending = false;
      if (_dateErrorCodes.contains(err.code)) {
        _datesError = err.message;
        return;
      }
      _datesError = err.fieldMessage('checkIn') ?? err.fieldMessage('checkOut');
      _moveInError = err.fieldMessage('moveInDate');
      _messageError = err.fieldMessage('message');
      if (_datesError == null && _moveInError == null && _messageError == null) _banner = err.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Session perdue pendant que le panneau est ouvert : on repropose le code.
    ref.listen(sessionControllerProvider, (_, next) {
      if (next.hasValue && next.value == null && _anonymous == false && !_sending) {
        setState(() => _anonymous = true);
      }
    });
    final session = ref.watch(sessionControllerProvider);
    // Compte injoignable (hors ligne) : « Réessayer », pas de nouveau code SMS.
    final unreachable = _anonymous == null && sessionUnreachable(session);
    if (_anonymous == null && !session.isLoading && !unreachable) _anonymous = session.value == null;

    final offer = _offer;
    return Padding(
      key: const Key('request-sheet'),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SerifTitle('Votre ', 'demande'),
            const SizedBox(height: 4),
            Text(
              _anonymous == true ? 'Pas de mot de passe : un code par SMS suffit.' : widget.listing.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted),
            ),
            const SizedBox(height: 14),
            if (offer == null)
              const Text('Aucune offre n’est proposée pour ce logement.', style: TextStyle(fontWeight: FontWeight.w300))
            else if (unreachable)
              const SessionUnreachableMessage()
            else if (_anonymous == null)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else
              ..._form(offer),
          ],
        ),
      ),
    );
  }

  List<Widget> _form(OfferType offer) {
    final price = widget.listing.offers.priceOf(offer);
    final min = _minNights;
    return [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in _offers)
          _OfferChip(
            label: offerTypeLabel(t),
            selected: t == offer,
            onTap: _sending
                ? null
                : () => setState(() {
                      _offer = t;
                      _datesError = null;
                      _moveInError = null;
                      _banner = null;
                    }),
          ),
      ]),
      if (price != null) ...[
        const SizedBox(height: 6),
        Text(
          [
            '${formatPrice(price)} ${priceSuffix(offer)}'.trim(),
            if (offer == OfferType.nightly && min != null && min > 1) '$min nuits minimum',
          ].join(' · '),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted),
        ),
      ],
      const SizedBox(height: 12),
      if (offer == OfferType.nightly) ...[
        _DateField(
          key: const Key('request-dates'),
          label: 'ARRIVÉE ET DÉPART',
          value: _stay == null
              ? null
              : '${formatDate(_stay!.start)} → ${formatDate(_stay!.end)} · '
                  '${_nights(_stay!)} nuit${_nights(_stay!) > 1 ? 's' : ''}',
          placeholder: 'Choisir vos dates',
          error: _datesError != null,
          onTap: _sending ? null : _pickStay,
        ),
        if (_datesError != null) FieldErrorText(_datesError!, key: const Key('request-dates-error')),
        const SizedBox(height: 10),
      ],
      if (offer == OfferType.monthly) ...[
        _DateField(
          key: const Key('request-move-in'),
          label: 'ENTRÉE SOUHAITÉE',
          value: _moveIn == null ? null : formatDate(_moveIn!, long: true, withYear: _moveIn!.year != DateTime.now().year),
          placeholder: 'Facultatif',
          error: _moveInError != null,
          onTap: _sending ? null : _pickMoveIn,
          onClear: _moveIn == null || _sending ? null : () => setState(() => _moveIn = null),
        ),
        if (_moveInError != null) FieldErrorText(_moveInError!),
        const SizedBox(height: 10),
      ],
      TextField(
        key: const Key('request-message'),
        controller: _message,
        enabled: !_sending,
        minLines: 2,
        maxLines: 4,
        maxLength: 1000,
        decoration: InputDecoration(hintText: 'Message au vendeur (facultatif)', counterText: '', errorText: _messageError),
      ),
      SwitchListTile(
        key: const Key('request-visit'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: const Text('Je souhaite visiter', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w300)),
        value: _wantsVisit,
        onChanged: _sending ? null : (v) => setState(() => _wantsVisit = v),
      ),
      if (_banner != null) ...[
        SoftBanner(_banner!),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 4),
      if (_anonymous == true)
        OtpPanel(
          askName: true,
          submitLabel: 'Envoyer ma demande',
          notice: 'Votre nom et votre numéro seront transmis au vendeur',
          validate: _validate,
          onSignedIn: _onSignedIn,
        )
      else
        FilledButton(
          key: const Key('request-submit'),
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.ivoire),
                )
              : const Text('Envoyer ma demande'),
        ),
    ];
  }
}

class _OfferChip extends StatelessWidget {
  const _OfferChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? WellyColors.laitonSoft : WellyColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? WellyColors.laitonSoft : WellyColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
                  color: selected ? WellyColors.laitonText : WellyColors.ink,
                )),
          ),
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.error,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final String? value;
  final String placeholder;
  final bool error;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Material(
        color: WellyColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WellyRadii.card),
          side: BorderSide(color: error ? WellyColors.expired : WellyColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label,
                      style: const TextStyle(fontSize: 10.5, letterSpacing: 0.6, fontWeight: FontWeight.w500, color: WellyColors.muted)),
                  const SizedBox(height: 3),
                  Text(value ?? placeholder,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: value == null ? WellyColors.muted : WellyColors.ink,
                      )),
                ]),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Effacer',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18, color: WellyColors.muted),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.calendar_today_outlined, size: 18, color: WellyColors.muted),
                ),
            ]),
          ),
        ),
      );
}
