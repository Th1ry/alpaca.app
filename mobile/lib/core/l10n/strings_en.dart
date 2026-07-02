import '../app_settings.dart';

/// English UI strings.
class StringsEn {
  const StringsEn();

  String get appTitle => 'Options';
  String get home => 'Home';
  String get trade => 'Trade';
  String get portfolio => 'Portfolio';
  String get settings => 'Settings';
  String get totalAssets => 'Total Assets';
  String get buyingPower => 'Buying Power';
  String get cash => 'Cash';
  String get today => 'Today';
  String get todayPnl => "Today's P&L";
  String get pnlCurve => 'P&L Curve';
  String get period7d => '7D';
  String get period1m => '1M';
  String get period1y => '1Y';
  String get tradeAnalytics => 'Trade Analytics';
  String get winRate => 'Win Rate';
  String get profitFactor => 'Profit Factor';
  String get avgHoldTime => 'Avg Hold';
  String get totalTrades => 'Opens';
  String get realizedPnl => 'Realized P&L';
  String get avgWin => 'Avg Win';
  String get avgLoss => 'Avg Loss';
  String get pnlCalendar => 'P&L Calendar';
  String get bestDay => 'Best Day';
  String get worstDay => 'Worst Day';
  String get noAnalyticsData => 'No trade data yet';
  String get hours => 'h';
  String get days => 'd';
  String get watchlist => 'Watchlist';
  String get loading => 'Loading...';
  String get loadFailed => 'Cannot reach Alpaca';
  String get loadFailedHint => 'Choose Paper/Live in Settings and add your API Key & Secret';
  String get retry => 'Retry';
  String get accountEquity => 'Equity';
  String get positions => 'Positions';
  String get noPositions => 'No positions';
  String get orders => 'Orders';
  String get orderHistory => 'Order History';
  String get noOrders => 'No orders';
  String get noPosition => 'No position';
  String get colContract => 'Symbol';
  String get colSize => 'Size';
  String get colSizeOption => 'Contracts';
  String get colSizeStock => 'Shares';
  String get colEntry => 'Entry';
  String get colMark => 'Mark';
  String get colUpnl => 'Unrealized P&L';
  String get long => 'Long';
  String get short => 'Short';
  String get stockPositions => 'Stocks';
  String get optionPositions => 'Options';
  String get noStockPositions => 'No stock positions';
  String get noOptionPositions => 'No option positions';
  String get quickClose => 'Close All';
  String get partialClose => 'Partial Close';
  String get tpSl => 'TP / SL';
  String get closeRatio => 'Close %';
  String get confirmClose => 'Confirm Close';
  String get confirmPartialClose => 'Confirm Partial Close';
  String get quickCloseConfirm => 'Market close entire position:';
  String get cancel => 'Cancel';
  String get closeSubmitted => 'Close order submitted';
  String get noLiquidity => 'No liquidity';
  String get noLiquidityHint => 'No bid/ask — market close may fail';
  String get dismissPosition => 'Remove';
  String get dismissPositionConfirm =>
      'This option has no liquidity and cannot be sold.\n'
      'Remove it from your list; Alpaca will zero it at expiry.\n\n'
      'Remove from list?';
  String get positionDismissed => 'Removed from positions list';
  String get tryCloseAnyway => 'Try close';
  String get takeProfitPrice => 'Take Profit';
  String get stopLossPrice => 'Stop Loss';
  String get saveTpSl => 'Submit TP/SL';
  String get tpSlSubmitted => 'TP/SL orders submitted';
  String get noChartData => 'No chart data';
  String get searchSymbol => 'Search symbol';
  String get searchSymbolOrName => 'Search symbol or name';
  String get noSearchResults => 'No results';
  String get addWatchlist => 'Add';
  String get removeWatchlist => 'Remove';
  String get addedWatchlist => 'Added to watchlist';
  String get editWatchlist => 'Edit';
  String get done => 'Done';
  String get watchlistEmpty => 'Watchlist empty — search and tap star to add';
  String get news => 'News';
  String get noNews => 'No news';
  String get newsLoadFailed => 'News failed to load';
  String get buy => 'Buy';
  String get sell => 'Sell';
  String get market => 'Market';
  String get limit => 'Limit';
  String get qty => 'Qty';
  String get qtyUnitOption => ' ct';
  String get qtyUnitStock => ' sh';
  String get limitPrice => 'Limit Price';
  String get orderPrice => 'Order Price';
  String get availableCash => 'Buying Power';
  String get marginBuyingPower => 'Margin BP';
  String get maxBuyQty => 'Max Buy';
  String get maxSellQty => 'Max Sell';
  String get fundsRatio => 'Size %';
  String get submitOrder => 'Submit Order';
  String get orderSection => 'Order';
  String get orderSubmitted => 'Order submitted';
  String get depthBook => 'Depth';
  String get bidAsk => 'Book';
  String get bid1 => 'Bid';
  String get ask1 => 'Ask';
  String get lastPrice => 'Last trade';
  String get noBidAsk => 'No quotes';
  String get colPrice => 'Price';
  String get colDepthQty => 'Qty';
  String get loadingOptions => 'Loading options...';
  String get noOptionsChain => 'No options chain';
  String get expiry => 'Expiry';
  String get call => 'Call';
  String get put => 'Put';
  String get tabChart => 'Chart';
  String get tabOptionsChain => 'Chain';
  String get backToChart => 'Back to chart';
  String get currentPosition => 'Position';
  String get apiSection => 'Alpaca API';
  String get apiLocalOnly => 'Keys stay on this device. The app connects to Alpaca directly.';
  String get apiUrlAuto => 'Endpoint (auto from Paper / Live)';
  String get alpacaEnvPaper => 'Paper';
  String get alpacaEnvLive => 'Live';
  String get alpacaApiKey => 'API Key';
  String get alpacaApiSecret => 'API Secret';
  String get depthApiUrl => 'Depth API URL';
  String get depthApiHint =>
      'Optional. JSON: {"asks":[{"price":1.23,"size":100}],"bids":[...]}. Use {symbol} in the URL. Leave empty for Alpaca BBO (level 1) only.';
  String get apiSaved => 'Alpaca credentials saved';
  String get apiTestConnection => 'Test connection';
  String get apiStatusTesting => 'Connecting to Alpaca…';
  String get apiStatusConnected => 'Connected to Alpaca';
  String get apiStatusFailed => 'Connection failed';
  String get apiNotConfigured => 'Enter API Key and Secret first';
  String get apiSaveSuccess => 'Saved and connected';
  String get apiSaveFailed => 'Saved, but connection failed';
  String get apiSavedLocal => 'Credentials stored on this device';
  String apiConnectedDetail(bool paper, double equity) =>
      '${paper ? "Paper" : "Live"} · equity \$${equity.toStringAsFixed(2)}';
  String get chartStock => 'Stock';
  String get chartOption => 'Option';
  String get preferences => 'Preferences';
  String get language => 'Language';
  String get languageZh => '中文';
  String get languageEn => 'English';
  String get themeLabel => 'Theme';
  String get themeBlack => 'Black';
  String get themeWhite => 'White';
  String get themePink => 'Pink';
  String get themeGreen => 'Green';
  String get pnlColors => 'Up / Down Colors';
  String get pnlGreenUp => 'Green up, red down';
  String get pnlRedUp => 'Red up, green down';
  String get timezone => 'Timezone';
  String get tzShanghai => 'Beijing (UTC+8)';
  String get tzNewYork => 'New York (UTC-5)';
  String get tzLosAngeles => 'Los Angeles (UTC-8)';
  String get tzUtc => 'UTC';
  String get save => 'Save';
  String get settingsSaved => 'Settings saved';
  String get appVersion => 'Version';
  String get checkForUpdate => 'Check for updates';
  String get updateAvailableBody => 'Update for the latest features and fixes.';
  String get updateNow => 'Update now';
  String get updateLater => 'Later';
  String get updateDownloading => 'Downloading…';
  String get updateInstalling => 'Installing — follow system prompts…';
  String get updateUpToDate => 'You are up to date';
  String get updateCheckFailed => 'Update check failed';
  String get updateDisabled => 'Update URL not configured';
  String get updateInstallFailed => 'Update installation failed';
  String get updatePermissionRequired =>
      'Allow this app to install unknown apps in system settings, then retry';
  String get updateDownloadFailed => 'Download failed — check your network and retry';
  String updateErrorMessage(String code) {
    switch (code) {
      case 'PERMISSION_NOT_GRANTED_ERROR':
        return updatePermissionRequired;
      case 'DOWNLOAD_ERROR':
        return updateDownloadFailed;
      case 'ALREADY_RUNNING_ERROR':
        return 'An update is already in progress';
      case 'CHECKSUM_ERROR':
        return 'Package verification failed — try again later';
      case 'CANCELED':
        return 'Download canceled';
      case 'no_download_url':
        return 'No download URL for this platform';
      case 'launch_failed':
        return 'Could not open download link';
      default:
        return code.isEmpty ? updateInstallFailed : '$updateInstallFailed ($code)';
    }
  }
  String updateAvailableTitle(String version) => 'Update $version available';
  String updateBanner(String version) => 'Version $version available — tap to update';

