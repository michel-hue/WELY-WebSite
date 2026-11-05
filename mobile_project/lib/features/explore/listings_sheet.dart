import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';
import '../favorites/favorite_button.dart';
import '../listings/models.dart' hide Page;
import 'explore_controller.dart';
import 'listing_photo_card.dart';

const sheetMin = 0.18;
const sheetMid = 0.5;
const sheetMax = 0.92;

/// Panneau « Autour de vous » : replié / mi-hauteur / plein écran.
class ListingsSheet extends ConsumerStatefulWidget {
  const ListingsSheet({super.key, required this.controller, required this.onOpen, this.maxSize = sheetMax});

  final DraggableScrollableController controller;
  final ValueChanged<ListingCard> onOpen;

  /// Hauteur pleine (mode Liste), au plus [sheetMax].
  final double maxSize;

  @override
  ConsumerState<ListingsSheet> createState() => _ListingsSheetState();
}

class _ListingsSheetState extends ConsumerState<ListingsSheet> {
  ScrollController? _scroll;
  bool _list = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSize);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSize);
    super.dispose();
  }

  void _onSize() {
    final list = widget.controller.isAttached && widget.controller.size >= widget.maxSize - 0.02;
    if (list != _list) setState(() => _list = list);
  }

  void _setMode(bool list) {
    if (!widget.controller.isAttached) return;
    widget.controller.animateTo(
      list ? widget.maxSize : sheetMid,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Une pastille touchée : son annonce arrive en tête, on remonte la liste.
    ref.listen(exploreControllerProvider.select((s) => s.focusedId), (_, id) {
      if (id == null) return;
      if (_scroll?.hasClients ?? false) _scroll!.jumpTo(0);
      if (widget.controller.isAttached && widget.controller.size < sheetMid - 0.02) _setMode(false);
    });
    final state = ref.watch(exploreControllerProvider);
    final ctrl = ref.read(exploreControllerProvider.notifier);

    return DraggableScrollableSheet(
      controller: widget.controller,
      initialChildSize: sheetMid,
      minChildSize: sheetMin,
      maxChildSize: widget.maxSize,
      snap: true,
      snapSizes: const [sheetMid],
      builder: (context, scroll) {
        _scroll = scroll;
        final items = state.ordered;
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: WellyColors.ivoire,
            borderRadius: BorderRadius.vertical(top: Radius.circular(WellyRadii.sheet)),
            boxShadow: [BoxShadow(color: Color(0x1A13161B), blurRadius: 28, offset: Offset(0, -10))],
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 400) ctrl.loadMore();
              return false;
            },
            child: CustomScrollView(
              controller: scroll,
              slivers: [
                SliverToBoxAdapter(child: _Header(list: _list, onMode: _setMode)),
                if (state.loading && items.isEmpty)
                  const SliverToBoxAdapter(child: _Loading())
                else if (state.error != null)
                  SliverToBoxAdapter(
                    child: _Message(
                      title: state.error!.isNetwork ? state.error!.message : 'Impossible de charger les logements.',
                      body: state.error!.isNetwork ? null : state.error!.message,
                      action: 'Réessayer',
                      onAction: ctrl.retry,
                    ),
                  )
                else if (items.isEmpty)
                  const SliverToBoxAdapter(
                    child: _Message(
                      title: "Aucun logement ici pour l'instant",
                      body: 'Élargissez la zone ou retirez des filtres.',
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => ListingPhotoCard(
                        items[i],
                        key: ValueKey('card-${items[i].id}'),
                        onTap: () => widget.onOpen(items[i]),
                        favorite: FavoriteButton(items[i]),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _Footer(state: state, onRetry: ctrl.retryMore)),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.list, required this.onMode});
  final bool list;
  final ValueChanged<bool> onMode;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFD8D1C5), borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: SerifTitle('', 'Autour de vous', size: 21)),
            _Segmented(list: list, onMode: onMode),
          ]),
        ]),
      );
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.list, required this.onMode});
  final bool list;
  final ValueChanged<bool> onMode;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool on, bool value) => GestureDetector(
          onTap: () => onMode(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: on ? WellyColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: on ? WellyColors.ivoire : WellyColors.ink,
                )),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: WellyColors.surface,
        border: Border.all(color: WellyColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('Carte', !list, false),
        seg('Liste', list, true),
      ]),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.laiton),
          ),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.body, this.action, this.onAction});
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
        child: Column(children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: WellyColors.ink)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted)),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});
  final ExploreState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) return const _Loading();
    if (state.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(child: TextButton(onPressed: onRetry, child: const Text('Réessayer'))),
      );
    }
    return const SizedBox.shrink();
  }
}
