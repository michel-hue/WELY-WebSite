import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/soft_banner.dart';

/// Petits éléments de formulaire partagés par les étapes de l'éditeur.
class EditorLabel extends StatelessWidget {
  const EditorLabel(this.text, {super.key, this.optional = false});
  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text),
          if (optional)
            const TextSpan(
              text: '  facultatif',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: WellyColors.muted),
            ),
        ]), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: WellyColors.ink)),
      );
}

class EditorHint extends StatelessWidget {
  const EditorHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted, height: 1.4));
}

/// Puce « pilule » (sélection simple ou multiple).
class EditorChip extends StatelessWidget {
  const EditorChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? WellyColors.ink : WellyColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? WellyColors.ink : WellyColors.line),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w400, color: selected ? WellyColors.ivoire : WellyColors.ink)),
        ),
      );
}

/// Champ texte relié à une valeur du contrôleur ; l'erreur s'affiche dessous.
class EditorField extends StatelessWidget {
  const EditorField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.hint,
    this.error,
    this.number = false,
    this.maxLines = 1,
    this.maxLength,
    this.suffix,
    this.helper,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? error;
  final bool number;
  final int maxLines;
  final int? maxLength;
  final String? suffix;
  final String? helper;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: number ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
          textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 3 : 1,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            helperText: helper,
            counterText: '',
            isDense: true,
          ),
        ),
        if (error != null) FieldErrorText(error!),
      ]);
}
