# Site Manager — Project Memory

> Handoff file so a future session can pick up instantly. Read this first.

## Project

**What:** Mobile-first apartment / site manager app (manager only, not tenants/landlords).
**Stack:** Flutter 3.41.2 / Dart 3.11, Provider (state), sqflite (local SQLite), Material 3.
**Platforms:** iOS + Android + Web. Real-device testing on **iPhone 13** (`Kurtaranın iPhone'u`, bundle `com.princeofpersia41.sitemanager`, team `5785G2M882`).
**Vibe:** Fully **offline-first** — no server, no sync. SQLite is the single source of truth. Light mode only (dark mode removed).

## Current Status (done)

### Architecture
```
lib/
├── main.dart                  → MultiProvider (8 stores), CurvedNavigationBar in Stack overlay (Menu button → grid modal),
│                                floating menu grid modal (6 nav items)
├── models/
│   ├── work_order.dart        → work order (priority/status/assignedTo/copyWith + proofBytes Uint8List)
│   ├── unit.dart              → unit + Occupant (name/phone JSON list), isRented, fromRow/toRow
│   ├── payment.dart           → Payment + UnitCharge; PaymentType consts (Aidat/Yakıt/Diğer)
│   ├── expense.dart           → expense + attachment BLOB/name + staffId/salaryMonth
│   ├── account.dart           → Account (bank/cash, currency, IBAN, opening) + currencies list
│   │                           currencies: EUR, USD, TRY, GBP, INR, RUB
│   └── staff_member.dart      → crew member: name, role, phone, salary, dispatchLabel
├── data/
│   ├── local_db.dart          → ALL SQLite. Tables: properties, work_orders, units, charges,
│   │                             payments, expenses, accounts, staff, settings. Schema v14 + _migrate().
│   │                             v10: occupiers TEXT + is_rented INTEGER. v11: proof_data BLOB.
│   │                             v13: ALL money columns rebuilt REAL→INTEGER (exact cents).
│   │                             v14: properties.address column added; work_orders.updated_at added.
│   │                             DDL lives in `_tableDdl` map; fresh DBs create INTEGER money.
│   │                             + deletePayment() for removing income transactions
│   ├── unit_store.dart        → units + per-unit UnitLedger, baseCurrency, memoized ledgers
│   │                             + allPayments, totalCharged/totalOutstanding/totalIncome getters
│   │                             + monthBalancesAll(): per-month balances with credit CARRY-FORWARD
│   │                             + removeUnit() for deleting units + removePayment/removePayments
│   │                             + auto-bills current month on load() + addUnit() for occupied units
│   │                             + recordPayment auto-posts charge if missing for that month
│   │                             + postAllMonthlyCharges: ORDER BY id ASC (was DESC — critical fix)
│   │                             + ledgerFor() returns nullable UnitLedger? (callers use fallback)
│   ├── account_store.dart     → accounts + memoized balances + transactions Txn log
│   │                             + defaultTransactionAccount getter + removePayment()
│   │                             + deleteAccount returns List<int> of removed payment IDs (cascade)
│   │                             + balanceFor() returns nullable (callers use fallback)
│   ├── expense_store.dart     → expenses CRUD + paySalary()
│   ├── work_order_store.dart  → work orders, dispatch/complete with raw BLOB proof bytes
│   ├── staff_store.dart       → crew CRUD, seeds default crew pre-onboarding only
│   │                             + update() renames assignedTo on matching work orders
│   │                             + remove() clears assignedTo on matching work orders
│   ├── site_store.dart        → MULTI-PROPERTY: portfolio of buildings (name/address/currency),
│   │                             active property = display currency; onboarding, switch, CRUD
│   ├── fx_store.dart          → FX rates (open.er-api.com), 1h TTL, mem+DB cache, offline fallback
│   │                             + convert() always uses multiplication path for consistency
│   ├── language_store.dart    → 6-language (EN/TR/RU/FR/DE/HI), auto-detect device locale,
│   │                             persist via settings
│   └── db_factory_io/_web.dart → platform DB factory resolution
├── l10n/
│   └── app_strings.dart       → AppStrings (200+ keys × 6 languages), t()/ls() helpers
│                                Includes: incomeType.aidat/fuel/other, dashboard.leaseRenewals/
│                                rentPayments/maintenance/active, finance.monthlyTxns/
│                                awaitingExpenses, unit.deleteMsg
├── screens/
│   ├── onboarding_screen.dart   → 3-step wizard (property/accounts/units), theme-consistent inputs
│   │                             + confirm modals on bank/unit draft removal
│   ├── properties_screen.dart   → portfolio mgmt: add/edit/delete buildings, currency sync
│   │                             + GUARDED currency change (confirm when the active ledger has data)
│   ├── rent_grid_screen.dart    → 12-month rent grid per unit (current + 11 forward), carry-aware
│   │                             month cells (paid/partial/unpaid), month detail sheet
│   ├── dashboard_screen.dart    → hero header (banner_icon.png on top of teal banner, overflowing),
│   │                             2 overview cards (units + occupancy %), 2 key cards (Active Crew
│   │                             count + Monthly Expense), 5 stat cards (2-2-1 grid):
│   │                             Awaiting Incomes, Awaiting Crew, Monthly Income, Monthly Expense,
│   │                             Monthly Transactions. AdMob banner card between "Bu Ay" header
│   │                             and first stat card.
│   ├── units_screen.dart        → dedicated screen with unit list, add/edit/delete
│   │                             Card layout matching account_screen (CircleAvatar header + financials box)
│   ├── work_orders_screen.dart  → list + summary chips + FormDialog new order + delete on rows
│   ├── work_order_detail_screen.dart → priority/status badges, info rows, tappable proof image
│   │                                   → raw BLOB storage + AttachmentViewerScreen for pinch-zoom
│   ├── finance_screen.dart      → 5 stat cards (2-2-1 grid) + awaiting units list + crew list
│   │                              + Record Income / Add Expense buttons + transactions link
│   │                              + "Post monthly charges" button wired (auto-bills current month)
│   ├── transactions_screen.dart → combined income/expense log + filters + delete + attachment viewer
│   │                              + confirm dialog on delete + cascades to UnitStore/AccountStore
│   ├── account_screen.dart      → vertical card layout (responsive for small screens) + PopupMenuButton
│   │                              + confirm dialog on delete + syncs UnitStore.removePayments
│   ├── staff_screen.dart        → ListTile + PopupMenuButton (edit/delete/pay salary)
│   ├── settings_screen.dart     → language picker (6 langs with drawn country flags) + About card
│   └── attachment_viewer_screen.dart → view image (InteractiveViewer) / download PDF
├── utils/
│   ├── money.dart              → money() + tryParseMoney() + moneySymbol() (EUR/USD/TRY/GBP/INR/RUB)
│   ├── money_input.dart        → MoneyInputFormatter (smart comma-as-decimal, no thousands grouping)
│   │                             + PhoneInputFormatter + moneyKeyboardType (TextInputType.text everywhere)
│   ├── download_bytes_*.dart   → browser download (web) / temp write (io)
│   └── metrics.dart            → SHARED monthly rollups (income/expenses/awaiting salaries/
│                                 txn count) + nonBaseCredits() for FX-currency payment credits
├── assets/
│   ├── fox_logo.png, fox_wallet.png, fox_avatar.png → fox branding
│   ├── appicon.png              → splash screen logo (centered, 320x320, animated upward on load)
│   ├── banner_icon.png         → hero header icon (placed on top of teal banner, overflowing)
│   ├── dashboard_icon.png      → menu grid dashboard item
│   ├── units_icon.png          → menu grid units item
│   ├── workorders_icon.png     → menu grid work orders item
│   ├── finance_icon.png        → menu grid finance item
│   ├── accounts_icon.png       → menu grid accounts item
│   └── crew_icon.png           → menu grid crew item
└── widgets/
    ├── active_property_label.dart → passive app-bar label (apartment icon + active property name, no menu; switching is via the dock's left shoulder)
    ├── language_flag.dart         → LanguageFlag chip — flags DRAWN via CustomPaint (no emoji/assets),
    │                                identical on iOS/Android/Web. en=Union Jack, tr=crescent+star,
    │                                ru/fr/de tricolors, hi=saffron/white/green + navy chakra ring
    ├── stat_card.dart             → shared KPI tile (tinted icon badge + bold value + label)
    │                                supports onTap for tappable cards (finance monthly txns)
    │                                + plain mode for count-only display
    │                                + optional caption line (e.g. "Paid in other currencies …")
    ├── ad_banner_card.dart        → AdMob banner: real BannerAd+AdWidget when loaded, styled placeholder on failure
    ├── form_scaffold.dart         → FormDialog (icon header + scroll body + actions) + FieldSection
    └── attachment_picker.dart     → image/PDF attach for income/expense
```

