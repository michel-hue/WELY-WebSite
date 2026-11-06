import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_service.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

class WellyApp extends ConsumerWidget {
  const WellyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushLifecycleProvider);
    return MaterialApp.router(
      title: 'WELLY',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
