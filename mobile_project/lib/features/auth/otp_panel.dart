import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/phone.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/soft_banner.dart';
import '../favorites/favorites_controller.dart';

const _codeLength = 6;
const _invalidPhone = 'Numéro de téléphone invalide.';

/// Connexion sans mot de passe : téléphone [+ nom] -> code à 6 chiffres.
///
/// Après un `verifyOtp` réussi, fusionne les favoris (sans bloquer en cas
/// d'échec) puis appelle [onSignedIn]. Les erreurs restent dans le panneau,
/// les saisies sont conservées.
class OtpPanel extends ConsumerStatefulWidget {
  const OtpPanel({
    super.key,
    required this.onSignedIn,
    this.askName = false,
    this.submitLabel = 'Se connecter',
    this.notice,
    this.validate,
    this.resendDelay = const Duration(seconds: 60),
  });

  final void Function() onSignedIn;

  /// `true` : nom demandé d'emblée ; sinon seulement si le numéro est nouveau.
  final bool askName;
  final String submitLabel;

  /// Mention affichée sous le téléphone.
  final String? notice;

  /// Vérification préalable (formulaire englobant) avant d'envoyer le code.
  final bool Function()? validate;
  final Duration resendDelay;

  @override
  ConsumerState<OtpPanel> createState() => _OtpPanelState();
}

class _OtpPanelState extends ConsumerState<OtpPanel> {
  final _name = TextEditingController();
  final _phone = TextEditingController(text: phonePrefix);
  final _code = TextEditingController();
  final _codeFocus = FocusNode();

  String? _sentTo;
  bool _isNewUser = false;
  bool _busy = false;
  String? _nameError;
  String? _phoneError;
  String? _codeError;
  String? _banner;
  Timer? _timer;
  int _resendIn = 0;