### Design System
- **Theme:** `AppTheme` seed `0xFFF26522` (fox orange); `AppBrand.gradient` orange FF7A2E→E85D1C,
  `AppBrand.tealGradient` 2AB7A4→1D8A7A (hero + wide cards). Light canvas = warm cream `0xFFFAF6F1`.
  Light mode ONLY — dark mode removed.
- **Hero header:** teal-gradient with `banner_icon.png` placed ON TOP of the banner (overflowing via Stack + Positioned).
- **Dashboard stat cards:** horizontal layout (circular icon left, value+label right), colored soft shadows.
- **Dashboard key cards:** orange-red gradient for Monthly Expense (spent), people icon for Active Crew (count).
- **Bottom navigation:** `CurvedNavigationBar` with charcoal background + orange button. Single Menu button → opens floating menu grid (6 nav items with custom PNG icons). Lives inside a `Stack` in the Scaffold body (not `bottomNavigationBar` property) — positioned at bottom via `Positioned`, transparent background, dashboard scroll content pads 76px below to clear it.
- **Floating menu grid:** modal bottom sheet with 6 navigation items (3×2 grid), custom icons for each.
- **Account cards:** vertical layout for small screens (responsive), balance section with tinted container.
  Card pattern: CircleAvatar header + full-width financials box.
- **Unit cards:** Card pattern matching accounts — CircleAvatar badge + unit info + PopupMenuButton,
  full-width financials box (monthly charge + status pill + due pill).
- **Staff cards:** ListTile + PopupMenuButton for actions (edit/delete/pay salary).
- **Work order cards:** dark header bar with delete icon + priority badge, translated priority labels.
- **Forms:** all dialogs use `FormDialog` (icon header + subtitle + scroll body) + `FieldSection`
- **Controls:** `SegmentedButton` for status, usage type, payment type, bank/cash kind
- **AppBars:** centerTitle, no elevation, scrolledUnderElevation 0.5

