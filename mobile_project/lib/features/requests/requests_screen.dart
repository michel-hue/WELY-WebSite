import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/contact.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/calm_message.dart';
import '../../core/widgets/serif_title.dart';
import '../auth/login_sheet.dart';
import '../listings/models.dart' hide Page;
import '../seller/seller_listings_repository.dart';
import 'models.dart';
import 'request_tile.dart';
import 'requests_controller.dart';

/// Onglet Demandes. Anonyme : invitation à se connecter. Acheteur : mes
/// demandes. Vendeur : segments « Reçues / Envoyées ». Rechargé à chaque
/// retour sur l'onglet et au changement de session ; tirer pour rafraîchir.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  bool _received = true;
  bool? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Les onglets inactifs ont leurs tickers coupés : sert de signal de visibilité.
    final visible = TickerMode.valuesOf(context).enabled;
    if (_visible == false && visible) {
      // Hors de la phase de construction : on ne modifie pas un provider pendant un build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reloadAll();
      });
    }
    _visible = visible;
  }

  void _reloadAll() {
    if (ref.exists(sentRequestsProvider)) ref.read(sentRequestsProvider.notifier).reload();
    if (ref.exists(receivedRequestsProvider)) ref.read(receivedRequestsProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final me = session.hasError ? null : session.value;

    final Widget body;
    if (session.isLoading && !session.hasValue) {
      body = const Center(child: CircularProgressIndicator(color: WellyColors.laiton));
    } else if (me == null) {
      body = SingleChildScrollView(
        child: CalmMessage(
          icon: Icons.chat_bubble_outline,
          title: 'Suivez vos demandes ici',
          body: 'Connectez-vous pour voir vos demandes, leur réponse et recontacter les vendeurs.',
          action: 'Se connecter',
          onAction: () => showLoginSheet(context),
        ),
      );
    } else {
      final received = me.isSeller && _received;
      body = _RequestsList(
        key: ValueKey(received ? 'received' : 'sent'),
        received: received,
      );
    }

    return Scaffold(
      backgroundColor: WellyColors.ivoire,
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
            child: Row(children: [
              const Expanded(child: SerifTitle('Vos ', 'demandes', size: 24)),
              if (me?.isSeller ?? false) _Segments(received: _received, onChanged: (v) => setState(() => _received = v)),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.received, required this.onChanged});
  final bool received;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool value) {
      final on = received == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: on ? WellyColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: on ? WellyColors.ivoire : WellyColors.ink)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: WellyColors.surface,
        border: Border.all(color: WellyColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('Reçues', true), seg('Envoyées', false)]),
    );
  }
}

class _RequestsList extends ConsumerStatefulWidget {
  const _RequestsList({super.key, required this.received});
  final bool received;

  @override
  ConsumerState<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends ConsumerState<_RequestsList> {
  final _busy = <String>{};

  AsyncNotifierProvider<RequestsController, RequestsState> get _provider =>
      widget.received ? receivedRequestsProvider : sentRequestsProvider;

  RequestsController get _ctrl => ref.read(_provider.notifier);

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<T?> _run<T>(String id, Future<T> Function() action) async {
    setState(() => _busy.add(id));
    try {
      return await action();
    } catch (e) {
      _snack(ApiError.of(e).message);
      return null;
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<bool> _confirm({required String title, String? body, required String yes, String no = 'Annuler'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WellyColors.ivoire,
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(no)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(yes)),
        ],
      ),
    );
    return ok ?? false;
  }

  // --- Acheteur ---

  Future<void> _cancel(ListingRequest r) async {
    final ok = await _confirm(
      title: 'Annuler cette demande ?',
      body: 'Le vendeur ne pourra plus y répondre.',
      yes: 'Oui, annuler',
      no: 'Non',
    );
    if (!ok || !mounted) return;
    final done = await _run(r.id, () => _ctrl.cancel(r.id));
    if (done != null) _snack('Demande annulée.');
  }

  // --- Contact ---

  Future<void> _call(String phone) async {
    final launcher = ref.read(urlLauncherProvider);
    if (!await launcher.launch(telUri(phone))) _snack("Impossible de passer l'appel sur cet appareil.");
  }

  Future<void> _whatsApp({required String phone, String? callPhone, required String title, required String message, required String who}) async {
    final launcher = ref.read(urlLauncherProvider);
    var declined = false;
    final used = await openWhatsAppOrCall(
      launcher,
      phone,
      title,
      callPhone: callPhone,
      message: message,
      confirmCall: () async {
        if (!mounted) return false;
        final ok = await _confirm(title: "WhatsApp n'est pas installé", body: 'Voulez-vous appeler $who ?', yes: 'Appeler');
        declined = !ok;
        return ok;
      },
    );
    if (used == null && !declined) _snack("Impossible d'ouvrir WhatsApp ou l'appel sur cet appareil.");
  }

  VoidCallback? _contactSeller(ListingRequest r) {
    final s = r.seller;
    final phone = s?.whatsappPhone ?? s?.phone;
    if (s == null || phone == null) return null;
    return () => _whatsApp(
          phone: phone,
          callPhone: s.phone ?? phone,
          title: r.listing.title,
          message: 'Bonjour, je vous contacte au sujet de ma demande pour « ${r.listing.title} » sur WELLY.',
          who: 'le vendeur',
        );
  }

