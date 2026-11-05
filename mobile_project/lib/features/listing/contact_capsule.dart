import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Capsule sombre flottante (maquette « 3 · capsule ») : WhatsApp à gauche,
/// « Faire une demande » en laiton à droite.
class ContactCapsule extends StatelessWidget {
  const ContactCapsule({super.key, this.onWhatsApp, required this.onRequest});

  /// `null` : le vendeur n'a pas de numéro, WhatsApp est désactivé.
  final VoidCallback? onWhatsApp;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) => _CapsuleShell(
        child: Row(children: [
          Expanded(
            flex: 10,
            child: Semantics(
              button: true,
              enabled: onWhatsApp != null,
              child: InkWell(
                key: const Key('capsule-whatsapp'),
                onTap: onWhatsApp,
                customBorder: const StadiumBorder(),
                child: Opacity(
                  opacity: onWhatsApp == null ? 0.4 : 1,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      WhatsAppGlyph(size: 18, color: WellyColors.ivoire),
                      SizedBox(width: 7),
                      Text('WhatsApp',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: WellyColors.ivoire)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Expanded(flex: 13, child: _LaitonPill(label: 'Faire une demande', onTap: onRequest)),
        ]),
      );
}

/// Pictogramme WhatsApp simplifié (bulle ronde à queue + combiné), sans
/// dépendance SVG.
class WhatsAppGlyph extends StatelessWidget {
  const WhatsAppGlyph({super.key, this.size = 18, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BubblePainter(color),
          child: Center(child: Icon(Icons.call, size: size * 0.48, color: color)),
        ),
      );
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeJoin = StrokeJoin.round;
    final c = Offset(s / 2, s / 2);
    final r = s * 0.42;
    // Cercle ouvert en bas à gauche, refermé par une petite queue.
    final ring = Path()..addArc(Rect.fromCircle(center: c, radius: r), 2.4, 5.6);
    canvas.drawPath(ring, stroke);
    final start = c + Offset.fromDirection(2.4, r);
    final end = c + Offset.fromDirection(2.4 + 5.6 - 6.2832, r);
    final tail = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(s * 0.06, s * 0.94)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(tail, stroke);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color;
}

/// Variante pour sa propre annonce.
class ManageCapsule extends StatelessWidget {
  const ManageCapsule({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _CapsuleShell(child: _LaitonPill(label: "Gérer l'annonce", onTap: onTap));
}

class _CapsuleShell extends StatelessWidget {
  const _CapsuleShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(color: WellyColors.ink.withValues(alpha: 0.25), blurRadius: 28, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: WellyColors.ink.withValues(alpha: 0.92),
              child: Padding(padding: const EdgeInsets.all(5), child: child),
            ),
          ),
        ),
      );
}

class _LaitonPill extends StatelessWidget {
  const _LaitonPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: WellyColors.laiton,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            child: Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: WellyColors.ink)),
          ),
        ),
      );
}
