import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_project/app.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/features/notifications/notifications_repository.dart';
import 'package:mobile_project/features/notifications/notifications_screen.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_explore.dart';
import '../helpers/fake_notifications.dart';

Future<FakeNotificationsRepository> pumpNotifications(WidgetTester tester, FakeNotificationsRepository repo) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/start', routes: [
    GoRoute(
      path: '/start',
      builder: (context, _) => Scaffold(
        body: TextButton(onPressed: () => context.push('/notifications'), child: const Text('Ouvrir')),
      ),
    ),
    GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
    GoRoute(path: '/requests', builder: (_, _) => const Scaffold(body: Text('Onglet Demandes'))),
    GoRoute(path: '/listing/:id', builder: (_, s) => Scaffold(body: Text('Fiche ${s.pathParameters['id']}'))),
    GoRoute(path: '/seller/listings/:id', builder: (_, s) => Scaffold(body: Text('Gérer ${s.pathParameters['id']}'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(() => FakeAuthSession(initial: signedInUser())),
      notificationsRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('tapping an unread notification marks it read and opens Demandes', (tester) async {
    final repo = await pumpNotifications(
      tester,
      FakeNotificationsRepository(items: [
        sampleNotification(id: 'n1', title: 'Nouvelle demande'),
        sampleNotification(id: 'n2', title: 'Demande acceptée', type: 'request_accepted', read: true),
      ]),
    );
    expect(find.text('Nouvelle demande'), findsOneWidget);
    expect(find.text('Demande acceptée'), findsOneWidget);
    expect(find.byKey(const Key('unread-n1')), findsOneWidget);
    expect(find.byKey(const Key('unread-n2')), findsNothing);

    await tester.tap(find.text('Nouvelle demande'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['read:n1']);
    expect(find.text('Onglet Demandes'), findsOneWidget);
  });

  testWidgets('a read notification does not call markRead; listing_expired opens the listing management', (tester) async {
    final repo = await pumpNotifications(
      tester,
      FakeNotificationsRepository(items: [
        sampleNotification(id: 'n3', title: 'Annonce expirée', type: 'listing_expired', requestId: null, read: true),
      ]),
    );
    await tester.tap(find.text('Annonce expirée'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.text('Gérer l1'), findsOneWidget);
  });

  testWidgets('« Tout marquer comme lu » calls markAllRead and clears the dots', (tester) async {
    final repo = await pumpNotifications(
      tester,
      FakeNotificationsRepository(items: [sampleNotification(id: 'n1'), sampleNotification(id: 'n2')]),
    );
    expect(find.byKey(const Key('unread-n1')), findsOneWidget);
    await tester.tap(find.text('Tout marquer comme lu'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['readAll']);
    expect(find.byKey(const Key('unread-n1')), findsNothing);
    expect(find.byKey(const Key('unread-n2')), findsNothing);
  });

  testWidgets('offline: soft error with « Réessayer »', (tester) async {
    final repo = await pumpNotifications(
      tester,
      FakeNotificationsRepository(items: [sampleNotification()], error: const ApiError.network()),
    );
    expect(find.text(networkMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
    repo.error = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle demande'), findsOneWidget);
  });

  test('unreadCountProvider is 0 when anonymous without calling the API', () async {
    final repo = FakeNotificationsRepository(unread: 5);
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(() => FakeAuthSession()),
      notificationsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(unreadCountProvider.future), 0);
    expect(repo.unreadCalls, 0);
  });

  test('unreadCountProvider fetches the count when signed in, 0 on error', () async {
    final repo = FakeNotificationsRepository(unread: 5);
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(() => FakeAuthSession(initial: signedInUser())),
      notificationsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(unreadCountProvider.future), 5);

    repo.error = const ApiError.network();
    container.invalidate(unreadCountProvider);
    expect(await container.read(unreadCountProvider.future), 0);
  });

  testWidgets('the Profil tab shows an unread dot', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...exploreOverrides(repo: FakeListingsRepository()),
        unreadCountProvider.overrideWith((ref) async => 2),
      ],
      child: const WellyApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-unread-dot')), findsOneWidget);
  });
}
