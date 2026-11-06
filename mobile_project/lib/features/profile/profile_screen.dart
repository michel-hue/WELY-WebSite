import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../../core/phone.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_unreachable.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';
import '../../core/widgets/welly_logo.dart';
import '../auth/login_sheet.dart';
import '../notifications/notifications_repository.dart';
import 'edit_profile_sheet.dart';
import 'seller_space.dart';

/// Onglet Profil. Anonyme : bienvenue, « Se connecter », « Proposer un
/// logement ». Connecté : bascule Acheteur / Vendeur ; acheteur = profil et
/// actions du compte ; vendeur = espace vendeur puis le compte.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool? _visible;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Les onglets inactifs ont leurs tickers coupés : sert de signal de visibilité.
    final visible = TickerMode.valuesOf(context).enabled;
    if (_visible == false && visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
    _visible = visible;
  }

  void _refresh() {
    ref.invalidate(unreadCountProvider);
    if (ref.exists(myListingsProvider)) ref.read(myListingsProvider.notifier).reload();
    if (ref.exists(pendingRequestsCountProvider)) ref.invalidate(pendingRequestsCountProvider);
  }

  SessionController get _session => ref.read(sessionControllerProvider.notifier);

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack(ApiError.of(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setSeller(bool enabled) => _run(() async {
        await _session.setSellerMode(enabled);
      });

  Future<void> _proposeListing() async {
    final ok = await showLoginSheet(context);
    if (!ok || !mounted) return;
    final me = ref.read(sessionControllerProvider).value;
    if (me != null && !me.isSeller) await _setSeller(true);
  }

  Future<void> _newListing() async {
    await context.push('/seller/listings/new');
    if (mounted && ref.exists(myListingsProvider)) await ref.read(myListingsProvider.notifier).reload();
  }

  Future<void> _openNotifications() async {
    await context.push('/notifications');
    if (mounted) ref.invalidate(unreadCountProvider);
  }

  Future<void> _editProfile(Me me) async {
    if (await showEditProfileSheet(context, me)) _snack('Profil mis à jour.');
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WellyColors.ivoire,
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous pourrez vous reconnecter avec votre numéro et un code SMS.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (ok ?? false) await _run(_session.logout);
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const DeleteAccountDialog());
    if (!(ok ?? false) || !mounted) return;
    var done = false;
    await _run(() async {
      await _session.deleteAccount();
      done = true;
    });
    if (done) _snack('Votre compte a été supprimé.');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final me = session.hasError ? null : session.value;

    final Widget body;
    if (session.isLoading && !session.hasValue) {
      body = const Center(child: CircularProgressIndicator(color: WellyColors.laiton));
    } else if (sessionUnreachable(session)) {
      body = const Center(child: SingleChildScrollView(child: SessionUnreachableMessage()));
    } else if (me == null) {
      body = _Anonymous(onLogin: () => showLoginSheet(context), onPropose: _proposeListing);
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(children: [
            _RoleSegments(seller: me.isSeller, enabled: !_busy, onChanged: _setSeller),
            const Spacer(),
            if (me.isSeller)
              Material(
                color: WellyColors.laiton,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('new-listing'),
                  customBorder: const CircleBorder(),
                  onTap: _newListing,
                  child: const SizedBox.square(
                    dimension: 42,
                    child: Icon(Icons.add, color: WellyColors.ink, semanticLabel: 'Publier une annonce'),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          if (me.isSeller) ...[
            const SellerSpace(),
            const SizedBox(height: 28),
            const Text('Mon compte',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: WellyColors.muted, letterSpacing: .3)),
            const SizedBox(height: 10),
          ],
          _ProfileCard(me: me),
          const SizedBox(height: 14),
          _Actions(
            onEdit: () => _editProfile(me),
            onNotifications: _openNotifications,
            onAbout: () => showWellyAbout(context),
            onLogout: _busy ? null : _logout,
            onDelete: _busy ? null : _deleteAccount,
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: WellyColors.ivoire,
      body: SafeArea(bottom: false, child: body),
    );
  }
}

class _Anonymous extends StatelessWidget {
  const _Anonymous({required this.onLogin, required this.onPropose});
  final VoidCallback onLogin;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 56, 28, 32),
        children: [
          const Center(child: WellyLogo(size: 64)),
          const SizedBox(height: 22),
          const Center(child: SerifTitle('Bienvenue sur ', 'WELLY', size: 28)),
          const SizedBox(height: 10),
          const Text(
            'Suivez vos demandes, retrouvez vos favoris sur tous vos appareils ou proposez votre logement. '
            'Pas de mot de passe : un code par SMS suffit.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: WellyColors.muted, height: 1.45),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: onLogin, child: const Text('Se connecter')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPropose,
            icon: const Icon(Icons.add_home_outlined, size: 20),
            label: const Text('Proposer un logement'),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(onPressed: () => showWellyAbout(context), child: const Text('À propos')),
          ),
        ],
      );
}

class _RoleSegments extends StatelessWidget {
  const _RoleSegments({required this.seller, required this.enabled, required this.onChanged});
  final bool seller;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool value) {
      final on = seller == value;
      return GestureDetector(
        onTap: !enabled || on ? null : () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: on ? WellyColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: on ? WellyColors.ivoire : WellyColors.ink)),
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('Acheteur', false), seg('Vendeur', true)]),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.me});
  final Me me;

  @override
  Widget build(BuildContext context) {
    final name = me.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final wa = me.whatsappPhone;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WellyColors.surface,
        border: Border.all(color: WellyColors.lineSoft),
        borderRadius: BorderRadius.circular(WellyRadii.cardLarge),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: WellyColors.laitonSoft, shape: BoxShape.circle),
          child: Text(initial,
              style: const TextStyle(
                  fontFamily: kSerifFamily, fontStyle: FontStyle.italic, fontSize: 28, color: WellyColors.laitonText)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: WellyColors.ink)),
            if (me.phone != null) ...[
              const SizedBox(height: 3),
              Text(formatPhone(me.phone!),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
            ],
            if (wa != null && wa != me.phone) ...[
              const SizedBox(height: 2),
              Text('WhatsApp : ${formatPhone(wa)}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.onEdit,
    required this.onNotifications,
    required this.onAbout,
    required this.onLogout,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onNotifications;
  final VoidCallback onAbout;
  final VoidCallback? onLogout;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    Widget tile(IconData icon, String label, VoidCallback? onTap, {Widget? trailing, Color color = WellyColors.ink}) =>
        ListTile(
          onTap: onTap,
          leading: Icon(icon, size: 22, color: color),
          title: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300, color: color)),
          trailing: trailing ?? const Icon(Icons.chevron_right, color: WellyColors.muted),
        );
    const divider = Divider(height: 1, indent: 56, color: WellyColors.lineSoft);
    return Container(
      decoration: BoxDecoration(
        color: WellyColors.surface,
        border: Border.all(color: WellyColors.lineSoft),
        borderRadius: BorderRadius.circular(WellyRadii.cardLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: [
          tile(Icons.edit_outlined, 'Modifier mon profil', onEdit),
          divider,
          tile(
            Icons.notifications_none_outlined,
            'Notifications',
            onNotifications,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (unread > 0)
                Container(
                  key: const Key('notifications-badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: WellyColors.laiton, borderRadius: BorderRadius.circular(999)),
                  child: Text(unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: WellyColors.ink)),
                ),
              const Icon(Icons.chevron_right, color: WellyColors.muted),
            ]),
          ),
          divider,
          tile(Icons.info_outline, 'À propos', onAbout),
          divider,
          tile(Icons.logout, 'Se déconnecter', onLogout),
          divider,
          tile(Icons.delete_outline, 'Supprimer mon compte', onDelete, color: WellyColors.expired, trailing: const SizedBox.shrink()),
        ]),
      ),
    );
  }
}

