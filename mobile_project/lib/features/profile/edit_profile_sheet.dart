import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/phone.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';
import '../../core/widgets/soft_banner.dart';

/// Panneau « Modifier mon profil » (nom, numéro WhatsApp). `true` si enregistré.
Future<bool> showEditProfileSheet(BuildContext context, Me me) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: WellyColors.ivoire,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(WellyRadii.sheet))),
    builder: (_) => EditProfileSheet(me: me),
  );
  return ok ?? false;
}

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.me});
  final Me me;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final _name = TextEditingController(text: widget.me.name);
  late final _whatsapp =
      TextEditingController(text: widget.me.whatsappPhone == null ? '' : formatPhone(widget.me.whatsappPhone!));
  bool _busy = false;
  String? _nameError;
  String? _whatsappError;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final wa = _whatsapp.text.trim();
    final waDigits = wa.replaceAll(RegExp(r'[^\d]'), '');
    final clear = (wa.isEmpty || waDigits == '225') && widget.me.whatsappPhone != null;
    final normalized = wa.isEmpty || waDigits == '225' ? null : normalizePhone(wa);
    setState(() {
      _error = null;
      _nameError = name.length < 2 ? 'Indiquez votre nom (2 caractères minimum).' : null;
      _whatsappError = wa.isNotEmpty && waDigits != '225' && normalized == null ? 'Numéro invalide.' : null;
    });
    if (_nameError != null || _whatsappError != null) return;

    setState(() => _busy = true);
    try {
      await ref.read(sessionControllerProvider.notifier).updateProfile(
            name: name,
            whatsappPhone: normalized,
            clearWhatsapp: clear,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final err = ApiError.of(e);
      if (!mounted) return;
      setState(() {
        _nameError = err.fieldMessage('name');
        _whatsappError = err.fieldMessage('whatsappPhone');
        _error = _nameError == null && _whatsappError == null ? err.message : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('edit-profile-sheet'),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SerifTitle('Mon ', 'profil'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('profile-name'),
              controller: _name,
              enabled: !_busy,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Votre nom', counterText: '', errorText: _nameError),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('profile-whatsapp'),
              controller: _whatsapp,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Numéro WhatsApp',
                hintText: phonePrefix,
                helperText: 'Laissez vide pour utiliser votre numéro de téléphone.',
                errorText: _whatsappError,
              ),
            ),
            if (widget.me.phone != null) ...[
              const SizedBox(height: 10),
              Text('Téléphone de connexion : ${formatPhone(widget.me.phone!)}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              SoftBanner(_error!),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.ivoire))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
