import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/explore/explore_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/listing/listing_screen.dart';
import '../features/requests/requests_screen.dart';
import '../features/seller/manage_listing_screen.dart';
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
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/explore',
              builder: (_, _) => const ExploreScreen(key: Key('tab-explore')),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/favorites',
              builder: (_, _) => const FavoritesScreen(key: Key('tab-favorites')),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/requests',
              builder: (_, _) => const RequestsScreen(key: Key('tab-requests')),
            ),
          ]),
          _tab('/profile', const Key('tab-profile'), 'Votre ', 'profil'),
        ],
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (_, state) => ListingScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/seller/listings/:id',
        builder: (_, state) => ManageListingScreen(id: state.pathParameters['id']!),
      ),
    ],
  );
});
