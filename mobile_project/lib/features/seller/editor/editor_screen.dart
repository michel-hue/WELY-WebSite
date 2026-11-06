import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/calm_message.dart';
import '../../../core/widgets/soft_banner.dart';
import '../manage_listing_screen.dart' show refreshMyListings;
import '../seller_listings_repository.dart';
import 'editor_controller.dart';
import 'step_location.dart';
import 'step_offers.dart';
import 'step_photos.dart';
import 'step_property.dart';
import 'step_publish.dart';

/// Création ([id] `null`) ou modification d'une annonce, en étapes courtes
/// avec progression ; le brouillon est enregistré dans l'API dès l'étape 2.
class ListingEditorScreen extends ConsumerStatefulWidget {
  const ListingEditorScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<ListingEditorScreen> createState() => _ListingEditorScreenState();
}

class _ListingEditorScreenState extends ConsumerState<ListingEditorScreen> {
  late final EditorController c;

  @override
  void initState() {
    super.initState();
    c = EditorController(ref.read(sellerListingsRepositoryProvider), listingId: widget.id);
    if (widget.id != null) c.load();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    final hadDraft = c.listingId != null;
    final publishing = c.isLastStep && c.hasPublishStep;
    final ok = await c.next();
    if (!mounted || !ok) return;
    if (!hadDraft && c.listingId != null) refreshMyListings(ref); // brouillon créé
    if (!c.done) return;
    refreshMyListings(ref);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(publishing ? 'Annonce publiée.' : 'Modifications enregistrées.'),
    ));
    if (widget.id == null) {
      context.pushReplacement('/seller/listings/${c.listingId}');
    } else if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/profile');
    }
  }

  void _leave() {
    if (c.listingId != null && c.listing?.status == ListingStatus.draft) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brouillon enregistré. Retrouvez-le dans « Mes annonces ».')));
    }
    refreshMyListings(ref);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  Widget _step() => switch (c.step) {
        0 => StepProperty(c: c),
        1 => StepLocation(c: c),
        2 => StepPhotos(c: c),
        3 => StepOffers(c: c),
        _ => StepPublish(c: c),
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final ready = !c.loading && c.loadError == null;
          return PopScope(
            canPop: !ready || c.step == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                refreshMyListings(ref);
              } else {
                c.back();
              }
            },
            child: Scaffold(
              backgroundColor: WellyColors.ivoire,
              appBar: AppBar(
                backgroundColor: WellyColors.ivoire,
                leading: IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: _leave),
                title: Text(widget.id == null ? 'Nouvelle annonce' : 'Modifier l’annonce'),
              ),
              body: SafeArea(top: false, child: ready ? _body() : _loadState()),
            ),
          );
        },
      );

  Widget _loadState() {
    final err = c.loadError;
    if (err == null) return const Center(child: CircularProgressIndicator(color: WellyColors.laiton));
    return Center(
      child: CalmMessage(
        icon: Icons.wifi_off_outlined,
        title: err.isNetwork ? err.message : 'Impossible de charger l’annonce.',
        body: err.isNetwork ? null : err.message,
        action: 'Réessayer',
        onAction: c.load,
      ),
    );
  }

  Widget _body() {
    final total = c.totalSteps;
    final label = c.isLastStep ? (c.hasPublishStep ? 'Publier' : 'Enregistrer') : 'Continuer';
    final ApiError? err = c.error;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Étape ${c.step + 1} sur $total · ${EditorController.stepTitles[c.step]}',
              key: const Key('editor-progress'),
              style: const TextStyle(fontSize: 12.5, color: WellyColors.muted)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (c.step + 1) / total,
              minHeight: 4,
              color: WellyColors.laiton,
              backgroundColor: WellyColors.laitonSoft,
            ),
          ),
        ]),
      ),
      Expanded(child: KeyedSubtree(key: ValueKey('step-${c.step}'), child: _step())),
      if (err != null)
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: SoftBanner(err.message)),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 20, 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: WellyColors.lineSoft))),
        child: Row(children: [
          if (c.step > 0)
            TextButton(onPressed: c.saving ? null : c.back, child: const Text('Retour'))
          else
            const SizedBox.shrink(),
          const Spacer(),
          FilledButton(
            key: const Key('editor-next'),
            onPressed: c.saving ? null : _next,
            child: c.saving
                ? const SizedBox.square(
                    dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.ivoire))
                : Text(label),
          ),
        ]),
      ),
    ]);
  }
}
