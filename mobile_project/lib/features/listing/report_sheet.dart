import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/labels.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';
import '../listings/listings_repository.dart';

/// Panneau « Signaler l'annonce » (sans compte). Renvoie `true` si envoyé.
Future<bool> showReportSheet(BuildContext context, String listingId) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WellyColors.ivoire,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(WellyRadii.sheet))),
    builder: (_) => ReportSheet(listingId: listingId),
  );
  return sent ?? false;
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final _comment = TextEditingController();
  String? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(listingsRepositoryProvider).report(widget.listingId, reason, comment: _comment.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = ApiError.of(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SerifTitle('Signaler ', "l'annonce"),
              const SizedBox(height: 6),
              const Text("Elle ne vous sera plus proposée. Votre signalement nous aide à garder WELLY sûr.",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted)),
              const SizedBox(height: 14),
              for (final entry in reportReasonLabels.entries)
                _ReasonTile(
                  label: entry.value,
                  selected: _reason == entry.key,
                  onTap: _sending ? null : () => setState(() => _reason = entry.key),
                ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('report-comment'),
                controller: _comment,
                enabled: !_sending,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(hintText: 'Commentaire (facultatif)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(fontSize: 13, color: WellyColors.expired)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _reason == null || _sending ? null : _send,
                child: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.ivoire),
                      )
                    : const Text('Envoyer le signalement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? WellyColors.laitonSoft : WellyColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WellyRadii.card),
            side: BorderSide(color: selected ? WellyColors.laiton : WellyColors.lineSoft),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: selected ? FontWeight.w400 : FontWeight.w300,
                        color: WellyColors.ink,
                      )),
                ),
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20, color: selected ? WellyColors.laitonText : WellyColors.line),
              ]),
            ),
          ),
        ),
      );
}
