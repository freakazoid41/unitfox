import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sitemanager/data/language_store.dart';
import 'package:sitemanager/data/site_store.dart';
import 'package:sitemanager/screens/onboarding_screen.dart';
import 'package:sitemanager/utils/money.dart';

/// Regression for the Accounts-step cash row design (Sep 2026):
/// the "Cash (main)" card must share the bank rows' two-line ListTile design —
/// same leading icon slot, no forced isThreeLine height, and the subtitle in
/// the same "{CCY} · {Opening} {amount}" shape (no lowercase one-off format,
// no empty bank/iban gap).
void main() {
  testWidgets('onboarding cash row matches bank row design',
      (tester) async {
    final site = SiteStore(usePersistence: false);
    await site.load();
    final lang = LanguageStore(usePersistence: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: site),
          ChangeNotifierProvider.value(value: lang),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1 (Site): fill the required property name, keep defaults otherwise.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Apartment / property name *'),
        'FoxTest');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2 (Accounts): cash card must be present with unified subtitle.
    expect(find.text('Cash (main)'), findsOneWidget);
    final expectedCash =
        'EUR · Opening balance ${money(0, currency: 'EUR')}';
    expect(find.text(expectedCash), findsOneWidget);

    // Cash tile: two-line (no forced three-line height).
    final cashTile =
        tester.widget<ListTile>(find.ancestor(
      of: find.text('Cash (main)'),
      matching: find.byType(ListTile),
    ));
    expect(cashTile.isThreeLine, isNot(isTrue));
    expect(cashTile.leading, isA<Icon>());

    // Add a bank account with empty bank name / iban — subtitle must not
    // contain a doubled separator or stray gap.
    await tester.tap(find.text('Add bank account'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Account name *'), 'TestBank');
    await tester.enterText(
        find.widgetWithText(TextField, 'Opening balance'), '100');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('TestBank'), findsOneWidget);
    final bankTile = tester.widget<ListTile>(find.ancestor(
      of: find.text('TestBank'),
      matching: find.byType(ListTile),
    ));
    expect(bankTile.leading, isA<Icon>());
    expect(bankTile.isThreeLine, isNot(isTrue));
    final bankSubtitle = tester.widget<Text>(find.descendant(
      of: find.ancestor(
          of: find.text('TestBank'), matching: find.byType(ListTile)),
      matching: find.byType(Text),
    ).at(1));
    expect(bankSubtitle.data, isNot(contains('  ')));
    expect(bankSubtitle.data, startsWith('EUR · Opening balance'));
  });
}