### Features delivered
- **Splash screen:** charcoal background with centered `icons/appicon.png` logo (320x320). Logo smoothly animates upward 60px when loading text fades in. No background image.
- **CurvedNavigationBar:** bottom bar with single Menu button (charcoal + orange), tapping opens the floating menu grid. Lives in Stack overlay inside Scaffold body (not bottomNavigationBar property).
- **Floating menu grid:** modal bottom sheet with 6 navigation items, custom icons per screen.
- **Hero header:** banner_icon.png placed on top of teal banner via Stack + Positioned (overflowing).
- **Dashboard stat cards:** 5 cards in 2-2-1 grid (Awaiting Incomes, Awaiting Crew, Monthly Income, Monthly Expense, Monthly Transactions).
- **Dashboard key cards:** Active Crew (crew count), Monthly Expense (spent amount), Maintenance (count).
- **Finance screen:** simplified — 5 stat cards + awaiting units list + crew list + Record Income/Add Expense buttons + transactions link + "Post monthly charges" button.
- **Units screen:** dedicated screen with Card-style unit list (matching account_screen pattern), add/edit/delete.
- **6-language l10n** (EN/TR/RU/FR/DE/HI): income type translations (Aidat/Yakıt/Diğer), dashboard labels, finance labels.
- **Currencies:** EUR, USD, TRY, GBP, INR (₹), RUB (₽) — full symbol support in money formatter.
- **Money input:** fixed formatter for dot/comma handling, `TextInputType.text` on all platforms (avoids browser-locale issues).
- **Transaction deletion:** payments and expenses can be deleted from transactions screen via PopupMenuButton. All deletions require confirm dialog.
- **Crew screen:** redesigned with ListTile + PopupMenuButton (edit/delete/pay salary), no more tiny action buttons.
- **Settings screen (Aug 2026):** opened via the **gear icon on the dock bar's right shoulder** (apartment switcher lives on the left shoulder since Aug 2026) (`BottomMenuBar.onSettingsPressed`, `right:34/bottom:16`, white70 icon + press-scale/haptic). Language picker = 6 ListTiles with drawn `LanguageFlag` chips, native names + check on active; About card. PropertySwitcher dropdown is now properties-only — **screenshot workflow language switch is now: dock gear → Settings → tap language** (force-stop + relaunch still required after switching). New l10n keys in all 6 langs: `settings.title`/`settings.langIntro`/`settings.about`/`settings.aboutBody`. On PixelPlay (1080×2400) gear tap target centers ≈ **(930, 2235)**; menu dock button ≈ (540, 2231).
- **Top bar (Aug 2026):** `PropertySwitcher` dropdown removed — `ActivePropertyLabel` (apartment icon + active name, no menu/chevron) in every screen's `AppBar.actions`. Property switching now only on the dock's left shoulder.
- **Account cards:** vertical responsive layout for small screens, balance section with tinted container. Delete cascades to UnitStore.
- **Work order delete:** delete button on list rows + translated priority labels.
- **Onboarding:** theme-consistent inputs (removed OutlineInputBorder, hint text). Bank/unit draft removals require confirm.
- **Custom icons:** dashboard, units, workorders, finance, accounts, crew — all custom PNGs in menu grid.
- **Awaiting incomes:** auto-bills current month on app load + addUnit + recordPayment. No manual post step needed.
- **Rent grid screen:** per-unit 12-month grid (current + 11 forward) with paid/partial/unpaid month cells, month detail sheet, foreign-currency credits surfaced on the Awaiting cards.
- **AdMob banner:** `google_mobile_ads ^9.1.0` + `AdBannerCard` widget in the dashboard, placed between "Bu Ay" section header and the first stat card. Real production IDs live in `lib/ads/ads_config.dart` with `isProduction = true`. iOS `ca-app-pub-1088997129209291~8191655637` / banner `ca-app-pub-1088997129209291/4361734608`, Android `ca-app-pub-1088997129209291~5559266208` / banner `ca-app-pub-1088997129209291/6579191064`. Config also in Info.plist (`GADApplicationIdentifier`) + AndroidManifest (`APPLICATION_ID`). `MobileAds.instance.initialize()` is NOT called in main() — SDK v9+ auto-initializes on first ad request. Widget shows real `BannerAd` + `AdWidget` when loaded, styled placeholder (AD badge + "Sponsored" text) as fallback when ad fails. No crashes, no freezes. **Test verified:** Google test banner (`ca-app-pub-3940256099942544/6300978111`) loads and renders correctly on iOS. **Status:** AdMob console shows "İnceleme gerekli" (Review required) for UnitFox iOS — production ads won't serve until Google approves. **Note Sep 2026:** ad load rate noticeably up on device testing — placement + refresh may matter more now. Next: guarantee visibility (post-frame load retry, anchored placement, no lazy-load, refresh 30–60s).
- **TODO ads (Sep 2026):** make the banner **reliably seen** — verify dashboard load isn't racing the AdWidget, confirm the banner is above the fold on small screens, add a timed retry on `onAdFailedToLoad`, consider anchored bottom placement or sticky header so scroll never hides it, and tune refresh via AdMob console. Goal: every session sees an impression even on slow/ad-blocked networks.

