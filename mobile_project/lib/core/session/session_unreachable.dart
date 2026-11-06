import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../widgets/calm_message.dart';
import 'session_controller.dart';

/// Compte injoignable au démarrage (hors ligne) : erreur douce avec
/// « Réessayer » au lieu d'inviter à se reconnecter (les jetons sont gardés).
class SessionUnreachableMessage extends ConsumerWidget {
  const SessionUnreachableMessage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => CalmMessage(
        icon: Icons.wifi_off_outlined,
        title: networkMessage,
        body: 'Votre compte s’affichera dès que la connexion sera rétablie.',
        action: 'Réessayer',
        onAction: () => ref.invalidate(sessionControllerProvider),
      );
}
