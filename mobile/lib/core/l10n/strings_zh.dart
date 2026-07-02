import '../app_settings.dart';

/// Chinese UI strings.
class StringsZh {
  const StringsZh();

  String get appTitle => '期权';
  String get home => '首页';
  String get trade => '交易';
  String get portfolio => '资金';
  String get settings => '设置';
  String get totalAssets => '总资产';
  String get buyingPower => '购买力';
  String get cash => '现金';
  String get today => '今日';
  String get todayPnl => '今日盈亏';
  String get pnlCurve => '盈亏曲线';
  String get period7d => '7日';
  String get period1m => '1月';
  String get period1y => '1年';
  String get tradeAnalytics => '交易分析';
  String get winRate => '胜率';
  String get profitFactor => '盈亏比';
  String get avgHoldTime => '平均持仓';
  String get totalTrades => '开仓次数';
  String get realizedPnl => '已实现盈亏';
  String get avgWin => '平均盈利';
  String get avgLoss => '平均亏损';
  String get pnlCalendar => '盈亏日历';
  String get bestDay => '最佳单日';
  String get worstDay => '最差单日';
  String get noAnalyticsData => '暂无交易数据';
  String get hours => '小时';
  String get days => '天';
  String get watchlist => '自选';
  String get loading => '加载中...';
  String get loadFailed => '无法连接 Alpaca';
  String get loadFailedHint => '请先在设置中选择 Paper/Live，并填写 API Key 与 Secret';
  String get retry => '重试';
  String get accountEquity => '账户权益';
  String get positions => '持仓';
  String get noPositions => '暂无持仓';
  String get orders => '订单';
  String get orderHistory => '历史订单';
  String get noOrders => '暂无订单';
  String get noPosition => '暂无持仓';
  String get colContract => '合约';
  String get colSize => '数量';
  String get colEntry => '开仓均价';
  String get colMark => '标记价格';
  String get colUpnl => '未实现盈亏';
  String get long => '多';
  String get short => '空';
  String get stockPositions => '正股';
  String get optionPositions => '期权';
  String get noStockPositions => '暂无正股持仓';
  String get noOptionPositions => '暂无期权持仓';
  String get quickClose => '快速平仓';
  String get partialClose => '部分平仓';
  String get tpSl => '止盈止损';
  String get closeRatio => '平仓比例';
  String get confirmClose => '确认平仓';
  String get confirmPartialClose => '确认部分平仓';
  String get quickCloseConfirm => '将以市价全部平仓：';
  String get cancel => '取消';
  String get closeSubmitted => '平仓订单已提交';
  String get noLiquidity => '无流动性';
  String get noLiquidityHint => '该期权已无报价，市价无法成交';
  String get dismissPosition => '移出列表';
  String get dismissPositionConfirm =>
      '此期权已无流动性，无法卖出。\n移出后不再显示在持仓中；到期后 Alpaca 会自动清零。\n\n确认移出？';
  String get positionDismissed => '已从持仓列表移除';
  String get tryCloseAnyway => '尝试平仓';
  String get takeProfitPrice => '止盈价';
  String get stopLossPrice => '止损价';
  String get saveTpSl => '提交止盈止损';
  String get tpSlSubmitted => '止盈止损订单已提交';
  String get noChartData => '暂无K线数据';
  String get searchSymbol => '搜索代码';
  String get searchSymbolOrName => '搜索代码或公司名';
  String get noSearchResults => '未找到标的';
  String get addWatchlist => '加自选';
  String get removeWatchlist => '移出自选';
  String get addedWatchlist => '已加入自选';
  String get editWatchlist => '编辑';
  String get done => '完成';
  String get watchlistEmpty => '自选为空，搜索后点击星标添加';
  String get news => '新闻';
  String get noNews => '暂无新闻';
  String get newsLoadFailed => '新闻加载失败';
  String get buy => '买入';
  String get sell => '卖出';
  String get market => '市价';
  String get limit => '限价';
  String get qty => '数量';
  String get limitPrice => '限价';
  String get orderPrice => '下单价格';
  String get availableCash => '购买力';
  String get marginBuyingPower => '融资购买力';
  String get maxBuyQty => '可买';
  String get maxSellQty => '可卖';
  String get fundsRatio => '资金比例';
  String get submitOrder => '提交订单';
  String get orderSection => '下单';
  String get orderSubmitted => '订单已提交';
  String get depthBook => '五档报价';
  String get bidAsk => '盘口';
  String get bid1 => '买一';
  String get ask1 => '卖一';
  String get lastPrice => '最新成交价';
  String get noBidAsk => '暂无盘口';
  String get colPrice => '价格';
  String get colDepthQty => '数量';
  String get loadingOptions => '加载期权中...';
  String get noOptionsChain => '暂无期权链数据';
  String get expiry => '到期日';
  String get call => '看涨';
  String get put => '看跌';
  String get tabChart => '图表';
  String get tabOptionsChain => '期权链';
  String get backToChart => '返回图表';
  String get currentPosition => '当前持仓';
  String get apiSection => 'Alpaca API';
  String get apiLocalOnly => 'Key 仅保存在本设备，App 直连 Alpaca（Paper / Live）';
  String get apiUrlAuto => '接口地址（随 Paper / Live 自动切换）';
  String get alpacaEnvPaper => '模拟盘 Paper';
  String get alpacaEnvLive => '实盘 Live';
  String get alpacaApiKey => 'API Key';
  String get alpacaApiSecret => 'API Secret';
  String get depthApiUrl => '五档 API 地址';
  String get depthApiHint => '可选。返回 JSON：{"asks":[{"price":1.23,"size":100}],"bids":[...]}，URL 中用 {symbol} 占位。留空则仅显示 Alpaca 买一/卖一。';
  String get apiSaved => 'Alpaca 已保存';
  String get apiTestConnection => '测试连接';
  String get apiStatusTesting => '正在连接 Alpaca…';
  String get apiStatusConnected => '已连接 Alpaca';
  String get apiStatusFailed => '连接失败';
  String get apiNotConfigured => '请先填写 API Key 和 Secret';
  String get apiSaveSuccess => '已保存，连接成功';
  String get apiSaveFailed => '已保存，但连接失败';
  String get apiSavedLocal => '凭证已保存到本设备';
  String apiConnectedDetail(bool paper, double equity) =>
      '${paper ? "Paper 模拟盘" : "Live 实盘"} · 账户权益 \$${equity.toStringAsFixed(2)}';
  String get chartStock => '正股';
  String get chartOption => '期权';
  String get preferences => '偏好设置';
  String get language => '语言';
  String get languageZh => '中文';
  String get languageEn => 'English';
  String get themeLabel => '主题';
  String get themeBlack => '黑';
  String get themeWhite => '白';
  String get themePink => '粉';
  String get themeGreen => '绿';
  String get pnlColors => '涨跌颜色';
  String get pnlGreenUp => '涨绿跌红';
  String get pnlRedUp => '涨红跌绿';
  String get timezone => '时区';
  String get tzShanghai => '北京时间 (UTC+8)';
  String get tzNewYork => '纽约 (UTC-5)';
  String get tzLosAngeles => '洛杉矶 (UTC-8)';
  String get tzUtc => 'UTC';
  String get save => '保存';
  String get settingsSaved => '设置已保存';
  String get appVersion => '版本';
  String get checkForUpdate => '检查更新';
  String get updateAvailableBody => '建议更新以获得最新功能与修复。';
  String get updateNow => '立即更新';
  String get updateLater => '稍后';
  String get updateDownloading => '正在下载…';
  String get updateInstalling => '正在安装，请按系统提示完成…';
  String get updateUpToDate => '已是最新版本';
  String get updateCheckFailed => '检查更新失败';
  String get updateDisabled => '未配置更新地址';
  String get updateInstallFailed => '更新安装失败';
  String get updatePermissionRequired => '请在系统设置中允许本应用「安装未知应用」后重试';
  String get updateDownloadFailed => '下载失败，请检查网络后重试';
  String updateErrorMessage(String code) {
    switch (code) {
      case 'PERMISSION_NOT_GRANTED_ERROR':
        return updatePermissionRequired;
      case 'DOWNLOAD_ERROR':
        return updateDownloadFailed;
      case 'ALREADY_RUNNING_ERROR':
        return '更新正在进行中，请稍候';
      case 'CHECKSUM_ERROR':
        return '安装包校验失败，请稍后重试';
      case 'CANCELED':
        return '已取消下载';
      case 'no_download_url':
        return '未找到适用于当前平台的下载地址';
      case 'launch_failed':
        return '无法打开下载链接';
      default:
        return code.isEmpty ? updateInstallFailed : '$updateInstallFailed ($code)';
    }
  }
  String updateAvailableTitle(String version) => '发现新版本 $version';
  String updateBanner(String version) => '新版本 $version 可用，点击更新';

  String winRateOpens(int total, int wins, int losses) =>
      '共 $total 笔开仓，$wins 胜 / $losses 负';

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
        return '新建';
      case 'accepted':
        return '已接受';
      case 'filled':
        return '已成交';
      case 'partially_filled':
        return '部分成交';
      case 'canceled':
      case 'cancelled':
        return '已取消';
      case 'rejected':
        return '已拒绝';
      case 'pending_new':
        return '待提交';
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