/// « À propos » : nom de l'app et version.
Future<void> showWellyAbout(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WellyColors.ivoire,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const WellyLogo(size: 44, wordmark: true),
          const SizedBox(height: 14),
          const Text('Trouver un logement en Côte d’Ivoire.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: WellyColors.ink)),
          const SizedBox(height: 8),
          const Text('Version $appVersion', style: TextStyle(fontSize: 12.5, color: WellyColors.muted)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer'))],
      ),
    );

/// Confirmation de suppression : il faut taper exactement « SUPPRIMER ». `true` si confirmé.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  static const word = 'SUPPRIMER';

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _text.text.trim() == DeleteAccountDialog.word;
    return AlertDialog(
      backgroundColor: WellyColors.ivoire,
      title: const Text('Supprimer mon compte ?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Vos annonces seront retirées, vos favoris effacés et vos demandes en attente annulées. Cette action est définitive.',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, height: 1.4),
        ),
        const SizedBox(height: 12),
        const Text('Tapez SUPPRIMER pour confirmer.', style: TextStyle(fontSize: 13, color: WellyColors.muted)),
        const SizedBox(height: 6),
        TextField(
          key: const Key('delete-account-field'),
          controller: _text,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: DeleteAccountDialog.word),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        FilledButton(
          key: const Key('delete-account-confirm'),
          style: FilledButton.styleFrom(backgroundColor: WellyColors.expired, foregroundColor: WellyColors.ivoire),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Supprimer'),
        ),
      ],
    );
  }
}
