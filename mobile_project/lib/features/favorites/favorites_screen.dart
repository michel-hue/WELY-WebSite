import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/calm_message.dart';
import '../../core/widgets/serif_title.dart';
import '../explore/listing_photo_card.dart';
import '../listings/models.dart' hide Page;
import 'favorite_button.dart';
import 'favorites_controller.dart';

/// Onglet Favoris : grille de cartes photo sur deux colonnes.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final ctrl = ref.read(favoritesProvider.notifier);

    Future<void> refresh() async {
      try {
        ref.invalidate(favoritesProvider);
        await ref.read(favoritesProvider.future);
      } catch (_) {
        // L'erreur s'affiche dans l'écran.
      }
    }

    final Widget body = favorites.when(
      loading: () => const _Fill(child: CircularProgressIndicator(color: WellyColors.laiton)),
      error: (e, _) {
        final err = ApiError.of(e);
        return _Fill(
          child: CalmMessage(
            icon: Icons.wifi_off_outlined,
            title: err.isNetwork ? err.message : 'Impossible de charger vos favoris.',
            body: err.isNetwork ? null : err.message,
            action: 'Réessayer',
            onAction: () => ref.invalidate(favoritesProvider),
          ),
        );
      },
      data: (cards) {
        if (cards.isEmpty) {
          return const _Fill(
            child: CalmMessage(
              icon: Icons.favorite_border,
              title: 'Aucun favori pour l’instant',
              body: 'Touchez ♡ sur un logement pour le retrouver ici',
            ),
          );
        }
        final rows = <List<ListingCard>>[
          for (var i = 0; i < cards.length; i += 2) cards.sublist(i, i + 2 > cards.length ? cards.length : i + 2),
        ];
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var j = 0; j < 2; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(
                  child: j < rows[i].length
                      ? _FavoriteCard(card: rows[i][j], unavailable: ctrl.isUnavailable(rows[i][j].id))
                      : const SizedBox.shrink(),
                ),
              ],
            ]),
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: WellyColors.ivoire,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: WellyColors.laiton,
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 18, 22, 14),
                  child: SerifTitle('Vos ', 'favoris', size: 24),
                ),
              ),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _Fill extends StatelessWidget {
  const _Fill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SliverFillRemaining(hasScrollBody: false, child: Center(child: child));
}

/// Carte favorite ; grisée « plus disponible » si la fiche a disparu.
class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.card, required this.unavailable});
  final ListingCard card;
  final bool unavailable;

  static const _greyscale = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    void open() => context.push('/listing/${card.id}');
    final photoCard = ListingPhotoCard(
      card,
      key: ValueKey('favorite-card-${card.id}'),
      onTap: open,
      favorite: FavoriteButton(card),
      compact: true,
    );
    if (!unavailable) return photoCard;
    return Stack(children: [
      Opacity(opacity: 0.55, child: ColorFiltered(colorFilter: _greyscale, child: photoCard)),
      Positioned(
        left: 8,
        top: 8,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(color: WellyColors.closedBg, borderRadius: BorderRadius.circular(999)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text('plus disponible',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: WellyColors.closed)),
            ),
          ),
        ),
      ),
    ]);
  }
}
