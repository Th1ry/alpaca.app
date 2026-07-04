import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_settings.dart';
import 'core/constants.dart';
import 'core/display_config.dart';
import 'core/strings.dart';
import 'core/symbol_utils.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/portfolio/portfolio_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/trade/trade_screen.dart';
import 'models/models.dart';
import 'providers/app_settings_provider.dart';
import 'providers/app_update_provider.dart';
import 'services/api_service.dart';
import 'services/ws_service.dart';
import 'features/settings/app_update_dialog.dart';
import 'shared/widgets/floating_capsule_nav.dart';

class AlpacaOptionsApp extends ConsumerStatefulWidget {
  const AlpacaOptionsApp({super.key});

  @override
  ConsumerState<AlpacaOptionsApp> createState() => _AlpacaOptionsAppState();
}

class _AlpacaOptionsAppState extends ConsumerState<AlpacaOptionsApp> {
  int _tab = 0;
  String _tradeSymbol = AppConstants.defaultSymbol;
  String? _tradeSelectedOcc;
  final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static const _navDuration = Duration(milliseconds: 320);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(wsServiceProvider).subscribePortfolio();
      await ref.read(appUpdateProvider.notifier).autoCheckIfDue();
      _promptUpdateIfNeeded();
    });
  }

  void _promptUpdateIfNeeded() {
    final info = ref.read(appUpdateProvider).info;
    if (info == null) return;
    final ctx = _rootNavigatorKey.currentContext;
    if (ctx == null) return;
    showAppUpdateDialog(
      ctx,
      info: info,
      onLater: () => ref.read(appUpdateProvider.notifier).dismiss(info),
      onInstall: () => ref.read(appUpdateServiceProvider).installUpdate(info),
    );
  }

  void _openUpdateFromBanner() {
    final info = ref.read(appUpdateProvider).info;
    if (info == null) {
      _openSettings();
      return;
    }
    final ctx = _rootNavigatorKey.currentContext;
    if (ctx == null) return;
    showAppUpdateDialog(
      ctx,
      info: info,
      onLater: () => ref.read(appUpdateProvider.notifier).dismiss(info),
      onInstall: () => ref.read(appUpdateServiceProvider).installUpdate(info),
    );
  }

  void _goTrade(String symbol) {
    setState(() {
      _tradeSymbol = symbol;
      _tradeSelectedOcc = null;
      _tab = 1;
    });
  }

  void _goTradePosition(Position position) {
    final sym = position.symbol.toUpperCase();
    final occ = isOptionSymbol(sym) ? sym : null;
    final underlying = optionUnderlying(sym) ?? sym;
    setState(() {
      _tradeSymbol = underlying;
      _tradeSelectedOcc = occ;
      _tab = 1;
    });
  }

  void _onTabTap(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
  }

  void _openSettings() {
    _rootNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(alpacaCredentialsProvider, (prev, next) {
      if (!next.isConfigured) return;
      if (prev?.apiKey != next.apiKey ||
          prev?.apiSecret != next.apiSecret ||
          prev?.apiUrl != next.apiUrl) {
        ref.read(wsServiceProvider).subscribePortfolio(force: true);
      }
    });

    final settings = ref.watch(appSettingsProvider);
    final updateState = ref.watch(appUpdateProvider);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final locale = settings.language == AppLanguage.en
        ? const Locale('en', 'US')
        : const Locale('zh', 'CN');

    final tabTitles = [S.home, S.trade, S.portfolio];
    final navItems = [
      FloatingCapsuleNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: S.home,
      ),
      FloatingCapsuleNavItem(
        icon: Icons.candlestick_chart_outlined,
        activeIcon: Icons.candlestick_chart_rounded,
        label: S.trade,
      ),
      FloatingCapsuleNavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: S.portfolio,
      ),
    ];

    return MaterialApp(
      navigatorKey: _rootNavigatorKey,
      title: S.appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.current(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(DisplayConfig.textScale),
          ),
          child: child!,
        );
      },
      home: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: AnimatedSwitcher(
            duration: _navDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              tabTitles[_tab],
              key: ValueKey('$_tab-${settings.language.name}'),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              tooltip: S.settings,
              onPressed: _openSettings,
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (updateState.phase == AppUpdateCheckPhase.available &&
                    updateState.info != null)
                  AppUpdateBanner(
                    version: updateState.info!.manifest.version,
                    onTap: _openUpdateFromBanner,
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      HomeScreen(
                        key: ValueKey('home-${settings.language.name}'),
                        isActive: _tab == 0,
                        onTrade: _goTrade,
                      ),
                      TradeScreen(
                        key: ValueKey('trade-${settings.language.name}:${_tradeSelectedOcc ?? ''}'),
                        symbol: _tradeSymbol,
                        selectedOcc: _tradeSelectedOcc,
                        isActive: _tab == 1,
                        onSymbolChange: (s) => setState(() {
                          _tradeSymbol = s;
                          _tradeSelectedOcc = null;
                        }),
                      ),
                      PortfolioScreen(
                        key: ValueKey('portfolio-${settings.language.name}'),
                        isActive: _tab == 2,
                        onTapPosition: _goTradePosition,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 12 + safeBottom,
              child: FloatingCapsuleNav(
                key: ValueKey(settings.language.name),
                index: _tab,
                onTap: _onTabTap,
                items: navItems,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