  // --- Vendeur ---

  Future<void> _accept(ListingRequest r) async {
    final updated = await _run(r.id, () => _ctrl.accept(r.id));
    if (updated == null || !mounted) return;
    final reason = switch (updated.offerType) {
      OfferType.monthly => ClosedReason.rented,
      OfferType.sale => ClosedReason.sold,
      OfferType.nightly => null,
    };
    final ctrl = _ctrl;
    if (reason == null) {
      _snack('Demande acceptée.');
    } else {
      final word = reason == ClosedReason.rented ? 'loué' : 'vendu';
      final close = await _confirm(
        title: 'Marquer comme $word ?',
        body: '« ${updated.listing.title} » ne sera plus proposé dans les recherches. '
            'Vous pourrez le remettre en ligne depuis vos annonces.',
        yes: 'Marquer comme $word',
        no: 'Plus tard',
      );
      if (close && mounted) {
        final sellerRepo = ref.read(sellerListingsRepositoryProvider);
        final ok = await _run(r.id, () async {
          await sellerRepo.close(updated.listing.id, reason);
          return true;
        });
        if (ok == true) {
          _snack(reason == ClosedReason.rented ? 'Logement marqué comme loué.' : 'Logement marqué comme vendu.');
        }
      }
    }
    // Les autres demandes sur ce logement ont pu changer côté serveur
    // (nuits bloquées, annonce close) : on recharge la liste.
    await ctrl.reload();
  }

  Future<void> _refuse(ListingRequest r) async {
    final message = await showDialog<String>(context: context, builder: (_) => const _RefuseDialog());
    if (message == null || !mounted) return;
    final done = await _run(r.id, () => _ctrl.refuse(r.id, message: message));
    if (done != null) _snack('Demande refusée.');
  }

  Widget _tile(ListingRequest r) {
    void open() => context.push('/listing/${r.listing.id}');
    final busy = _busy.contains(r.id);
    if (!widget.received) {
      return SentRequestTile(
        key: ValueKey('sent-${r.id}'),
        request: r,
        busy: busy,
        onOpen: open,
        onCancel: () => _cancel(r),
        onContact: _contactSeller(r),
      );
    }
    final phone = r.buyer?.phone;
    return ReceivedRequestTile(
      key: ValueKey('received-${r.id}'),
      request: r,
      busy: busy,
      onOpen: open,
      onCall: phone == null ? null : () => _call(phone),
      onWhatsApp: phone == null
          ? null
          : () => _whatsApp(
                phone: phone,
                title: r.listing.title,
                message: 'Bonjour, je vous réponds au sujet de votre demande pour « ${r.listing.title} » sur WELLY.',
                who: "l'acheteur",
              ),
      onAccept: () => _accept(r),
      onRefuse: () => _refuse(r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_provider);

    Widget scrollable(List<Widget> children) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: children,
        );

    final Widget content = async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: WellyColors.laiton)),
      error: (e, _) {
        final err = ApiError.of(e);
        return scrollable([
          CalmMessage(
            icon: Icons.wifi_off_outlined,
            title: err.isNetwork ? err.message : 'Impossible de charger les demandes.',
            body: err.isNetwork ? null : err.message,
            action: 'Réessayer',
            onAction: () => ref.invalidate(_provider),
          ),
        ]);
      },
      data: (s) {
        if (s.items.isEmpty) {
          return scrollable([
            widget.received
                ? const CalmMessage(
                    icon: Icons.inbox_outlined,
                    title: 'Aucune demande reçue',
                    body: 'Les demandes sur vos annonces apparaîtront ici.',
                  )
                : const CalmMessage(
                    icon: Icons.chat_bubble_outline,
                    title: 'Aucune demande pour l’instant',
                    body: 'Faites une demande depuis la fiche d’un logement : elle apparaîtra ici.',
                  ),
          ]);
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 300) _ctrl.loadMore();
            return false;
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: s.items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => i < s.items.length ? _tile(s.items[i]) : _Footer(state: s, onRetry: _ctrl.loadMore),
          ),
        );
      },
    );

    return RefreshIndicator(color: WellyColors.laiton, onRefresh: _ctrl.reload, child: content);
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});
  final RequestsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.laiton)),
        ),
      );
    }
    if (state.moreError != null) {
      return Center(child: TextButton(onPressed: onRetry, child: const Text('Réessayer')));
    }
    return const SizedBox.shrink();
  }
}

/// Refus avec message facultatif ; renvoie le message ('' si vide) ou `null` si abandon.
class _RefuseDialog extends StatefulWidget {
  const _RefuseDialog();

  @override
  State<_RefuseDialog> createState() => _RefuseDialogState();
}

class _RefuseDialogState extends State<_RefuseDialog> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: WellyColors.ivoire,
        title: const Text('Refuser la demande ?'),
        content: TextField(
          key: const Key('refuse-message'),
          controller: _message,
          maxLength: 500,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Message (facultatif)', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(
            key: const Key('refuse-confirm'),
            onPressed: () => Navigator.of(context).pop(_message.text.trim()),
            child: const Text('Refuser'),
          ),
        ],
      );
}
