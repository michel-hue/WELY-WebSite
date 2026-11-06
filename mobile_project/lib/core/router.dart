import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/explore/explore_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/listing/listing_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/requests/requests_screen.dart';
import '../features/seller/editor/editor_screen.dart';
import '../features/seller/manage_listing_screen.dart';
import 'shell/home_shell.dart';

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
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfileScreen(key: Key('tab-profile')),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (_, state) => ListingScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      // Avant `/seller/listings/:id` : sinon « new » serait pris pour un identifiant.
      GoRoute(
        path: '/seller/listings/new',
        builder: (_, _) => const ListingEditorScreen(),
      ),
      GoRoute(
        path: '/seller/listings/:id',
        builder: (_, state) => ManageListingScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/seller/listings/:id/edit',
        builder: (_, state) => ListingEditorScreen(id: state.pathParameters['id']!),
      ),
    ],
  );
});
