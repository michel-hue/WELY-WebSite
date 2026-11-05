import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'shell/home_shell.dart';
import 'shell/tab_placeholder.dart';

StatefulShellBranch _tab(String path, Key key, String before, String serif) {
  return StatefulShellBranch(routes: [
    GoRoute(
      path: path,
      builder: (_, _) =>
          TabPlaceholder(key: key, before: before, serif: serif),
    ),
  ]);
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/explore',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          _tab('/explore', const Key('tab-explore'), 'Explorer les ',
              'annonces'),
          _tab('/favorites', const Key('tab-favorites'), 'Vos ', 'favoris'),
          _tab('/requests', const Key('tab-requests'), 'Vos ', 'demandes'),
          _tab('/profile', const Key('tab-profile'), 'Votre ', 'profil'),
        ],
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('Annonce ${state.pathParameters['id']}')),
        ),
      ),
    ],
  );
});