  bool get _codeSent => _sentTo != null;
  bool get _showName => widget.askName || (_codeSent && _isNewUser);

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendIn = widget.resendDelay.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _requestCode({bool resend = false}) async {
    if (_busy) return;
    if (!resend && widget.validate != null && !widget.validate!()) return;
    final phone = resend ? _sentTo : normalizePhone(_phone.text);
    if (phone == null) {
      setState(() => _phoneError = _invalidPhone);
      return;
    }
    final session = ref.read(sessionControllerProvider.notifier);
    setState(() {
      _busy = true;
      _phoneError = null;
      _codeError = null;
      _banner = null;
    });
    try {
      final r = await session.requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sentTo = phone;
        _isNewUser = r.isNewUser;
        _code.clear();
      });
      _startCountdown();
      _codeFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      final err = ApiError.of(e);
      setState(() {
        _busy = false;
        final phoneMsg = err.fieldMessage('phone') ?? (err.code == 'INVALID_PHONE' ? err.message : null);
        if (phoneMsg != null && !resend) {
          _phoneError = phoneMsg;
        } else {
          _banner = err.message;
        }
      });
    }
  }

  Future<void> _verify() async {
    final phone = _sentTo;
    final code = _code.text;
    if (_busy || phone == null || code.length != _codeLength) return;
    final session = ref.read(sessionControllerProvider.notifier);
    final favorites = ref.read(favoritesProvider.notifier);
    final onSignedIn = widget.onSignedIn;
    final name = _name.text.trim();
    setState(() {
      _busy = true;
      _nameError = null;
      _codeError = null;
      _banner = null;
    });
    try {
      await session.verifyOtp(phone, code, name: name.isEmpty ? null : name);
    } catch (e) {
      if (mounted) _showVerifyError(ApiError.of(e));
      return;
    }
    try {
      await favorites.syncAfterSignIn();
    } catch (_) {
      // La fusion des favoris ne doit jamais empêcher la suite.
    }
    if (mounted) setState(() => _busy = false);
    onSignedIn();
  }

  void _showVerifyError(ApiError err) {
    setState(() {
      _busy = false;
      switch (err.code) {
        case 'OTP_INVALID' || 'OTP_TOO_MANY_ATTEMPTS':
          _codeError = err.message;
          _code.clear();
        default:
          final nameMsg = err.fieldMessage('name');
          final codeMsg = err.fieldMessage('code');
          if (nameMsg != null) {
            _nameError = nameMsg;
            if (!_showName) _isNewUser = true;
          }
          if (codeMsg != null) _codeError = codeMsg;
          if (nameMsg == null && codeMsg == null) _banner = err.message;
      }
    });
    if (_codeError != null) _codeFocus.requestFocus();
  }

  void _editPhone() {
    _timer?.cancel();
    setState(() {
      _sentTo = null;
      _resendIn = 0;
      _code.clear();
      _codeError = null;
      _banner = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showName) ...[
          TextField(
            key: const Key('otp-name'),
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            decoration: InputDecoration(labelText: 'Votre nom', counterText: '', errorText: _nameError),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          key: const Key('otp-phone'),
          controller: _phone,
          readOnly: _codeSent,
          enabled: !_busy || _codeSent,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ .\-]'))],
          onChanged: (_) {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
          decoration: InputDecoration(
            labelText: 'Téléphone',
            errorText: _phoneError,
            suffixIcon: _codeSent
                ? TextButton(
                    key: const Key('otp-edit-phone'),
                    onPressed: _busy ? null : _editPhone,
                    child: const Text('Modifier'),
                  )
                : null,
          ),
        ),
        if (widget.notice != null) ...[
          const SizedBox(height: 8),
          Text(widget.notice!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
        ],
        if (_codeSent) ...[
          const SizedBox(height: 16),
          const Text('Code reçu par SMS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted)),
          const SizedBox(height: 8),
          _CodeBoxes(
            controller: _code,
            focusNode: _codeFocus,
            enabled: !_busy,
            onChanged: (v) {
              setState(() => _codeError = null);
              if (v.length == _codeLength) _verify();
            },
          ),
          if (_codeError != null) FieldErrorText(_codeError!),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('otp-resend'),
              onPressed: _resendIn > 0 || _busy ? null : () => _requestCode(resend: true),
              child: Text(_resendIn > 0 ? 'Renvoyer le code ($_resendIn s)' : 'Renvoyer le code'),
            ),
          ),
        ],
        if (_banner != null) ...[
          const SizedBox(height: 10),
          SoftBanner(_banner!),
        ],
        const SizedBox(height: 12),
        if (!_codeSent)
          FilledButton(
            key: const Key('otp-send-code'),
            onPressed: _busy ? null : _requestCode,
            child: _busy ? const _Spinner() : const Text('Recevoir le code'),
          )
        else
          FilledButton(
            key: const Key('otp-submit'),
            onPressed: _busy || _code.text.length != _codeLength ? null : _verify,
            child: _busy ? const _Spinner() : Text(widget.submitLabel),
          ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.ivoire),
      );
}

/// Six cases ; un seul champ invisible derrière (avance automatique, collage,
/// remplissage automatique du code SMS par le système).
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.controller, required this.focusNode, required this.enabled, required this.onChanged});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Stack(children: [
        ListenableBuilder(
          listenable: Listenable.merge([controller, focusNode]),
          builder: (context, _) {
            final text = controller.text;
            return Row(children: [
              for (var i = 0; i < _codeLength; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: WellyColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: focusNode.hasFocus && i == text.length.clamp(0, _codeLength - 1)
                            ? WellyColors.laiton
                            : WellyColors.line,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      i < text.length ? text[i] : '',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: WellyColors.ink),
                    ),
                  ),
                ),
              ],
            ]);
          },
        ),
        Positioned.fill(
          child: TextField(
            key: const Key('otp-code'),
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_codeLength),
            ],
            showCursor: false,
            enableInteractiveSelection: true,
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }
}
