import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/app.dart';

import '../helpers/fake_explore.dart';

void main() {
  testWidgets('shows the four tabs and switches to Profil', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: exploreOverrides(repo: FakeListingsRepository()),
      child: const WellyApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tab-explore')), findsOneWidget);
    for (final label in ['Explorer', 'Favoris', 'Demandes', 'Profil']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tab-profile')), findsOneWidget);
  });
}
