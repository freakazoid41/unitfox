import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sitemanager/data/account_store.dart';
import 'package:sitemanager/data/expense_store.dart';
import 'package:sitemanager/data/fx_store.dart';
import 'package:sitemanager/data/language_store.dart';
import 'package:sitemanager/data/site_store.dart';
import 'package:sitemanager/data/staff_store.dart';
import 'package:sitemanager/data/unit_store.dart';
import 'package:sitemanager/data/work_order_store.dart';
import 'package:sitemanager/main.dart';

void main() {
  testWidgets('Site Manager renders dashboard',
      (tester) async {
    final store = WorkOrderStore(usePersistence: false);
    await store.load();
    final units = UnitStore(usePersistence: false);
    await units.load();
    final expenses = ExpenseStore(usePersistence: false);
    await expenses.load();
    final accounts = AccountStore(usePersistence: false);
    await accounts.load();
    final site = SiteStore(usePersistence: false);
    await site.load();
    final fx = FxStore();
    final staff = StaffStore(usePersistence: false);
    await staff.load();
    final lang = LanguageStore(usePersistence: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: site),
          ChangeNotifierProvider.value(value: fx),
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: units),
          ChangeNotifierProvider.value(value: expenses),
          ChangeNotifierProvider.value(value: accounts),
          ChangeNotifierProvider.value(value: staff),
          ChangeNotifierProvider.value(value: lang),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );

    expect(find.textContaining('Sunset Villa'), findsOneWidget);
  });
}
