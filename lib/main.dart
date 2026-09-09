import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/account_store.dart';
import 'data/expense_store.dart';
import 'data/fx_store.dart';
import 'data/language_store.dart';
import 'data/local_db.dart';
import 'data/site_store.dart';
import 'data/staff_store.dart';
import 'data/unit_store.dart';
import 'data/work_order_store.dart';
import 'l10n/app_strings.dart';
import 'screens/account_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/properties_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/staff_screen.dart';
import 'screens/units_screen.dart';
import 'screens/work_orders_screen.dart';
import 'theme.dart';
import 'widgets/bottom_menu_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDB.open();
  runApp(const SiteManagerApp());
}

class SiteManagerApp extends StatelessWidget {
  const SiteManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SiteStore()),
        ChangeNotifierProvider(create: (_) => FxStore()),
        ChangeNotifierProvider(create: (_) => WorkOrderStore()),
        ChangeNotifierProvider(create: (_) => UnitStore()),
        ChangeNotifierProvider(create: (_) => ExpenseStore()),
        ChangeNotifierProvider(create: (_) => AccountStore()),
        ChangeNotifierProvider(create: (_) => StaffStore()),
        ChangeNotifierProvider(create: (_) => LanguageStore()),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Unitfox',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          locale: context.watch<LanguageStore>().locale,
          supportedLocales: LanguageStore.supported,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _showSplash = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitial();
    });
  }

  Future<void> _loadInitial() async {
    try {
      await context.read<SiteStore>().load();
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
    try {
      await context.read<LanguageStore>().load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onComplete: () {
          if (mounted) setState(() => _showSplash = false);
        },
      );
    }
    final site = context.watch<SiteStore>();
    if (_loadError) {
      return Scaffold(
        backgroundColor: AppBrand.charcoal,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load data',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  setState(() { _loadError = false; });
                  _loadInitial();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (!site.isLoaded) {
      return Scaffold(
        backgroundColor: AppBrand.charcoal,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/fox_logo.png',
                width: 140,
                height: 140,
                errorBuilder: (_, _, _) => Icon(
                  Icons.pets,
                  size: 120,
                  color: AppBrand.gradient[0],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'UnitFox',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Smart Apartment Management',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'Welcome to UnitFox',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              CircularProgressIndicator(
                color: AppBrand.gradient[0],
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      );
    }
    if (!site.onboarded) {
      return const OnboardingScreen();
    }
    return const HomeShell();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int? _loadedProperty;
  int _loadGen = 0;
  int _loadFailures = 0;
  int _page = 0;

  static final _screens = [
    const DashboardScreen(),
    const UnitsScreen(),
    const WorkOrdersScreen(),
    const FinanceScreen(),
    const AccountScreen(),
    const StaffScreen(),
  ];

  Future<void> _loadForProperty(SiteStore site, int propertyId) async {
    final gen = ++_loadGen;
    final units = context.read<UnitStore>();
    final accounts = context.read<AccountStore>();
    final expenses = context.read<ExpenseStore>();
    final orders = context.read<WorkOrderStore>();
    final staff = context.read<StaffStore>();
    final fx = context.read<FxStore>();
    // Fix the charge currency BEFORE the stores load: load() auto-bills the
    // current month, and billing under the previous property's currency would
    // leave ledgers denominated in the wrong units until the next recompute.
    units.setBaseCurrency(site.mainCurrency);
    try {
        await Future.wait([
          units.load(propertyId: propertyId),
          accounts.load(propertyId: propertyId),
          expenses.load(propertyId: propertyId),
          orders.load(propertyId: propertyId),
          staff.load(propertyId: propertyId),
        ]);
      } catch (e) {
        // A failed store load must never crash the shell. The post-frame
        // caller has no error boundary, so swallow and let the UI show its
        // loading states again rather than throwing into the zone. Retry a
        // bounded number of times before giving up (a transient DB hiccup
        // shouldn't strand the property in a permanent spinner).
        debugPrint('HomeShell: failed to load property $propertyId: $e');
        if (_loadFailures < 3 && mounted) {
          _loadFailures++;
          setState(() => _loadedProperty = null);
        }
        return;
      }
    if (gen != _loadGen || !mounted) return;
    _loadFailures = 0;
    unawaited(fx.refresh(site.mainCurrency));
  }

  void _showMenuGrid(BuildContext context) {
    final s = strings(context);
    final items = [
      _MenuItem(Icons.home, s.t('nav.dashboard'), 0, iconAsset: 'assets/dashboard_icon.png'),
      _MenuItem(Icons.apartment, s.t('section.units'), 1, iconAsset: 'assets/units_icon.png'),
      _MenuItem(Icons.build, s.t('nav.workOrders'), 2, iconAsset: 'assets/workorders_icon.png'),
      _MenuItem(Icons.receipt_long, s.t('nav.finance'), 3, iconAsset: 'assets/finance_icon.png'),
      _MenuItem(Icons.account_balance, s.t('nav.accounts'), 4, iconAsset: 'assets/accounts_icon.png'),
      _MenuItem(Icons.people, s.t('nav.crew'), 5, iconAsset: 'assets/crew_icon.png'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => LayoutBuilder(
        builder: (ctx, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 480
              ? 4
              : width >= 360
                  ? 3
                  : 2;
          final iconSize = width >= 480
              ? 72.0
              : width >= 360
                  ? 64.0
                  : 56.0;
          final labelSize = width >= 480 ? 12.0 : 11.0;
          return Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final isSelected = _page == item.index;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _page = item.index);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppBrand.gradient[0].withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppBrand.gradient[0]
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              flex: 0,
                              child: item.iconAsset != null
                                  ? Image.asset(
                                      item.iconAsset!,
                                      width: iconSize,
                                      height: iconSize,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Icon(
                                        item.icon,
                                        size: iconSize,
                                        color: isSelected
                                            ? AppBrand.gradient[0]
                                            : Colors.grey.shade600,
                                      ),
                                    )
                                  : Icon(
                                      item.icon,
                                      size: iconSize,
                                      color: isSelected
                                          ? AppBrand.gradient[0]
                                          : Colors.grey.shade600,
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Flexible(
                              flex: 0,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: Text(
                                  item.label,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: labelSize,
                                    height: 1.1,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppBrand.gradient[0]
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPropertySwitcher(BuildContext context) {
    final site = context.read<SiteStore>();
    final s = strings(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in site.properties)
                      ListTile(
                        leading: Icon(
                          p.id == site.activePropertyId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 22,
                          color: p.id == site.activePropertyId
                              ? AppBrand.gradient[0]
                              : Colors.grey.shade400,
                        ),
                        title: Text(p.name),
                        subtitle: Text(p.currency),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (p.id != site.activePropertyId) {
                            site.switchProperty(p.id);
                          }
                        },
                      ),
                    const Divider(height: 16),
                    ListTile(
                      leading: Icon(Icons.settings_outlined,
                          size: 22, color: Theme.of(ctx).colorScheme.primary),
                      title: Text(s.t('Manage properties')),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                              builder: (_) => const PropertiesScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final site = context.watch<SiteStore>();
    final propertyId = site.activePropertyId;
    if (propertyId != null && propertyId != _loadedProperty) {
      _loadedProperty = propertyId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadForProperty(site, propertyId);
      });
    }
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _page,
            children: _screens,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: BottomMenuBar(
                  onMenuPressed: () => _showMenuGrid(context),
                  onSwitcherPressed: () => _showPropertySwitcher(context),
                  onSettingsPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String? iconAsset;
  final String label;
  final int index;

  const _MenuItem(this.icon, this.label, this.index, {this.iconAsset});
}