### QA fixes (latest session)
- **Nav bar:** CurvedNavigationBar now lives in a `Stack` overlay inside Scaffold body (not `bottomNavigationBar`). Positioned at bottom with `Positioned(left: 0, right: 0, bottom: 0)`. Transparent background, dashboard scroll pads 76px below to clear it.
- **postAllMonthlyCharges:** ORDER BY id DESC → ASC (was returning wrong IDs for multi-unit billing).
- **recordPayment:** removed double `DateTime.now()` — single `paidAt` for consistency.
- **deleteAccount:** returns `List<int>` of removed payment IDs. Cascades removes to UnitStore/AccountStore.
- **transactions_screen:** captures stores before async gap (fixes use_build_context_sissors). Income/expense deletes sync UnitStore/AccountStore.
- **finance_screen:** monthlyIncome & monthlyExpenses now FX-convert like dashboard (were raw currency amounts).
- **expense_store:** added `_loadGen` guard against stale loads.
- **UnitLedger → per-month carry-forward:** `outstanding` is now the sum of `remaining` across `UnitMonthBalance` rows (monthly credit rolls forward). Rent grid and arrears summary read the SAME numbers — an overpayment in March now genuinely covers April.
- **Foreign-currency credits surfaced:** `metrics.nonBaseCredits()` (payments not in base, converted) shown as a StatCard caption ("Paid in other currencies …") on dashboard + finance Awaiting cards.
- **Properties currency edit guarded:** changing an active property's currency now confirms first when the ledger already has data (same dialog keys as the account path). `fx.refresh` is now `unawaited`.
- **Dead code pruned:** `monthlyCharged` / `monthlyIncome` (+ caches), `vacantCount`, `ledgers` (public), `ExpenseStore.totalThisMonth`. `totalAll` kept (test-only, documented raw native-currency sum).
- **`AccountStore._loadScoped` / `refreshTransactions`:** gen-guarded between every sequential DB read (no stale property-mix after a switch).

- **Sub-page FABs:** All screens with FABs (units, work orders, accounts, staff) wrap them in `Padding(bottom: AppBrand.bottomPad)` so the floating action button clears the Stack-overlay nav bar. Finance screen has no FAB.

### Money/logic audit — 2nd pass (Aug 2026)
- **FX guess surfaced:** `monthlyIncomeGuessed`/`monthlyExpensesGuessed`'s `guessed` flag was thrown away on dashboard + finance — silent 1:1 fallback offline. Now shown as a `stat.approx` caption on the monthly income/expense cards (all 6 langs).
- **`recordPayment` auto-bill restricted to `PaymentType.aidat`** — posting the full monthly charge for a fuel/other payment inflated outstanding by (charge − payment).
- **`AccountStore._resolveAccount`:** an explicit `accountId` is now honored only when the account's currency matches the transaction; a mismatch counts on no balance (was: summed into a differently-denominated balance).
- **`tryParseMoney` comma fix:** a comma with >2 trailing digits is a thousands separator ("1,234" → 123400), matching `MoneyInputFormatter`. Was misparsing to 123. Regression tests added (`money_input_test`).
- **Salary partials enabled:** `ExpenseStore.paySalary` takes a `salary` cap, sums already-paid, blocks overpayment, allows top-up. Staff/finance "paid" badges now compare sums (≥ salary), consistent with `awaitingCrewSalaries`.
- **Rent grid:** future months with no posted charge render as neutral "Upcoming" cells with the projected rent instead of empty grey. Detail sheet gained a confirm-guarded "Remove charge" action (`UnitStore.removeCharge` + `LocalDB.deleteCharge`).
- **`StatCard`** now shares `money.moneyNumber()` (was a private duplicated formatter); dead `isDark` branches removed from stat_card + dashboard `_OverviewCard`.
- **HomeShell property-load retry:** transient store-load failures retry up to 3× instead of stranding the property in a permanent spinner.

### Full Audit & Fixes (Aug 2026)
43 issues identified (7 critical, 11 high, 19 medium, 6 low). All fixed and verified.

**Money & Currency:**
- `fx_store.convert()` — now always uses multiplication path (`_rates[from]`) for consistency; prevents different results depending on which base's rates are cached
- `metrics.dart` — `awaitingCrewSalaries` now sums partial payments via `.where().fold()` instead of `any()` boolean check

