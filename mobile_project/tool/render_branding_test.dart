// Régénère les PNG sources de l'icône : `flutter test tool/render_branding_test.dart`
// puis `dart run flutter_launcher_icons` et `dart run flutter_native_splash:create`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/core/theme/tokens.dart';
import 'package:mobile_project/core/widgets/welly_logo.dart';

Future<void> _render(WidgetTester tester, String path, {required Color? background, required double logo}) async {
  const side = 1024.0;
  final key = GlobalKey();
  tester.view.physicalSize = const Size(side, side);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      key: key,
      child: Container(
        width: side,
        height: side,
        color: background,
        alignment: Alignment.center,
        child: WellyLogo(size: logo),
      ),
    ),
  ));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render branding', (tester) async {
    await _render(tester, 'assets/branding/icon.png', background: WellyColors.ivoire, logo: 640);
    await _render(tester, 'assets/branding/icon_foreground.png', background: null, logo: 560);
    await _render(tester, 'assets/branding/splash_logo.png', background: null, logo: 512);
  });
}