  String winRateOpens(int total, int wins, int losses) =>
      '$total opens · $wins wins / $losses losses';

  String positionSide(String side) {
    switch (side.toLowerCase()) {
      case 'long':
        return long;
      case 'short':
        return short;
      default:
        return side;
    }
  }

  String orderSide(String side) {
    switch (side.toLowerCase()) {
      case 'buy':
        return buy;
      case 'sell':
        return sell;
      default:
        return side;
    }
  }

  String orderTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'market':
        return market;
      case 'limit':
        return limit;
      default:
        return type;
    }
  }

  String orderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'New';
      case 'accepted':
        return 'Accepted';
      case 'filled':
        return 'Filled';
      case 'partially_filled':
        return 'Partial';
      case 'canceled':
      case 'cancelled':
        return 'Canceled';
      case 'rejected':
        return 'Rejected';
      case 'pending_new':
        return 'Pending';
      default:
        return status;
    }
  }

  String themeName(AppThemeId id) {
    switch (id) {
      case AppThemeId.black:
        return themeBlack;
      case AppThemeId.white:
        return themeWhite;
      case AppThemeId.pink:
        return themePink;
      case AppThemeId.green:
        return themeGreen;
    }
  }

  String timezoneLabel(AppTimezone tz) {
    switch (tz) {
      case AppTimezone.shanghai:
        return tzShanghai;
      case AppTimezone.newYork:
        return tzNewYork;
      case AppTimezone.losAngeles:
        return tzLosAngeles;
      case AppTimezone.utc:
        return tzUtc;
    }
  }
}