**Data Layer (`local_db.dart`):**
- `setSetting()` — uses atomic `INSERT OR REPLACE` upsert (was check-then-insert race)
- `reset()` — now closes the DB handle + nulls `_db` + clears `_openFuture` (prevents stale handle reuse)
- `_workOrderRow()` — includes `updated_at` column in SELECT (was silently dropped)
- `_migrate()` — adds missing `properties.address` column with ALTER TABLE
- `_rebuildMoneyColumns()` — uses `IF EXISTS` for backup drops (safe if table/column doesn't exist)

**Store Logic:**
- `main.dart` `_Root` — error state with retry button (was permanent loading spinner on SiteStore.load failure)
- `CurvedNavigationBar` index — tracked via `_page` variable (was hardcoded 0)
- `IndexedStack` — replaces direct `_screens[_page]` (preserves screen state across page switches)
- `_screens` list — changed from `const` to `final` (const destroys IndexedStack state)
- `account_store._loadScoped` — uses local variables before assignment (was referencing `this` during initialization)
- `account_store.balanceFor` / `unit_store.ledgerFor` — return nullable with `UnitLedger?` (was force-unwrapping)
- All callers updated with fallback defaults (`?? UnitLedger.empty()`, `?? 0`)

**Staff & Work Orders:**
- `staff_store.update()` — renames `assignedTo` on matching work orders when staff name changes
- `staff_store.remove()` — clears `assignedTo` on matching work orders before deletion

**Widget/UI Fixes:**
- `stat_card.dart` — all `!` force-unwraps replaced with null-safe `(textTheme.headlineSmall ?? const TextStyle())` pattern
- `work_order_detail_screen.dart` — `_fmt()` accepts `BuildContext` param (was using unavailable `context`); localized month names via `ls(context).t('month.*')`; localized year; `wo.notFound` key used instead of hardcoded string
- `dashboard_screen.dart` — `ValueKey('occ_${name}_$i')` instead of `ValueKey(i)` (prevents key collisions on reorder)
- `rent_grid_screen.dart` — `childAspectRatio: 1.15` (was 1.0, too cramped)

**L10N:**
- `wo.notFound` key added to all 6 languages (EN/TR/RU/FR/DE/HI)
- All `DropdownButtonFormField` kept as `initialValue:` (correct API on Flutter 3.33+; `value` is deprecated)
- Finance dialog `_isSaving = true` moved before validation (prevents double-tap race)
- Test `setUp` now `await`s `LocalDB.reset()` (prevents DB-closed race between tests)

**Reverted (correct original behavior):**
- Dropdown `initialValue` → `value` change was backwards; Flutter 3.33+ deprecated `value`, original `initialValue` was correct

### Conventions / gotchas
- **iOS build + AdMob:** Podfile pins `platform :ios, '15.0'`. google_mobile_ads 9.1.0 + GoogleMobileAds SDK 13.x hits a KNOWN non-modular header error (`FLTAdPreloader.h` → `GoogleMobileAds_Beta.h` moved to PrivateHeaders). Fix applied in TWO places — post_install `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES` on all pod targets AND the same flag injected into all 6 Runner build configs in `Runner.xcodeproj/project.pbxproj` (pod-target flag alone does NOT fix it). Should be resolvable by deleting the flag once the SDK ships the fix.
- **CocoaPods + GitHub 429:** this IP gets hard-blocked on raw.githubusercontent.com (429 for everything). If `pod install` fails on podspec downloads, surgical workaround: partial git clone of the specs repo (`git clone --filter=blob:none --sparse --depth 1 https://github.com/CocoaPods/Specs.git`) → `git sparse-checkout add "Specs/<dir>/<Pod>/<ver>"` → copy `*.podspec.json` (+ a fake `.etag`) into `~/.cocoapods/repos/trunk/Specs/...`. GitHub git protocol still works when raw is blocked.
- **Android Gradle + JDK:** Gradle 8.14 does NOT support JDK 25 (Android Studio 2026.1 bundles it). `gradle.properties` must pin `org.gradle.java.home` to JDK 20 at `/Library/Java/JavaVirtualMachines/temurin-20.jdk/Contents/Home`. Without this, build fails with `java.lang.IllegalArgumentException: 25.0.2`.
- Every store has `usePersistence: false` escape hatch — widget tests use it.
- Store loading: `HomeShell.build()` watches SiteStore; on active-property change reloads all scoped stores via `_loadForProperty` post-frame (`_loadGen` cancels stale loads). Do NOT call load() inside build().
- **Money:** ALL money is exact minor-unit `int` (cents) — in Dart AND in the DB (INTEGER columns since v13). Never floats for money. FX rates are the only doubles. `money()` formats, `tryParseMoney()` parses, both pure int/string math.
- **MoneyInputFormatter:** strips commas (no thousands grouping), only dot is decimal separator. Handles comma-as-decimal when ≤2 digits follow (Turkish locale support). Trailing dot preserved. `moneyKeyboardType` returns `TextInputType.text` on all platforms.
- Dates: epoch millis (INTEGER). Months: `'YYYY-MM'` strings.
- Memoization: `UnitStore` ledgers + `allPayments`, `AccountStore` balances + `_allTxns`. Invalidate on mutation; incremental memory write on `recordPayment`/`postMonthlyCharge`.
- `ownedByManagement` still in Unit model (backward compat) but no UI toggle — `isRented` drives logic. Editing preserves `ownedByManagement` from initial.
- `addUnit` must copy `occupiers` and `isRented` from the passed unit (not just old fields).
- `flutter analyze` clean (1 pre-existing info: `use_build_context_synchronously` in main.dart). **All 10 tests pass** (`flutter test`): migration (incl. PRAGMA assertions that money columns are INTEGER after upgrade) + widget tests.
- Deploy: `flutter build ios --release` then `xcrun devicectl device install app` + `device process launch` (phone must be UNLOCKED — `Locked` error when screen off). `flutter install` can hang on "Uninstalling old version…" — use `xcrun devicectl` directly instead. First-ever launch on a fresh device needs the signing profile trusted: `Settings → General → VPN & Device Management → <profile> → Trust` (and on iOS 26 Developer Mode must be enabled, then the phone RESTARTED, or every run says "enable Developer Mode").
- **Android emulator:** PixelFox AVD (Pixel 7, Android 35, arm64-v8a, Google APIs). Launch with `~/Library/Android/sdk/emulator/emulator -avd PixelFox -no-snapshot-load -gpu host &` then `flutter build apk --release` + `adb install -r`. Android build requires JDK 20 — Gradle 8.14 chokes on Android Studio's bundled JDK 25 (`java.lang.IllegalArgumentException: 25.0.2`). Fix: `org.gradle.java.home=/Library/Java/JavaVirtualMachines/temurin-20.jdk/Contents/Home` in `android/gradle.properties`. Android package: `com.unit.fox` (renamed Aug 2026 to match Play Console listing — was `com.sitemanager.sitemanager`; build.gradle.kts namespace+applicationId, MainActivity.kt moved to `kotlin/com/unit/fox/`).
- **Device signing:** team `5785G2M882`, bundle `com.princeofpersia41.sitemanager`, auto-signing in Xcode project — works for both debug and release. First cable connect requires "Trust This Computer" popup.
- **Web assets:** after adding a new file to `assets/`, run `flutter clean && flutter build web` — hot reload/restart does NOT update the asset manifest on web. Missing this causes `assets/assets/` double-prefix errors.
- Device: iPhone `00008110-000A44D93C6B801E` ("Kurtaranın iPhone'u", iOS 26.5.2), iPad `00008120-001144863E600032` ("CivcivPad").
- **`StatCard`:** supports `onTap` for tappable cards (finance Monthly Transactions → transactions page) and `plain: true` for count-only display (no currency symbol).
- **`AppBrand.gradientFab`:** uses DecoratedBox wrapper — do NOT use inside Expanded/Row (expands to fill). Use regular FABs inside Rows instead.
- **Awaiting Incomes:** auto-bills on `load()` + `addUnit()` + `recordPayment()`. Manual "Post monthly charges" button also available in finance screen. Metric = Σ per-month `remaining` (carry-forward arrears, base currency only; foreign payments appear as credit captions).
- **Cross-store delete sync (economical integrity):** deleting an ACCOUNT must also call `ExpenseStore.removeForAccount(id)` (DB cascade wipes expenses; ExpenseStore in-memory copy otherwise keeps counting them in monthly totals until reload). Deleting a UNIT returns the removed payment ids (`UnitStore.removeUnit`) and the caller must feed them to `AccountStore.removePayments(ids)` — otherwise account balances/transaction log keep counting a deleted unit's payments. Same pattern for account-delete → `UnitStore.removePayments`. `deleteProperty` is safe on its own (HomeShell reloads every scoped store on active-property change).
- **Money/logic audit — 3rd pass (Aug 2026):** fixed both desyncs above (account-delete → ExpenseStore; unit-delete → AccountStore). Income dialog defaults to the cash (base-currency) account, so quick income entries never silently land in a foreign account. `flutter analyze` still 1 pre-existing info; **all 12 tests pass**.
- **Android runtime crash FIXED (Aug 2026):** `curved_navigation_bar` 1.0.6 throws `RangeError (length): Only valid value is 0: 1` on Flutter 3.4x — its AnimationController ticks during `initState` and the listener reads `State.widget` (framework now throws). The app only used it as a single centered menu button, so it was REMOVED from pubspec and replaced with a hand-rolled **`BottomMenuBar`** (`lib/widgets/bottom_menu_bar.dart`).
- **`BottomMenuBar` v2 = RNavNSheet clone (Aug 2026):** after evaluating `animated_notch_bottom_bar` (needs 2–6 tabs — wrong model) and `r_nav_n_sheet` (perfect docked-button + sheet model but 22 months stale, 82 weekly downloads — same crash-risk profile as curved_navigation_bar), Master chose to replicate the design natively. Now a **full-width 96px domed dock bar**: `CustomClipper` top profile = gentle shoulders rising to a pointed center peak (RNavNSheet's `(w/3)-36 / (w/2)±36 / (w/1.5)+36` quadraticBezier curve, value 10); thin 2px gradient glow rim stroked along the top edge (`_DockBarRimPainter`, orange peak via `[0xFF3E3E56, AppBrand.gradient[0], 0xFF3E3E56]`); charcoal vertical-gradient body; 58px brand-gradient docked circle button (white ring + orange glow) seated on the peak, springy `AnimatedScale` press + `HapticFeedback.selectionClick()`. Apartment switcher on LEFT shoulder (opens property sheet: radio rows + currency + Manage properties) + menu button → grid sheet + settings gear on RIGHT shoulder (Aug 2026). Switcher tap target centers ≈ (150, 2235) on 1080×2400. `AppBrand.bottomPad` = 100. On 1080×2400 PixelFox the dock button tap target ≈ `[464,2155][616,2307]` (center 540,2231). If side items are wanted later, add `Expanded` `RNavItem`s into the `Row` inside the clipped body — the shape is already item-compatible.
- **FINANCIAL SMOKE SUITE (Aug 2026) — `test/financial_smoke_test.dart`:** 14 tests, REAL SQLite (in-memory via sqflite_common_ffi) + REAL stores, no mocks. Seeds a site through `LocalDB.completeOnboardingAtomic` (EUR cash opening 100000 + TRY bank), then proves: opening balances; income→cash raises balance & clears arrears; **currency-mismatch accounts never land on a balance**; **foreign payment = credit, never clears base arrears** (nonBaseCredits + guessed flag asserted); **non-aidat never auto-bills**; aidat auto-bills missing month; **overpayment carry-forward** (100k→90k → next month remaining 80k); removeCharge drops DB row + arrears; **salary partial/cap/overpay-block** (50k then capped 30k, 3rd refused, cash debited 80k); **unit-delete syncs AccountStore**; **account-delete syncs ExpenseStore**; transaction log newest-first; FX identity + 1:1 fallback offline; **persistence across store restart**. One test gotcha: `staff.add()` assigns a real DB id — always use `store.members.single.id`, never the passed `StaffMember.id` (0). Run: `flutter test test/financial_smoke_test.dart`. Full suite now **26 tests — all pass** (`flutter analyze` still 1 pre-existing info).
- **Confirm dialogs:** all record deletions (DB-backed) require confirm. Onboarding draft removals also confirm. Work orders, transactions, units, accounts, staff, properties — all guarded.
- **Privacy policy (Aug 2026):** hosted at `https://freakazoid41.github.io/unitfox/privacy.html` (GitHub Pages, repo `https://github.com/freakazoid41/unitfox`). Covers: all data local-only, AdMob disclosure with Google policies linked, contact `kadir.bozat@tail.com.tr`.
- **Release signing — FULLY SETUP (Aug 2026):**
  - Keystore: `~/unitfox-upload.jks` (RSA 2048, valid until 2054, alias `upload`).
  - `android/key.properties` created + `.gitignore`'d — contains storePassword/keyPassword/keyAlias/storeFile.
  - `android/app/build.gradle.kts` rewritten: loads `key.properties`, creates `release` signing config from it, falls back to `debug` when missing.
  - Signed AAB: `build/app/outputs/bundle/release/app-release.aab` (62.3MB) — verified via `jarsigner`.
  - Distinguished name: CN=Unitfox, OU=Unitfox, O=PickleCan, L=Istanbul, ST=Istanbul, C=TR.
  - **Keystore password is in a separate vault entry** (never stored in memory.md for security).
- **INTERNET permission fix (Aug 2026):** `android/app/src/main/AndroidManifest.xml` now includes `INTERNET` + `ACCESS_NETWORK_STATE` — release builds have network (FX rates, AdMob).
- **Play Console status (Aug 2026):** developer account `PickleCan` (personal, ID 777413745887559423O) at `https://play.google.com/console`. **Identity verification COMPLETE (passed)** — all 3 manual steps (device access verification, phone+ID upload, Google approval email) done. Next: create app → fill checklist → upload AAB.
- **Store descriptions (Aug 2026):** short (74 chars): "Unitfox — offline site manager. Track rent, crew, expenses, work orders." / TR (77 chars): "Unitfox — çevrimdışı site yöneticisi. Kira, personel, gider, iş emri." Full EN + TR long descriptions written (saved in this session's chat, not in repo).
- **Store assets — GENERATED (Aug 2026), all in `store_assets/`:**
  - `feature_graphic.png` (1024×500, EN) + `feature_graphic_TR.png` (1024×500, TR) — ImageMagick-composed: warm cream bg `#FAF6F1`, left = orange "Unitfox" + tagline (EN "Offline Site Manager" / TR "Çevrimdışı Site Yöneticisi") + 4 checkmark bullets, right = teal-gradient rounded card (`#2AB7A4`→`#1D8A7A`) with fox_logo. All content within Google's 824px safe area (x 100–924). TR bullets: "Kira ve ödemeler takibi", "Personel ve gider yönetimi", "İş emirleri + fotoğraf kanıtı", "100% çevrimdışı - veri cihazında". Turkish UTF-8 chars render fine; escape `%` as `\%` in IM annotate.
  - **TR screenshots** (default, no prefix): `phone_dashboard.png` / `phone_finance.png` / `phone_units.png` (1080×2400, PixelFox emulator), `tablet_dashboard.png` + `tablet_dashboard_stats.png` (2560×1600, UnitFoxTablet AVD). **REAL device screenshots** via `adb exec-out screencap -p` (replaced earlier ImageMagick placeholders which Google rejects).
  - **EN screenshots** (`en_` prefix): `en_phone_dashboard.png` / `en_phone_finance.png` / `en_phone_units.png` (1080×2400) + `en_tablet_dashboard.png` / `en_tablet_dashboard_stats.png` (2560×1600). Same fake data, app switched to English.
  - For per-language listing uploads: TR set (default) + EN set (`en_` prefixed). RU/FR/DE/HI not made (low priority, add later if app gains traction there).
- **Fake data seeded on emulator (Aug 2026) for screenshots:** 6 units (2/3/5/6=occupied, 4=maintenance, 1=vacant; €3,200–4,500/mo; occupants Ali Yilmaz, Ayse Demir, Mehmet Kaya, Zeynep Aydin), 3 crew (Hasan/Mehmet/Ayse Usta, €15k/12k/10k), 3 work orders (Lavabo arızası, Su sızıntısı, Elektrik arızası), 3 expenses (Elektrik €2,500 + Temizlik €800 + €1,200 = €4,500). Dashboard: 66% occupancy, 1 maintenance, €4,500 monthly expense, €16,700 awaiting income, 3 transactions.
- **Screenshot workflow notes (Aug 2026):**
  - Drive app via `adb shell input tap/text` + OCR (tesseract, upscale 200-400% + `-normalize -sharpen`) since Flutter release builds don't expose widgets to uiautomator. Use `screencap -p` → OCR to map fields/buttons, tap by coords.
  - Dialog buttons differ: **full-screen pages** (AddUnit, work orders) have AppBar save at top-right ~(930,200); **FormDialog (AlertDialog)** forms (crew, expense) have Save at the dialog's bottom — find via orange/peach pixel scan (expense save was ~(750,1725)).
  - Data copy phone→tablet: `adb root` (works on google_apis images) → `pull /data/data/com.unit.fox/databases/sitemanager.db` → push to other device → `chown <app_uid> db` (get from `stat`, NOT hardcoded) + `chmod 660` + force-stop before relaunch. This clones fake data across emulators.
  - **Language switch for localized screenshots (UPDATED Aug 2026):** language moved from the PropertySwitcher dropdown to the **Settings screen** — Menu (bottom dock button) → Settings tile → tap a language row. After switching, **force-stop + relaunch the app** so ALL screens (esp. screen titles like Units/Daireler) rebuild in the new language — switching alone leaves already-pushed IndexedStack screens in the old language.
  - `medium_tablet` AVD default Android 35 google_apis image exists locally; `avdmanager create avd -n X -k "system-images;android-35;google_apis;arm64-v8a" -d medium_tablet`.
  - Note: fake data uses EUR currency + Turkish-style occupant names (Ali Yilmaz etc.) — fine for both TR and EN screenshots.

## Known-accepted
- `PaymentType.aidat` hardcoded Turkish (DB value, not worth migration)
- Work-order `Autocomplete` unit controller partial desync (cosmetic)
- `dispatch` optimistic write without rollback (offline-first: virtually impossible to fail)
- `LanguageStore.toggle()` dead — removed
- Dark mode removed — light mode only
- Onboarding draft removals (bank/unit) require confirm but are in-memory (not DB records)

## Room for improvement (not critical)
- Onboarding `_UnitForm` still uses old `tenantName` field (not the occupant list)
- Work order creation doesn't validate occupant selection against actual units
- No tenant move-in/move-out tracking or lease dates

## Release checklist (Play Store)
- **App name:** Unitfox
- **Package:** `com.unit.fox`
- **Version:** `1.1.0+12` (versionCode 12) — bump `+N` on each release
- **Privacy policy:** `https://freakazoid41.github.io/unitfox/privacy.html`
- **Play Console:** `https://play.google.com/console` (PickleCan, personal)
- **Signed AAB:** `build/app/outputs/bundle/release/app-release.aab` (62.3MB)
- **Keystore:** `~/unitfox-upload.jks` (password in vault)
- **Store listing needed:** title, short/full description, app icon 512×512, feature graphic 1024×500, 2+ screenshots, contact email, category (Business/Productivity)
- **Content rating:** fill questionnaire (ads → target 18+)
- **Data safety:** declare all data local-only, no collection
- **Ads declaration:** Yes (AdMob)
- **Pricing:** free or paid, select countries
- **AD_ID permission:** added to AndroidManifest.xml (required for AdMob on Android 13+)

## Closed testing (Aug 2026)
- **Google Group:** `pickletest@googlegroups.com` / `groups.google.com/g/pickletest`
- **Testers needed:** 12+ opted-in for 14 days (Google policy for new personal accounts)
- **Opt-in link:** from Play Console → Closed testing → Test kullanıcıları → Bağlantıyı kopyala
- **Reddit post drafted** for `r/AndroidTesting`, `r/AndroidApps`, `r/alphaandbetausers` — title: `[Android] Unitfox — Offline apartment/site manager. Looking for closed testers (12+ needed!)`
- **Version history:** v1 (internal testing, versionCode 1), v2 (AD_ID fix, versionCode 2 — failed upload), v3 (current, versionCode 3 — has AD_ID permission)

## TODO (Sep 2026)
- [x] **Banner reliably seen** — DONE: `AdBannerCard` post-frame load + resume retry + 5/10/20/30s backoff (5x) + 60s refresh; placement hero→banner→Overview above fold; `IndexedStack` keeps state. Emulator verified live `Test Ad` render.
- [x] **Full app test** — DONE: 27 tests green (`flutter test`), analyzer 1 pre-existing info, R8-minified release smoke on PixelPlay (launch, onboarding→DB, Units, menu grid, Dashboard, no crash).
- [x] **Onboarding cash row design (Sep 2026)** — DONE: cash card shared the bank rows' two-line `ListTile` (removed forced `isThreeLine`, same `field.opening` subtitle shape, leading icon on both, empty bank/iban collapsed). Dead `onb.openingLine` key removed from all 6 langs. Regression test `test/onboarding_cash_row_test.dart`.
- [x] **Flaky "newest first" test (Sep 2026)** — DONE: `financial_smoke_test` asserted inverted strict order; DB ms-truncation makes ties legal. Now asserts the non-increasing-date invariant (loop). Full suite 27 — all pass, 3x stable.

Same here t4t i did install your app and i will enter for 14 day. here are my links . im awaiting your valueable support
google group : https://groups.google.com/g/pickletest
play store : https://play.google.com/store/apps/details?id=com.unit.fox
web : https://play.google.com/apps/testing/com.unit.fox  