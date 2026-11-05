import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';
import 'otp_panel.dart';

/// Panneau « Se connecter » (numéro + code, nom si nouveau). `true` si connecté.
Future<bool> showLoginSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: WellyColors.ivoire,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(WellyRadii.sheet))),
    builder: (context) => const LoginSheet(),
  );
  return ok ?? false;
}

class LoginSheet extends StatelessWidget {
  const LoginSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('login-sheet'),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SerifTitle('Se ', 'connecter'),
            const SizedBox(height: 6),
            const Text('Pas de mot de passe : un code par SMS suffit.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted)),
            const SizedBox(height: 16),
            OtpPanel(
              onSignedIn: () {
                if (context.mounted) Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
