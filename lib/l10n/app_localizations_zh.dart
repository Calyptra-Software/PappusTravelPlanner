// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Pappus Travel Planner';

  @override
  String get tripsTitle => '我的旅行';

  @override
  String get newTrip => '新建旅行';

  @override
  String get noTripsTitle => '还没有旅行';

  @override
  String get noTripsBody => '点按「新建旅行」来规划你的第一次旅程。';

  @override
  String get searchTrips => '搜索旅行';

  @override
  String get searchTripsHint => '标题、目的地或备注';

  @override
  String get filterTrips => '筛选和排序';

  @override
  String get filterTitle => '筛选';

  @override
  String get filterAndSort => '筛选与排序';

  @override
  String get clearFilters => '清除';

  @override
  String tripsMatching(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$shown / $total 次旅行',
      one: '$shown / 1 次旅行',
    );
    return '$_temp0';
  }

  @override
  String routinesMatching(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$shown / $total 个模板行程',
      one: '$shown / 1 个模板行程',
    );
    return '$_temp0';
  }

  @override
  String get statusLabel => '状态';

  @override
  String get tripStatusUpcoming => '即将开始';

  @override
  String get tripStatusOngoing => '进行中';

  @override
  String get tripStatusPast => '已结束';

  @override
  String get tripStatusUndated => '无日期';

  @override
  String get sortLabel => '排序';

  @override
  String get sortDateAsc => '日期（最早）';

  @override
  String get sortDateDesc => '日期（最晚）';

  @override
  String get sortNameAsc => '名称（A-Z）';

  @override
  String get sortCreatedDesc => '最近添加';

  @override
  String get sortExpenseDesc => '费用（最高）';

  @override
  String get sortExpenseAsc => '费用（最低）';

  @override
  String get anyDate => '不限';

  @override
  String get noTripsFoundTitle => '没有匹配的旅行';

  @override
  String noTripsFoundBody(String query) {
    return '没有与「$query」匹配的旅行。';
  }

  @override
  String genericError(String error) {
    return '出了点问题：\n$error';
  }

  @override
  String days(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
      one: '1 天',
    );
    return '$_temp0';
  }

  @override
  String entries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个条目',
      one: '1 个条目',
    );
    return '$_temp0';
  }

  @override
  String get datesNotSet => '未设置日期';

  @override
  String until(String date) {
    return '至 $date';
  }

  @override
  String get editTrip => '编辑旅行';

  @override
  String get shareTrip => '分享旅行';

  @override
  String get shareTripSaved => '旅行文件已保存。';

  @override
  String get shareTripFailed => '无法分享此旅行。';

  @override
  String get exportPdf => '导出为 PDF';

  @override
  String get exportPdfFailed => '无法将此旅行导出为 PDF。';

  @override
  String get exportGpx => '导出轨迹（GPX）…';

  @override
  String get exportGpxEmpty => '此旅行没有可导出的轨迹';

  @override
  String get exportGpxFailed => '无法导出轨迹';

  @override
  String get exportIcs => '导出到日历';

  @override
  String get exportIcsFailed => '无法将此旅行导出到日历。';

  @override
  String get exportAction => '导出';

  @override
  String get pdfSectionsTitle => 'PDF 包含内容';

  @override
  String get pdfSectionsSubtitle => '旅行名称、日期和参与者始终会包含在内。';

  @override
  String get pdfSectionEmpty => '没有记录';

  @override
  String get pdfInclSettlements => '包含结算';

  @override
  String pdfLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个清单',
      one: '1 个清单',
    );
    return '$_temp0';
  }

  @override
  String pdfItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目',
      one: '1 个项目',
    );
    return '$_temp0';
  }

  @override
  String pdfOtherOptions(String options) {
    return '其他选项：$options';
  }

  @override
  String pdfExportedOn(String date) {
    return '导出于 $date';
  }

  @override
  String get importTrip => '导入旅行';

  @override
  String get importTripSuccess => '旅行已导入。';

  @override
  String get importTripInvalid => '此文件不是有效的共享旅行文件。';

  @override
  String get importTripTooNew => '此旅行来自更新版本的应用。请更新应用后再导入。';

  @override
  String get importTripFailed => '无法导入此旅行。';

  @override
  String get fieldTitle => '标题';

  @override
  String get titleHint => '例如：意大利之夏';

  @override
  String get titleValidator => '请输入标题';

  @override
  String get fieldDestination => '目的地';

  @override
  String get destinationHint => '例如：罗马、佛罗伦萨';

  @override
  String get fieldDates => '日期';

  @override
  String get fieldNotes => '备注';

  @override
  String get accentColour => '强调色';

  @override
  String get customColour => '自定义颜色';

  @override
  String get pickColour => '选择颜色';

  @override
  String get hexColour => '十六进制';

  @override
  String get invalidHexColour => '请输入有效的十六进制颜色，例如 1565C0';

  @override
  String get createTrip => '创建旅行';

  @override
  String get saveChanges => '保存更改';

  @override
  String get itineraryTitle => '行程';

  @override
  String get deleteTrip => '删除旅行';

  @override
  String get deleteTripQuestion => '删除旅行？';

  @override
  String get deleteTripBody => '这将永久删除该旅行及其全部行程。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get nothingPlanned => '暂无行程安排。';

  @override
  String get now => '现在';

  @override
  String get today => '今天';

  @override
  String get addPlace => '添加地点';

  @override
  String addArrival(String place) {
    return '添加 $place';
  }

  @override
  String get addTransport => '添加交通';

  @override
  String get hideEntries => '收起条目';

  @override
  String get showEntries => '展开条目';

  @override
  String get editPlace => '编辑地点';

  @override
  String get editTransport => '编辑交通';

  @override
  String get fieldMode => '方式';

  @override
  String get fieldFrom => '起点';

  @override
  String get fieldTo => '终点';

  @override
  String get fieldPlace => '地点';

  @override
  String get placeHint => '例如：斗兽场';

  @override
  String get placeValidator => '请输入地点';

  @override
  String get fromToValidator => '请输入起点或终点中的至少一项';

  @override
  String get transportLabelOptional => '标签（可选）';

  @override
  String get noteTitleOptional => '备注标题（可选）';

  @override
  String get fieldDay => '日期';

  @override
  String get timeDeparts => '出发';

  @override
  String get timeArrives => '到达';

  @override
  String get timeStart => '开始';

  @override
  String get timeEnd => '结束';

  @override
  String get setTime => '设置时间';

  @override
  String get plannedTimes => '计划';

  @override
  String get actualTimes => '实际';

  @override
  String get actualTimesHint => '实际发生的情况。时间线会显示提前或延误了多久。';

  @override
  String get endDayArrives => '到达';

  @override
  String get endDayEnds => '结束';

  @override
  String get endDaySame => '当日';

  @override
  String endDayLater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天后',
      one: '次日',
    );
    return '$_temp0';
  }

  @override
  String get endDayEarlier => '提前一天';

  @override
  String get endDayLaterButton => '延后一天';

  @override
  String get endBeforeStart => '结束时间早于开始时间。是否在之后的某一天？';

  @override
  String continuationArrives(String time) {
    return '$time 到达';
  }

  @override
  String continuationUntil(String time) {
    return '至 $time';
  }

  @override
  String get continuationEnds => '当天结束';

  @override
  String get continuationAllDay => '全天持续';

  @override
  String get continuationStarted => '由前一天延续';

  @override
  String get notesOptional => '备注（可选）';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get search => '搜索';

  @override
  String get searchNoMatches => '没有匹配项';

  @override
  String searchAdd(String query) {
    return '添加「$query」';
  }

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => '英语';

  @override
  String get languageGerman => '德语';

  @override
  String get languageChinese => '中文';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get settingsTitle => '设置';

  @override
  String get databaseSection => '数据库';

  @override
  String get currentDatabase => '当前数据库';

  @override
  String get dbOpen => '打开数据库…';

  @override
  String get dbOpenSubtitle => '选择现有的 .sqlite 文件';

  @override
  String get dbNew => '新建数据库…';

  @override
  String get dbNewSubtitle => '在指定位置创建空数据库';

  @override
  String get dbNewEmpty => '新建空数据库';

  @override
  String get dbNewEmptySubtitle => '从没有旅行的状态重新开始';

  @override
  String get dbNewEmptyConfirmTitle => '开始使用新数据库？';

  @override
  String get dbNewEmptyConfirmBody =>
      '这将删除所有当前旅行，并从空数据库开始。此操作无法撤销；如果要保留数据，请先导出副本。';

  @override
  String get dbNewEmptyAction => '开始新建';

  @override
  String get dbNewEmptyDone => '已开始使用新的空数据库';

  @override
  String get dbImport => '导入数据库…';

  @override
  String get dbImportSubtitle => '使用 .sqlite 文件替换当前数据';

  @override
  String get dbExport => '导出数据库…';

  @override
  String get dbExportSubtitle => '保存当前数据库的副本';

  @override
  String get dbReset => '恢复默认设置';

  @override
  String get dbResetSubtitle => '使用应用默认的数据库位置';

  @override
  String get dbImportConfirmTitle => '导入数据库？';

  @override
  String get dbImportConfirmBody => '这将用所选文件的内容替换所有现有旅行，且无法撤销。';

  @override
  String get dbImportAction => '导入';

  @override
  String get dbOpened => '数据库已打开';

  @override
  String get dbCreated => '已创建新数据库';

  @override
  String get dbImported => '数据库已导入';

  @override
  String get dbExported => '数据库已导出';

  @override
  String get dbResetDone => '已切换到默认数据库';

  @override
  String dbError(String error) {
    return '无法完成操作：$error';
  }

  @override
  String get modeWalk => '步行';

  @override
  String get modeBike => '自行车';

  @override
  String get modeCar => '汽车';

  @override
  String get modeTaxi => '出租车';

  @override
  String get modeBus => '公交车';

  @override
  String get modeTrain => '火车';

  @override
  String get modeTram => '有轨电车';

  @override
  String get modeSubway => '地铁';

  @override
  String get modeFerry => '轮渡';

  @override
  String get modeFlight => '飞机';

  @override
  String get modeOther => '其他';

  @override
  String get modeSki => '滑雪';

  @override
  String get widgetNoTripsTitle => '还没有旅行';

  @override
  String get widgetNoTripsBody => '点按规划下一次旅程';

  @override
  String widgetInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天后',
      one: '1 天后',
    );
    return '$_temp0';
  }

  @override
  String get widgetTomorrow => '明天开始';

  @override
  String get widgetEndedYesterday => '昨天结束';

  @override
  String widgetEndedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前结束',
      one: '1 天前结束',
    );
    return '$_temp0';
  }

  @override
  String widgetDayXofY(int current, int total) {
    return '第 $current / $total 天';
  }

  @override
  String get widgetTodayHeader => '今天';

  @override
  String widgetMoreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有 $count 项',
      one: '还有 1 项',
    );
    return '$_temp0';
  }

  @override
  String get addCost => '添加费用';

  @override
  String get editCost => '编辑费用';

  @override
  String get costAmount => '金额';

  @override
  String get costCurrency => '货币';

  @override
  String get costReason => '类别';

  @override
  String get costReasonHint => '例如：酒店、晚餐、火车票';

  @override
  String get costReasonLabel => '类别名称';

  @override
  String get costAmountInvalid => '请输入有效金额';

  @override
  String get costReasonRequired => '请输入类别';

  @override
  String get costsTotal => '合计';

  @override
  String get costs => '费用';

  @override
  String get generalCosts => '一般费用';

  @override
  String get costReasonsSection => '费用类别';

  @override
  String get costReasonDisplay => '在费用标签上显示';

  @override
  String get costReasonDisplayIcon => '图标';

  @override
  String get costReasonDisplayText => '文字';

  @override
  String get costReasonDisplayBoth => '图文';

  @override
  String get costReasonDisplayHelp =>
      '费用标签上的类别显示方式——图标：仅显示符号；文字：仅显示名称；图文：同时显示符号和名称。金额始终显示。';

  @override
  String get costReasonAdd => '添加类别';

  @override
  String get costReasonAddTitle => '新建类别';

  @override
  String get costReasonRenameTitle => '重命名类别';

  @override
  String get costReasonChooseIcon => '选择图标';

  @override
  String get costReasonDeleteConfirmTitle => '删除类别？';

  @override
  String costReasonDeleteConfirmBody(String reason) {
    return '「$reason」将从类别列表中移除。现有费用会保留其文字。';
  }

  @override
  String get noCostReasons => '还没有保存的类别';

  @override
  String get transportModesSection => '交通方式';

  @override
  String get transportModeAdd => '添加方式';

  @override
  String get transportModeAddTitle => '新建交通方式';

  @override
  String get transportModeRenameTitle => '重命名方式';

  @override
  String get transportModeLabel => '名称';

  @override
  String get transportModeHint => '例如：缆车';

  @override
  String get transportModeChooseIcon => '选择图标';

  @override
  String get transportModeDeleteConfirmTitle => '删除交通方式？';

  @override
  String transportModeDeleteConfirmBody(String mode) {
    return '「$mode」将从交通方式列表中移除。使用该方式的现有交通路段会保留路线，但会失去交通方式。';
  }

  @override
  String get noTransportModes => '还没有交通方式';

  @override
  String get costPaidBy => '付款人';

  @override
  String get costPaid => '已付款';

  @override
  String get costPaidFor => '分摊成员';

  @override
  String get costInvited => '请客';

  @override
  String costInvitedBy(String payer) {
    return '由 $payer 请客';
  }

  @override
  String get costInvitedHint => '被请客的人无需分摊。点按上方的姓名可只请其中几位。';

  @override
  String get costPaidByNone => '未指定';

  @override
  String costPaidByName(String name) {
    return '由 $name 付款';
  }

  @override
  String get addTransfer => '记录结算';

  @override
  String get editTransfer => '编辑结算';

  @override
  String get transfer => '结算';

  @override
  String get transfers => '结算记录';

  @override
  String get transferFrom => '转出';

  @override
  String get transferTo => '转入';

  @override
  String get transferPersonRequired => '请选择一位成员';

  @override
  String get transferSamePerson => '请选择两位不同的成员';

  @override
  String get transferAmountPositive => '请输入大于零的金额';

  @override
  String transferBetween(String from, String to) {
    return '$from → $to';
  }

  @override
  String get transferHint => '结算用于成员之间转移钱款，仅改变余额，不会改变旅行总额。';

  @override
  String get reimbursement => '报销';

  @override
  String get reimbursements => '报销记录';

  @override
  String get transferReimbursement => '来自团队外部的报销';

  @override
  String get transferReimbursementHint =>
      '用于记录来自旅行之外的钱款，例如雇主补贴。它不会改变任何人的余额，也不会改变旅行总额，但会显示在统计中。';

  @override
  String get currenciesSection => '货币';

  @override
  String get currencyAdd => '添加货币';

  @override
  String get currencyAddTitle => '新建货币';

  @override
  String get currencyEditTitle => '编辑货币';

  @override
  String get currencyCode => '代码';

  @override
  String get currencyCodeHint => '例如：JPY';

  @override
  String get currencyCodeRequired => '请输入代码';

  @override
  String get currencySymbol => '符号';

  @override
  String get currencySymbolHint => '例如：¥';

  @override
  String get currencyRate => '汇率';

  @override
  String get currencyRateInvalid => '请输入大于零的数字';

  @override
  String get currencyRateNone => '未设置汇率';

  @override
  String currencyRateExplains(String code, String rate, String base) {
    return '1 $code = $rate $base';
  }

  @override
  String currencyRateHelp(String code, String base) {
    return '1 $code 折合多少 $base。如果不想换算，可留空。';
  }

  @override
  String get currencyBase => '基准货币';

  @override
  String get currencyBaseHelp =>
      '所有汇率都以基准货币表示，新费用也默认使用基准货币。多种货币的总额会换算成基准货币——与各币种的精确金额并列显示，而不会取而代之。';

  @override
  String get currencyMakeBase => '设为基准货币';

  @override
  String get currencyRebaseWarnTitle => '更改基准货币？';

  @override
  String currencyRebaseWarnBody(String code) {
    return '「$code」没有汇率，因此其他货币的汇率无法以其为基准重新表示，现有汇率将被清除。之后你可以重新输入。';
  }

  @override
  String currencyInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 笔费用',
      one: '1 笔费用',
    );
    return '已用于 $_temp0';
  }

  @override
  String get currencyDeleteConfirmTitle => '删除货币？';

  @override
  String currencyDeleteConfirmBody(String code) {
    return '「$code」将从货币列表中移除。';
  }

  @override
  String currencyDeleteBlockedInUse(String code, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 笔费用',
      one: '1 笔费用',
    );
    return '「$code」仍被 $_temp0使用。金额不能没有货币。';
  }

  @override
  String get currencyDeleteBlockedBase => '无法删除基准货币。请先将另一种货币设为基准货币。';

  @override
  String get currencyCodeTaken => '该代码已在列表中';

  @override
  String get noCurrencies => '还没有货币';

  @override
  String get peopleSection => '成员';

  @override
  String get noPeople => '还没有保存的成员';

  @override
  String get personAdd => '添加成员';

  @override
  String get personAddTitle => '新建成员';

  @override
  String get personRenameTitle => '重命名成员';

  @override
  String get personLabel => '姓名';

  @override
  String get personHint => '例如：Alex';

  @override
  String get personDeleteConfirmTitle => '删除成员？';

  @override
  String personDeleteConfirmBody(String name) {
    return '「$name」将从成员列表中移除。现有费用会保留其付款人。';
  }

  @override
  String get personMarkAsMe => '标记为我';

  @override
  String get personIsMe => '这是我';

  @override
  String get myCostsTotal => '我的费用';

  @override
  String get expenseScopeAll => '全部';

  @override
  String get expenseScopeMine => '我的';

  @override
  String get participants => '参与者';

  @override
  String get addParticipant => '添加参与者';

  @override
  String get statsTitle => '统计';

  @override
  String get statsAllTripsTitle => '总览统计';

  @override
  String get mapTitle => '地图';

  @override
  String get mapOpen => '在地图上显示';

  @override
  String get mapNothingToShow => '还没有可显示的内容';

  @override
  String get mapNothingToShowHint => '地点和路段获得坐标后会显示在这里——导入的路线自带坐标。';

  @override
  String mapTripsHere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '此处有 $count 次旅行',
      one: '此处有 1 次旅行',
    );
    return '$_temp0';
  }

  @override
  String mapEntriesHere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '此处有 $count 个条目',
      one: '此处有 1 个条目',
    );
    return '$_temp0';
  }

  @override
  String get mapColor => '地图上的颜色';

  @override
  String get mapColorHint => '为该条目的轨迹或标记着色，旅行的其他内容不受影响。';

  @override
  String get mapColorTrip => '旅行颜色';

  @override
  String get trackSection => '地图上的轨迹';

  @override
  String get trackImport => '导入 GPX…';

  @override
  String get trackRemove => '移除';

  @override
  String get trackShow => '在地图上绘制';

  @override
  String get trackHide => '不绘制';

  @override
  String get trackRemoveAll => '全部移除';

  @override
  String get trackSourceRecorded => '已记录';

  @override
  String get trackSourceImported => '已导入';

  @override
  String get trackSourceRouted => '计算轨迹';

  @override
  String get trackNotDrawable => '无可绘制内容';

  @override
  String get trackNone => '无——路段的两端都有坐标后才会绘制。';

  @override
  String get trackChord => '直线';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条轨迹',
      one: '1 条轨迹',
    );
    return '$_temp0';
  }

  @override
  String get trackImportTitle => '导入记录的轨迹';

  @override
  String get trackPickEntries => '它覆盖哪些条目？';

  @override
  String get trackPickEntriesHint => '一次选择一段连续的条目——轨迹会在它们之间分配。';

  @override
  String get trackPickOptionHint => '行程出现分支时，请选择该轨迹所走的选项。';

  @override
  String get trackPickOption => '该轨迹走的是哪个选项？';

  @override
  String get trackOptionNotChosen => '不是旅行所采用的选项';

  @override
  String trackTapBoundary(String before, String after) {
    return '点按「$before」交接到「$after」的位置';
  }

  @override
  String trackMoveBoundary(String before, String after) {
    return '点按移动「$before」交接到「$after」的位置';
  }

  @override
  String trackHandoverChip(int number) {
    return '交接点 $number';
  }

  @override
  String get trackImportConfirm => '导入';

  @override
  String trackImportSummary(int legs, int ends) {
    String _temp0 = intl.Intl.pluralLogic(
      legs,
      locale: localeName,
      other: '$legs 个条目',
      one: '1 个条目',
    );
    String _temp1 = intl.Intl.pluralLogic(
      ends,
      locale: localeName,
      other: '已设置 $ends 个坐标',
      one: '已设置 1 个坐标',
      zero: '未设置坐标',
    );
    return '$_temp0，$_temp1';
  }

  @override
  String get trackNoLegsPicked => '请至少选择一条交通路段';

  @override
  String get trackImported => '轨迹已导入';

  @override
  String get trackNothingInFile => '该文件中没有轨迹';

  @override
  String get trackInvalidFile => '该文件不是可读取的 GPX';

  @override
  String get mapZoomIn => '放大';

  @override
  String get mapZoomOut => '缩小';

  @override
  String get mapFullscreen => '全屏地图';

  @override
  String get mapExitFullscreen => '退出全屏';

  @override
  String get mapMyLocationShow => '显示我的位置';

  @override
  String get mapMyLocationCenter => '居中到我的位置（长按隐藏）';

  @override
  String get mapUseMyLocation => '使用我的位置';

  @override
  String get mapLocationDenied => '位置访问已被拒绝';

  @override
  String get mapLocationBlocked => '此应用的位置访问权限已被阻止';

  @override
  String get mapLocationServiceOff => '此设备的位置服务已关闭';

  @override
  String get mapLocationFailed => '无法确定你的位置';

  @override
  String get mapLocationOpenSettings => '设置';

  @override
  String get mapPickConfirm => '使用此点';

  @override
  String get mapPickTitlePlace => '选择地点';

  @override
  String get mapPickTitleFrom => '选择起点';

  @override
  String get mapPickTitleTo => '选择终点';

  @override
  String get coordinatesLabel => '坐标';

  @override
  String get coordinatesFrom => '起点坐标';

  @override
  String get coordinatesTo => '终点坐标';

  @override
  String get coordinatesNone => '未设置';

  @override
  String get coordinatesPick => '在地图上选择';

  @override
  String get coordinatesClear => '移除位置';

  @override
  String get mapPickHint => '点按地图放置点';

  @override
  String get connectionUseMyPosition => '使用我的位置';

  @override
  String get connectionPickOnMap => '在地图上选择';

  @override
  String get mapView => '地图';

  @override
  String get statsOpen => '统计';

  @override
  String get statsAllTripsOpen => '总览统计';

  @override
  String get statsTabExpenses => '费用';

  @override
  String countriesRatio(int visited, int total, int percent) {
    return '$visited / $total · $percent%';
  }

  @override
  String get countriesWorld => '全球';

  @override
  String get regionAfrica => '非洲';

  @override
  String get regionAsia => '亚洲';

  @override
  String get regionEurope => '欧洲';

  @override
  String get regionNorthAmerica => '北美洲';

  @override
  String get regionSouthAmerica => '南美洲';

  @override
  String get regionOceania => '澳大利亚和大洋洲';

  @override
  String get regionAntarctica => '南极洲';

  @override
  String get statsTabCountries => '国家';

  @override
  String countriesVisited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个国家',
      one: '1 个国家',
      zero: '还没有国家',
    );
    return '$_temp0';
  }

  @override
  String get statsTabTransport => '交通';

  @override
  String get statsNoData => '还没有可分析的费用';

  @override
  String get statsNoTransport => '还没有可分析的交通路段';

  @override
  String get statsByCategory => '按类别';

  @override
  String get statsByMode => '按方式';

  @override
  String get statsScopeLegs => '路段';

  @override
  String get statsScopeTime => '时间';

  @override
  String statsLegs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条路段',
      one: '1 条路段',
    );
    return '$_temp0';
  }

  @override
  String statsTotalTime(String duration) {
    return '共 $duration';
  }

  @override
  String get statsByPerson => '按成员';

  @override
  String get statsScopePaid => '已付';

  @override
  String get statsScopeShare => '分摊';

  @override
  String get statsScopeBalances => '结余';

  @override
  String get statsPaidShort => '已付';

  @override
  String get statsShareShort => '分摊';

  @override
  String get statsSettleUp => '结清';

  @override
  String get statsSettledUp => '大家都已结清——无需结算。';

  @override
  String get statsGetsBack => '应收';

  @override
  String get statsOwes => '应付';

  @override
  String get statsEven => '已结清';

  @override
  String statsExpenses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 笔费用',
      one: '1 笔费用',
    );
    return '$_temp0';
  }

  @override
  String statsPaidAmount(String amount, int percent) {
    return '已付 $amount（$percent%）';
  }

  @override
  String statsOpenAmount(String amount, int percent) {
    return '未结 $amount（$percent%）';
  }

  @override
  String statsTransfer(String from, String to) {
    return '$from 付给 $to';
  }

  @override
  String get statsRecordSettlement => '记录';

  @override
  String statsSettlementSent(String amount) {
    return '已还 $amount';
  }

  @override
  String statsSettlementReceived(String amount) {
    return '已收到 $amount';
  }

  @override
  String statsInvitedTo(String amount) {
    return '被请客 $amount';
  }

  @override
  String statsInvitedOthers(String amount) {
    return '请客 $amount';
  }

  @override
  String statsReimbursedAmount(String amount) {
    return '已报销 $amount';
  }

  @override
  String get statsReimbursedBy => '报销方';

  @override
  String get statsNoSource => '无来源';

  @override
  String statsReimbursementLine(String share, String reimbursed, String own) {
    return '分摊 $share · 报销 $reimbursed · 自付 $own';
  }

  @override
  String get checklist => '清单';

  @override
  String get checklistAddHint => '添加项目…';

  @override
  String get checklistEditTitle => '编辑项目';

  @override
  String get checklistRenameTitle => '重命名清单';

  @override
  String get checklistNewTitle => '新建清单';

  @override
  String get checklistAdd => '添加清单';

  @override
  String get checklistDeleteTitle => '删除清单？';

  @override
  String checklistDeleteBody(String name) {
    return '「$name」及其所有项目将被移除。';
  }

  @override
  String get checklistActions => '清单操作';

  @override
  String get checklistDelete => '删除清单';

  @override
  String get checklistDuplicate => '创建副本';

  @override
  String checklistCopyTitle(String name) {
    return '$name（副本）';
  }

  @override
  String get checklistCopyToTrip => '复制到旅行…';

  @override
  String get checklistMoveToTrip => '移动到旅行…';

  @override
  String get tripPickerTitle => '选择哪次旅行？';

  @override
  String get checklistNoOtherTrips => '还没有其他旅行可放入。';

  @override
  String checklistCopiedTo(String trip) {
    return '已复制到「$trip」。不会复制勾选状态——清单只能以空白状态复用。';
  }

  @override
  String checklistMovedTo(String trip) {
    return '已移动到「$trip」。';
  }

  @override
  String get moveOrCopy => '移动或复制';

  @override
  String get moveOrCopyHint => '拿起此条目，再选择放置位置——其他日期或某个选项。';

  @override
  String get moveToDots => '移动到…';

  @override
  String get copyToDots => '复制到…';

  @override
  String get duplicateEntry => '创建副本';

  @override
  String get moveHere => '移动到这里';

  @override
  String get copyHere => '复制到这里';

  @override
  String holdingMove(String entry) {
    return '正在移动：$entry';
  }

  @override
  String holdingCopy(String entry) {
    return '正在复制：$entry';
  }

  @override
  String get holdingHint => '在任意日期或选项上点按「移动到这里」或「复制到这里」。';

  @override
  String get untitledEntry => '未命名条目';

  @override
  String get copiedWithoutCosts => '已复制。不会复制费用——因为付款只发生过一次。';

  @override
  String putIntoUnchosenOption(String option) {
    return '已放入 $option——当前选择其他选项时，它不会计入旅行。';
  }

  @override
  String get alternatives => '备选方案';

  @override
  String get planAlternatives => '规划备选方案';

  @override
  String get planAlternativesHint => '将此条目转为分支：规划多个选项，再选定最终采用的一项。';

  @override
  String get itemInOptionHint => '属于某个选项——仅在该选项被选用时计入旅行。';

  @override
  String get decisionDefaultLabel => '分支';

  @override
  String get decisionActions => '分支操作';

  @override
  String get decisionRename => '重命名分支';

  @override
  String get decisionNameLabel => '分支名称（可选）';

  @override
  String get decisionNameHint => '例如：周六下午';

  @override
  String get decisionDelete => '删除分支';

  @override
  String get decisionDeleteQuestion => '删除此分支？';

  @override
  String get decisionDeleteBody => '所有选项及其条目和费用都将被删除。';

  @override
  String optionLetter(String letter) {
    return '选项 $letter';
  }

  @override
  String get optionChosen => '已选用';

  @override
  String get optionChoose => '选用此选项';

  @override
  String get optionEmpty => '该选项暂无计划内容。';

  @override
  String get optionAdd => '添加选项';

  @override
  String get optionDuplicate => '复制选项';

  @override
  String get optionRename => '重命名选项';

  @override
  String get optionNameLabel => '选项名称（可选）';

  @override
  String get optionNameHint => '例如：博物馆日';

  @override
  String get optionDelete => '删除选项';

  @override
  String get optionDeleteQuestion => '删除此选项？';

  @override
  String get optionDeleteBody => '其中的条目及其费用也会被删除，其他选项会保留。';

  @override
  String get optionKeepOnly => '仅保留此选项';

  @override
  String get optionKeepOnlyQuestion => '仅保留此选项？';

  @override
  String get optionKeepOnlyBody => '其中的条目会移回当天，其他选项将被删除。';

  @override
  String get optionPrevious => '上一个选项';

  @override
  String get optionNext => '下一个选项';

  @override
  String get grouping => '分组';

  @override
  String get groupActions => '分组操作';

  @override
  String get groupWithNext => '与下一项编组';

  @override
  String get groupRename => '重命名分组';

  @override
  String get groupMoveTo => '移动分组到…';

  @override
  String get groupCopyTo => '复制分组到…';

  @override
  String get groupRemoveItem => '从分组中移除';

  @override
  String get groupUngroup => '取消编组';

  @override
  String get groupDelete => '删除分组';

  @override
  String get groupDeleteQuestion => '删除此分组？';

  @override
  String get groupDeleteBody => '其中的条目及其所有费用（包括共同费用）会一并删除。若要保留条目，请改为取消编组。';

  @override
  String get groupNameLabel => '分组名称（可选）';

  @override
  String get groupNameHint => '例如：前往罗马的火车';

  @override
  String get groupDefaultLabel => '已编组';

  @override
  String get groupSharedExpenses => '共同费用';

  @override
  String get groupMemberHint => '属于同个分组——共同费用适用于其中的所有项目。';

  @override
  String get calendarView => '日历视图';

  @override
  String get listView => '列表视图';

  @override
  String get calendarToday => '今天';

  @override
  String get calendarPreviousMonth => '上个月';

  @override
  String get calendarNextMonth => '下个月';

  @override
  String get calendarUndatedTitle => '无日期的旅行';

  @override
  String get calendarUndatedTooltip => '显示无日期的旅行';

  @override
  String get connectionSearch => '搜索路线';

  @override
  String get connectionSearchOnline => '在线搜索';

  @override
  String get connectionFrom => '起点';

  @override
  String get connectionTo => '终点';

  @override
  String get connectionVia => '途经站点';

  @override
  String get connectionViaAdd => '添加途经站点';

  @override
  String get connectionViaRemove => '移除途经站点';

  @override
  String get connectionViaHint => '只有车站可以作为途经站点。';

  @override
  String get connectionViaStay => '至少停留';

  @override
  String get connectionViaStayNone => '无限制';

  @override
  String connectionSummaryVia(String stops) {
    return '途经 $stops';
  }

  @override
  String get connectionEditSearch => '编辑搜索';

  @override
  String get connectionPickPlace => '搜索车站或地点';

  @override
  String get connectionPickStop => '搜索车站';

  @override
  String get connectionDepart => '出发时间';

  @override
  String get connectionArrive => '到达时间';

  @override
  String get connectionBudgetsTitle => '往返站点的时间';

  @override
  String get connectionBudgetsHint => '仅当从地址而非车站搜索时，才会应用首段和末段时间。';

  @override
  String get connectionBudgetAuto => '自动';

  @override
  String get connectionBudgetPre => '到首个站点';

  @override
  String get connectionBudgetPost => '从最后一站';

  @override
  String get connectionBudgetDirect => '全程不乘坐公共交通';

  @override
  String connectionSummaryToStop(int minutes) {
    return '到站 ≤$minutes 分钟';
  }

  @override
  String connectionSummaryFromStop(int minutes) {
    return '离站 ≤$minutes 分钟';
  }

  @override
  String connectionSummaryOwnWay(int minutes) {
    return '自行接驳 ≤$minutes 分钟';
  }

  @override
  String get connectionRoutedTransfers => 'Time changes by the actual walk';

  @override
  String get connectionRoutedTransfersHint =>
      'Work out each change from the actual path between the stops on OpenStreetMap, instead of precomputed standard times. Finds tight cross-platform changes; only as accurate as the map.';

  @override
  String get connectionRoutedTransfersImplied =>
      'Always on for step-free travel.';

  @override
  String get connectionSummaryRoutedTransfers => 'changes timed by walk';

  @override
  String get connectionWheelchair => '无障碍通行';

  @override
  String get connectionWheelchairHint =>
      '仅显示无台阶的步行和换乘，以及标注为无障碍的班次。许多交通网络并未公布此类信息，因此可能查不到或结果很少。';

  @override
  String get connectionNoAccessibleConnections => '未找到无障碍路线';

  @override
  String get connectionByBike => '骑行出行';

  @override
  String get connectionByBikeHint => '全程骑行，或骑到首个站点。';

  @override
  String get connectionBikeOnBoard => '可携带自行车';

  @override
  String get connectionBikeOnBoardHint =>
      '仅显示允许携带自行车的班次。许多交通网络并未公布此类信息，因此可能查不到结果。';

  @override
  String get connectionCyclingSpeed => '骑行速度';

  @override
  String get connectionCyclingSpeedHint => '用于计算骑行路段。';

  @override
  String get connectionNoBikeConnections => '未找到可携带自行车的路线';

  @override
  String get connectionCancelled => '已取消';

  @override
  String get connectionWithoutTransit => '不含公共交通';

  @override
  String get connectionSearchNoResults => '未找到路线';

  @override
  String get connectionEarlier => '更早';

  @override
  String get connectionLater => '更晚';

  @override
  String get connectionSearchError => '无法访问路线查询服务';

  @override
  String get connectionRetry => '重试';

  @override
  String connectionChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次换乘',
      one: '1 次换乘',
      zero: '直达',
    );
    return '$_temp0';
  }

  @override
  String connectionChangeIn(int minutes, String place) {
    return '在 $place 换乘，$minutes 分钟';
  }

  @override
  String connectionChangeBetween(int minutes, String from, String to) {
    return '换乘 $minutes 分钟：$from → $to';
  }

  @override
  String connectionChangeNow(int minutes) {
    return '当前 $minutes 分钟';
  }

  @override
  String get connectionOptionsTitle => '搜索选项';

  @override
  String get connectionOptionsReset => '重置';

  @override
  String get connectionMinTransfer => '最短换乘时间';

  @override
  String get connectionMinTransferHint => '到达后再次出发之间的间隔不能短于此时间。';

  @override
  String get connectionMinTransferAny => '不限';

  @override
  String connectionMinutesShort(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String connectionHoursShort(int hours) {
    return '$hours 小时';
  }

  @override
  String connectionHoursMinutesShort(int hours, int minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String get connectionWalkingSpeed => '步行速度';

  @override
  String get connectionWalkingSpeedHint => '用于计算往返及车站之间的步行路段。';

  @override
  String connectionSpeedValue(String speed) {
    return '$speed 千米/小时';
  }

  @override
  String get connectionSpeedNormal => '正常';

  @override
  String get connectionMaxTransfers => '最多换乘次数';

  @override
  String get connectionMaxTransfersAny => '不限';

  @override
  String get connectionMaxTransfersDirect => '直达';

  @override
  String connectionMaxTransfersAtMost(int count) {
    return '≤$count';
  }

  @override
  String connectionSummaryMinTransfer(int minutes) {
    return '换乘间隔 ≥ $minutes 分钟';
  }

  @override
  String connectionSummaryMaxChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '最多 $count 次换乘',
      one: '最多 1 次换乘',
      zero: '仅直达',
    );
    return '$_temp0';
  }

  @override
  String get connectionModesTitle => '交通工具';

  @override
  String get connectionModesSubtitle => '规划路线时只使用这些交通工具。';

  @override
  String get connectionModesAll => '所有交通工具';

  @override
  String get connectionModesNone => '不使用交通工具';

  @override
  String get connectionModeLongDistance => '长途列车';

  @override
  String get connectionModeRegional => '区域列车';

  @override
  String get connectionModeCity => '地铁与有轨电车';

  @override
  String get connectionModeBus => '公交车与长途客车';

  @override
  String get connectionModeFerry => '轮渡';

  @override
  String get connectionModeAir => '航班';

  @override
  String get connectionModeOther => '缆车及其他';

  @override
  String get connectionAddToDay => '添加到当天';

  @override
  String get connectionAdded => '路线已添加';

  @override
  String get connectionSaveToTrip => '保存到旅行…';

  @override
  String connectionSavedTo(String trip) {
    return '已添加到「$trip」';
  }

  @override
  String get attributionOsm => '© OpenStreetMap 贡献者';

  @override
  String get attributionTransitous => '时刻表数据来自 Transitous';

  @override
  String get dataSourcesSection => '数据来源';

  @override
  String get dataSourcesNote => '路线查询使用开放许可的时刻表和地图数据：';

  @override
  String linkOpenFailed(String url) {
    return '无法打开 $url';
  }

  @override
  String get transportModeRestoreBuiltin => '恢复内置';

  @override
  String platformShort(String track) {
    return '站台 $track';
  }

  @override
  String platformFromShort(String track) {
    return '从 $track 站台';
  }

  @override
  String platformToShort(String track) {
    return '到 $track 站台';
  }

  @override
  String directionTo(String destination) {
    return '开往 $destination';
  }

  @override
  String connectionStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '经停 $count 站',
      one: '经停 1 站',
    );
    return '$_temp0';
  }

  @override
  String connectionStopsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 站已取消',
      one: '1 站已取消',
    );
    return '$_temp0';
  }

  @override
  String connectionChangePlace(String place) {
    return '在 $place 换乘';
  }

  @override
  String connectionChangePlaces(String from, String to) {
    return '换乘：$from → $to';
  }

  @override
  String get journeyDetails => '查看行程';

  @override
  String get liveTimesRefresh => '更新实时信息';

  @override
  String get liveTimesNone => '没有可更新的实时信息';

  @override
  String get liveTimesCancelled => '该班次已取消';

  @override
  String get liveTimesError => '无法获取实时信息';

  @override
  String get tripKindTrip => '旅行';

  @override
  String get tripKindRoutine => '模板行程';

  @override
  String get tripKindTripBody => '日历上的旅行——一天或多天。';

  @override
  String get tripKindRoutineBody => '没有日期的可复用计划。每次出行时，都可以据此创建一次真实旅行。';

  @override
  String get newRoutine => '新建模板行程';

  @override
  String get editRoutine => '编辑模板行程';

  @override
  String get routinesTitle => '模板行程';

  @override
  String get noRoutinesTitle => '还没有模板行程';

  @override
  String get noRoutinesBody =>
      '模板行程是可以反复使用的计划——例如通勤路线、每周六的骑行。创建一个模板行程，之后每次出行时都可以据此创建旅行。';

  @override
  String get noRoutinesFoundTitle => '没有匹配的模板行程';

  @override
  String noRoutinesFoundBody(String query) {
    return '没有与「$query」匹配的模板行程。';
  }

  @override
  String get searchRoutines => '搜索模板行程';

  @override
  String get searchRoutinesHint => '标题、目的地或备注';

  @override
  String get filterRoutines => '筛选与排序';

  @override
  String get routineNoDates => '无日期';

  @override
  String get routineFromRoutine => '从模板行程…';

  @override
  String get routineCreateTrip => '创建旅行';

  @override
  String get routineCreateTripFor => '创建旅行，日期为';

  @override
  String get routineStartDate => '开始日期';

  @override
  String get routineLookUpConnections => '搜索当前路线';

  @override
  String get routineLookUpConnectionsBody => '在所选日期搜索此计划中的各段旅程，以便更新实时信息。';

  @override
  String get routineCreated => '旅行已创建。';

  @override
  String get routineCreatedOpen => '打开';

  @override
  String get routineDuplicateReversed => '复制并反转';

  @override
  String routineReversedSuffix(String title) {
    return '$title（返程）';
  }

  @override
  String get routineAlreadyRecordedTitle => '已记录';

  @override
  String routineAlreadyRecordedBody(String title, String date) {
    return '「$title」已有一个从 $date 开始的旅行。要再创建一个吗？';
  }

  @override
  String get routineCreateAnyway => '仍要创建';

  @override
  String routineNewDay(int number) {
    return '第 $number 天（新）';
  }

  @override
  String get routineAddDay => '添加一天';

  @override
  String routineDayNumber(int number) {
    return '第 $number 天';
  }

  @override
  String get connectionsNotFound => '未找到路线——计划已按原样复制。';

  @override
  String get connectionsNotTaken => '有一段路线无法沿用——计划已保留。';

  @override
  String get connectionsOffline => '无法连接到路线服务。计划已按原样复制。';

  @override
  String get connectionsKeepPlan => '保留计划';

  @override
  String get connectionsUseThis => '使用此路线';

  @override
  String get connectionsSearching => '正在查询路线…';

  @override
  String get connectionsFindForLeg => '查找路线';

  @override
  String get filterRoutineLabel => '来自模板行程';

  @override
  String get filterRoutineAny => '任意模板行程';

  @override
  String get tagsLabel => '标签';

  @override
  String get tagsManage => '管理标签';

  @override
  String get tagsNone => '还没有标签';

  @override
  String get tagsAddHint => '新建标签';

  @override
  String get tagsAdd => '添加标签';

  @override
  String get tagsFilterLabel => '已加标签';

  @override
  String get tagsAll => '全部';

  @override
  String get tagDeleteQuestion => '删除此标签？';

  @override
  String get tagDeleteBody => '它会从所有带有此标签的旅行中移除，旅行本身不受影响。';

  @override
  String get tagRename => '重命名标签';

  @override
  String get tagNameLabel => '名称';

  @override
  String get tagDuplicate => '已存在同名标签。';

  @override
  String get aboutSection => '关于';

  @override
  String get aboutCiBuild => 'CI 测试版本';

  @override
  String get aboutCiBuildSubtitle => '与正式版应用并存，使用独立的数据库。请勿用于真实旅行。';

  @override
  String get aboutVersion => '版本';

  @override
  String get aboutVersionCopied => '版本号已复制';

  @override
  String get aboutSourceCode => '源代码';

  @override
  String get aboutReportIssue => '反馈问题';

  @override
  String get aboutContact => '联系我们';

  @override
  String get aboutLicenses => '开源许可';

  @override
  String get aboutLicensesSubtitle => '此应用所使用的库和字体';

  @override
  String get attachmentsLabel => '附件';

  @override
  String get attachmentsAddPhoto => '添加照片';

  @override
  String get attachmentsAddFile => '添加文件';

  @override
  String get attachmentsAdding => '正在读取文件…';

  @override
  String get attachmentsAddedOne => '已添加附件。';

  @override
  String attachmentsAddedMany(int count) {
    return '已添加 $count 个文件。';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个附件',
      one: '1 个附件',
    );
    return '$_temp0';
  }

  @override
  String attachmentTooLarge(String size, String limit) {
    return '该文件大小为 $size——上限为 $limit。导出旅行时会复制整个数据库，大文件可能导致无法移动。';
  }

  @override
  String attachmentUnreadableImage(String format) {
    return '无法读取此图片格式（$format）。请先另存为 JPEG 或 PNG。';
  }

  @override
  String attachmentLocationRedacted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Android 未提供这些照片的拍摄位置。你可以手动设置位置。',
      one: 'Android 未提供此照片的拍摄位置。你可以手动设置位置。',
    );
    return '$_temp0';
  }

  @override
  String get attachmentUnreadable => '无法读取该文件。';

  @override
  String get attachmentRename => '重命名';

  @override
  String get attachmentNameLabel => '名称';

  @override
  String get attachmentOpen => '打开';

  @override
  String get attachmentOpenNoApp => '此设备上没有可打开该文件的应用。但你仍可将其分享给支持该文件的应用。';

  @override
  String get attachmentMore => '更多';

  @override
  String get attachmentShare => '分享';

  @override
  String get attachmentDelete => '删除';

  @override
  String get attachmentDeleteQuestion => '删除此附件？';

  @override
  String get attachmentDeleteBody => '该文件仅存储在此数据库中。此处删除后将永久移除。';

  @override
  String get attachmentPositionExif => '使用照片中的位置';

  @override
  String get attachmentPositionPicked => '使用地图上选择的位置';

  @override
  String get attachmentPositionNone => '无位置';

  @override
  String get attachmentPositionSet => '在地图上设置';

  @override
  String get attachmentPositionClear => '移除位置';

  @override
  String get photosSection => '照片';

  @override
  String get photoLocationTitle => '读取照片拍摄位置';

  @override
  String get photoLocationSubtitle =>
      '除非获得许可，否则 Android 会隐藏照片的拍摄位置。开启后会请求该权限；关闭后，即使 Android 提供位置，也会在附加照片时将其移除。';

  @override
  String get photoLocationStillGranted =>
      '照片将不附带位置信息。Android 会保留此权限，直到你在系统设置中撤销它。';

  @override
  String get photoLocationDenied => 'Android 未允许此权限。照片将在不附带位置的情况下添加，你可以手动设置位置。';

  @override
  String get photoLocationBlocked => 'Android 不会再次询问。你仍可在系统设置中此应用的页面上允许该权限。';

  @override
  String get photoLocationOpenSettings => '打开设置';

  @override
  String get attachmentPhotoOpenFailed => '无法打开该文件。';

  @override
  String get pdfSectionPhotos => '照片';

  @override
  String pdfPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张照片',
      one: '1 张照片',
    );
    return '$_temp0';
  }

  @override
  String get pdfPhotoUnnamed => '照片';

  @override
  String get attachmentSaved => '文件已保存。';

  @override
  String get attachmentsTripTitle => '旅行文档';

  @override
  String get attachmentsTripAdd => '添加旅行文档';

  @override
  String get galleryTitle => '照片';

  @override
  String get galleryPrevious => '上一张照片';

  @override
  String get galleryNext => '下一张照片';

  @override
  String get coverSet => '设为旅行封面';

  @override
  String get coverRemove => '取消旅行封面';

  @override
  String photosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张照片',
      one: '1 张照片',
    );
    return '$_temp0';
  }

  @override
  String documentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文档',
      one: '1 个文档',
    );
    return '$_temp0';
  }

  @override
  String get documentsTitle => '文档';

  @override
  String get photosTitle => '照片';
}
