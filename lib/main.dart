import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'data/market.dart';
import 'widgets/chart.dart';
import 'widgets/score_panel.dart';
import 'widgets/pattern_analysis.dart';
import 'widgets/settings_panel.dart';

const ink = Color(0xff050816);
const surface = Color(0xff0c1327);
const edge = Color(0xff202b43);
const muted = Color(0xff97a7c3);
const cyan = Color(0xff56dcf2);
const green = Color(0xff46dba7);
const red = Color(0xffff7886);
const quick = ['BIST:THYAO', 'BIST:ASELS', 'BIST:GARAN', 'BINANCE:BTCUSDT', 'NASDAQ:AAPL', 'NASDAQ:NVDA'];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  runApp(EasyLocalization(
    supportedLocales: const [Locale('tr'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('tr'),
    startLocale: const Locale('tr'),
    child: const TradeMindApp(),
  ));
}
class TradeMindApp extends StatelessWidget {
  const TradeMindApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'TradeMind', debugShowCheckedModeBanner: false,
    localizationsDelegates: context.localizationDelegates,
    supportedLocales: context.supportedLocales,
    locale: context.locale,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: ink,
      colorScheme: const ColorScheme.dark(primary: cyan, secondary: Color(0xff9595ff), surface: surface),
      textTheme: ThemeData.dark().textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      dividerColor: edge,
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface, isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: edge)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: edge))),
      chipTheme: ChipThemeData(backgroundColor: surface, side: const BorderSide(color: edge), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ), home: const Dashboard());
}
class Dashboard extends StatefulWidget {
  final MarketApi? api;
  final bool autoLoad;
  const Dashboard({super.key, this.api, this.autoLoad = true});
  @override State<Dashboard> createState() => _DashboardState();
}
class _DashboardState extends State<Dashboard> {
  late final MarketApi api;
  final search = TextEditingController();
  final service = TextEditingController();
  final scroll = ScrollController();
  int page = 0, liquidity = 1, request = 0;
  String market = 'turkey', tf = '1D', order = 'desc';
  String? error, detailError, storageError;
  bool loading = false, analyzing = false, checking = false;
  String? connection;
  ScanResult? result;
  Detail? selected;
  SharedPreferences? preferences;
  Set<String> favorites = {};
  final detailAnchor = GlobalKey();
  @override void initState() { super.initState(); api = widget.api ?? MarketApi(); initialize(); }
  Future<void> initialize() async {
    try {
      preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        favorites = (preferences!.getStringList('trademind.favorites') ?? []).toSet();
        api.base = preferences!.getString('trademind.api') ?? api.base;
        service.text = api.base;
      });
    } catch (_) { if (mounted) setState(() => storageError = 'Yerel kayıt kullanılamıyor; izleme listesi bu oturum boyunca tutulacak.'); }
    if (mounted && widget.autoLoad && (kIsWeb || api.base.isNotEmpty)) await scan();
  }
  @override void dispose() { request++; if (widget.api == null) api.dispose(); search.dispose(); service.dispose(); scroll.dispose(); super.dispose(); }
  Future<void> scan() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    final scanResult = await api.scan(market, tf, order, liquidity);
    if (!mounted) return;
    setState(() { result = scanResult; loading = false; error = scanResult.errors.isEmpty ? null : scanResult.errors.join('\n'); });
  }
  Future<void> analyze(String input) async {
    if (input.trim().isEmpty) return;
    final id = ++request;
    setState(() { analyzing = true; detailError = null; selected = null; if (page == 3) page = 0; });
    try {
      final value = await api.detail(input, tf);
      if (!mounted || id != request) return;
      setState(() { selected = value; analyzing = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = detailAnchor.currentContext;
        if (target != null) Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 350), alignment: .05);
      });
    } catch (e) { if (mounted && id == request) setState(() { analyzing = false; detailError = cleanError(e); }); }
  }
  Future<void> favorite(String ticker) async {
    setState(() { if (!favorites.add(ticker)) favorites.remove(ticker); });
    try { await preferences?.setStringList('trademind.favorites', favorites.toList()..sort()); }
    catch (_) { if (mounted) setState(() => storageError = 'İzleme listesi diske kaydedilemedi.'); }
  }
  void changeFilter(VoidCallback update) {
    request++;
    setState(() { update(); result = null; selected = null; analyzing = false; error = null; detailError = null; });
  }
  String stamp(DateTime? at) => at == null ? 'Henüz taranmadı' : '${at.toLocal().hour.toString().padLeft(2, '0')}:${at.toLocal().minute.toString().padLeft(2, '0')}:${at.toLocal().second.toString().padLeft(2, '0')}';
  @override Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    return Scaffold(
      drawer: wide ? null : Drawer(backgroundColor: ink, child: navigation(true)),
      body: SafeArea(child: Row(children: [
        if (wide) SizedBox(width: 238, child: navigation(false)),
        Expanded(child: Column(children: [topbar(wide), Expanded(child: Container(
          decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment.topRight, radius: 1.3, colors: [Color(0xff0c1c34), ink])),
          child: SingleChildScrollView(controller: scroll, padding: EdgeInsets.all(wide ? 30 : 16), child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (storageError != null) notice(storageError!),
              if (page == 3) settings() else ...[
                heading(), const SizedBox(height: 24),
                if (page == 0) ...[metrics(), const SizedBox(height: 22)],
                if (page == 2) watchlist() else ...[filters(), const SizedBox(height: 14), quickLinks(),
                  const SizedBox(height: 16), if (error != null) notice(error!, retry: scan), marketTable()],
                if (analyzing) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
                if (detailError != null) notice(detailError!),
                if (selected != null) Padding(key: detailAnchor, padding: const EdgeInsets.only(top: 24), child: detailPanel(selected!)),
              ],
              const SizedBox(height: 26), Text('footer_disclaimer'.tr(), style: TextStyle(color: muted, fontSize: 12, height: 1.7)),
            ]),
          ))),
        ))])),
      ])),
    );
  }
  Widget navigation(bool drawer) => Material(
    color: const Color(0xff060b1a),
    shape: const Border(right: BorderSide(color: edge)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 30), child: Row(children: [
        Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: cyan.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.auto_graph_rounded, color: cyan, size: 26)),
        const SizedBox(width: 12), const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TradeMind', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), Text('MARKET INTELLIGENCE', style: TextStyle(fontSize: 8, letterSpacing: 1.8, color: muted))]))),
      ])),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 26), child: Text('ÇALIŞMA ALANI', style: TextStyle(fontSize: 10, letterSpacing: 2, color: muted))),
      const SizedBox(height: 14),
      ...List.generate(4, (i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: ListTile(
        selected: page == i, selectedColor: cyan, selectedTileColor: cyan.withValues(alpha: .10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon([Icons.space_dashboard_outlined, Icons.query_stats, Icons.star_outline_rounded, Icons.tune_rounded][i], size: 21),
        title: Text(['Genel bakış', 'Piyasa tarayıcı', 'İzleme listesi', 'Ayarlar'][i], style: const TextStyle(fontSize: 14)),
        onTap: () { setState(() => page = i); if (drawer) Navigator.pop(context); scroll.jumpTo(0); },
      ))),
      const Spacer(),
      Padding(padding: const EdgeInsets.all(18), child: panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.insights_rounded, color: cyan), const SizedBox(height: 12), const Text('Veriye dayalı bakış', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8), const Text('BIST, ABD ve kripto piyasalarını tek çalışma alanında incele.', style: TextStyle(color: muted, fontSize: 12, height: 1.6)),
        const SizedBox(height: 14), Text(result == null ? '● Veri bekleniyor' : error != null ? '● Bağlantı uyarısı' : '● Son tarama alındı', style: TextStyle(color: result == null || error != null ? muted : green, fontSize: 11)),
      ]))),
      const Padding(padding: EdgeInsets.fromLTRB(26, 0, 26, 20), child: Text('TradeMind / Flutter 2.0', style: TextStyle(color: muted, fontSize: 10))),
    ]),
  );
  Widget topbar(bool wide) => Container(padding: EdgeInsets.symmetric(horizontal: wide ? 30 : 12, vertical: 13), decoration: const BoxDecoration(color: Color(0xff090f20), border: Border(bottom: BorderSide(color: edge))),
    child: Row(children: [
      if (!wide) Builder(builder: (ctx) => IconButton(tooltip: 'Menü', onPressed: () => Scaffold.of(ctx).openDrawer(), icon: const Icon(Icons.menu))),
      if (wide) ...[const Text('Piyasaları keşfet', style: TextStyle(color: muted, fontSize: 13)), const SizedBox(width: 28)],
      Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: TextField(controller: search,
        decoration: const InputDecoration(hintText: 'Sembol ara · THYAO, AAPL, BTC-USD', prefixIcon: Icon(Icons.search, size: 20)),
        textInputAction: TextInputAction.search, onSubmitted: analyze))),
      const SizedBox(width: 10), IconButton.filledTonal(tooltip: 'Sembolü analiz et', onPressed: analyzing ? null : () => analyze(search.text), icon: const Icon(Icons.arrow_forward)),
    ]));
  Widget heading() => Wrap(spacing: 24, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('TRADEMIND / PİYASA ANALİZİ', style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2.2, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10), Text(['Piyasaya daha geniş bak.', 'Fırsatları verilerle süz.', 'Takibindeki semboller.'][page], style: TextStyle(fontSize: MediaQuery.sizeOf(context).width < 600 ? 27 : 36, fontWeight: FontWeight.w800, letterSpacing: -1)),
      const SizedBox(height: 10), const Text('Teknik göstergeler, piyasa taraması ve odaklı analiz.', style: TextStyle(color: muted, fontSize: 13)),
    ]),
    badge('SON TARAMA  ${stamp(result?.fetchedAt)}', muted),
  ]);
  Widget metrics() {
    final rows = result?.rows ?? [];
    final buy = rows.where((r) => (r.score ?? 0) >= .1).length;
    final sell = rows.where((r) => (r.score ?? 0) <= -.1).length;
    final items = [('Taranan sembol', result == null ? '—' : '${result!.scanned}', Icons.radar, cyan), ('Filtreyi geçen', result == null ? '—' : '${rows.length}', Icons.filter_alt_outlined, const Color(0xffaa9aff)), ('AL eğilimi', result == null ? '—' : '$buy', Icons.trending_up, green), ('SAT eğilimi', result == null ? '—' : '$sell', Icons.trending_down, red)];
    return LayoutBuilder(builder: (context, c) { final count = c.maxWidth > 760 ? 4 : 2; final w = (c.maxWidth - (count - 1) * 12) / count;
      return Wrap(spacing: 12, runSpacing: 12, children: items.map((i) => SizedBox(width: w, child: panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text(i.$1, style: const TextStyle(color: muted, fontSize: 12))), Icon(i.$3, color: i.$4, size: 19)]),
        const SizedBox(height: 20), Text(i.$2, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6), Text(result == null ? 'Tarama bekleniyor' : '${markets[market]} · ${intervals[tf]}', style: const TextStyle(color: muted, fontSize: 10)),
      ])))).toList());
    });
  }
  Widget filters() => panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Piyasa tarayıcı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 16),
    Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
      dropdown('Piyasa', market, markets, (v) => changeFilter(() => market = v)),
      dropdown('Zaman aralığı', tf, intervals, (v) => changeFilter(() => tf = v)),
      dropdown('Sıralama', order, const {'desc':'En yüksek skor', 'asc':'En düşük skor'}, (v) => changeFilter(() => order = v)),
      dropdown('Likidite', '$liquidity', const {'0':'Filtre kapalı', '1':'Orta', '2':'Yüksek'}, (v) => changeFilter(() => liquidity = int.parse(v))),
      SizedBox(height: 46, child: FilledButton.icon(onPressed: loading ? null : scan, icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.radar, size: 18), label: Text(loading ? 'Taranıyor' : 'Piyasayı tara'))),
    ]),
    const SizedBox(height: 12), const Text('Likidite filtresi: günlük hacim × fiyat. Eşikler piyasanın kotasyon para birimindedir.', style: TextStyle(color: muted, fontSize: 10)),
  ]));
  Widget dropdown(String label, String value, Map<String, String> values, ValueChanged<String> change) => SizedBox(width: 166, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: muted, fontSize: 11)), const SizedBox(height: 7),
    DropdownButtonFormField<String>(initialValue: value, isExpanded: true, style: const TextStyle(fontSize: 12),
      items: values.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: loading ? null : (v) { if (v != null) change(v); }),
  ]));
  Widget quickLinks() => Wrap(spacing: 8, runSpacing: 8, children: quick.map((s) => ActionChip(label: Text(s.split(':').last, style: const TextStyle(fontSize: 11)), onPressed: () => analyze(s))).toList());
  Widget marketTable() {
    final rows = (result?.rows ?? []).take(50).toList();
    return panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 16, runSpacing: 6, children: [const Text('Teknik görünüm', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text('İlk ${rows.length} sembol · Skor −100…+100', style: const TextStyle(color: muted, fontSize: 11))]),
      const SizedBox(height: 16),
      if (loading) const LinearProgressIndicator(minHeight: 2),
      if (rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 44), child: Center(child: Column(children: [
        Icon(loading ? Icons.radar : Icons.candlestick_chart_outlined, color: cyan, size: 38), const SizedBox(height: 14),
        Text(loading ? 'Piyasa verileri alınıyor…' : result == null ? 'Analiz için piyasayı tara.' : error != null ? 'Tarama tamamlanamadı.' : 'Bu filtrelerle sonuç bulunamadı.', style: const TextStyle(color: muted)),
      ]))) else LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 700) return Column(children: rows.map((r) => Container(
          padding: const EdgeInsets.symmetric(vertical: 12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: edge))),
          child: Row(children: [star(r.ticker), Expanded(child: InkWell(onTap: () => analyze(r.ticker), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)), Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 10)),
            const SizedBox(height: 6), Text('${recommendation(r.score)} · ${number(r.score! * 100, 0)}', style: TextStyle(color: scoreColor(r.score), fontSize: 10)),
          ]))), const SizedBox(width: 10), InkWell(onTap: () => analyze(r.ticker), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(price(r.close)), Text('${number(r.day)}%', style: TextStyle(color: scoreColor(r.day), fontSize: 11))])),
          ]),
        )).toList());
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(horizontalMargin: 0, columnSpacing: 22, headingRowHeight: 40, dataRowMinHeight: 60, dataRowMaxHeight: 64,
          columns: ['','Sembol / şirket','Fiyat','Gün %','Hafta %','Teknik sınıf','Skor','RSI','ADX'].map((t) => DataColumn(label: Text(t, style: const TextStyle(color: muted, fontSize: 11)))).toList(),
          rows: rows.map((r) => DataRow(cells: [DataCell(star(r.ticker)),
            DataCell(SizedBox(width: 190, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 10))])), onTap: () => analyze(r.ticker)),
            DataCell(Text(price(r.close), style: const TextStyle(fontSize: 12)), onTap: () => analyze(r.ticker)),
            DataCell(Text(number(r.day), style: TextStyle(color: scoreColor(r.day), fontSize: 12))),
            DataCell(Text(number(r.week), style: TextStyle(color: scoreColor(r.week), fontSize: 12))),
            DataCell(badge(recommendation(r.score), scoreColor(r.score))), DataCell(Text(number(r.score! * 100, 0))), DataCell(Text(number(r.rsi, 0))), DataCell(Text(number(r.adx, 0))),
          ])).toList(),
        ));
      }),
      const SizedBox(height: 12), const Text('Detay için sembole dokun. Fiyatlar ilgili piyasanın kotasyon para birimindedir.', style: TextStyle(color: muted, fontSize: 10)),
    ]));
  }
  Widget star(String ticker) => IconButton(tooltip: favorites.contains(ticker) ? 'İzleme listesinden çıkar' : 'İzleme listesine ekle', onPressed: () => favorite(ticker), icon: Icon(favorites.contains(ticker) ? Icons.star_rounded : Icons.star_border_rounded, color: favorites.contains(ticker) ? cyan : muted, size: 19));
  Widget watchlist() => panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('İzleme listem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 10),
    const Text('Yıldızla eklediğin semboller bu cihazda saklanır. Sembole dokunarak güncel analizi al.', style: TextStyle(color: muted, height: 1.6)),
    const SizedBox(height: 20), if (favorites.isEmpty) const Text('Henüz sembol eklenmedi.', style: TextStyle(color: muted)),
    ...(favorites.toList()..sort()).map((s) => ListTile(contentPadding: EdgeInsets.zero, leading: star(s), title: Text(s), subtitle: Text(markets[marketFor(s)]!), trailing: const Icon(Icons.arrow_outward, color: cyan), onTap: () => analyze(s))),
  ]));
  Widget detailPanel(Detail d) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    ScorePanel(key: ValueKey('${d.ticker}-${d.interval}'), api: api, detail: d),
    const SizedBox(height: 16),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        star(d.ticker), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.ticker, style: const TextStyle(color: cyan, fontSize: 13)), const SizedBox(height: 8), Text(d.description, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
        badge(recommendation(d.score), scoreColor(d.score)),
      ]), const SizedBox(height: 20),
      Wrap(spacing: 36, runSpacing: 20, children: [valueBlock('Fiyat · ${intervals[d.interval]}', price(d.close)), valueBlock('Günlük değişim', '${number(d.value('change'))}%'), valueBlock('Teknik skor', d.score == null ? '—' : number(d.score! * 100, 0)), valueBlock('RSI (14)', number(d.value('RSI')))]),
      const SizedBox(height: 18), Text('Veri alım saati ${stamp(d.fetchedAt)} · Fiyatın işlem zamanı değildir.', style: const TextStyle(color: muted, fontSize: 10)),
      if (d.limited) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Sağlayıcı yalnızca sınırlı indikatör setini döndürdü.', style: TextStyle(color: Colors.amber, fontSize: 12))),
    ])),
    const SizedBox(height: 16), panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Fiyat grafiği', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      const Text('TradingView dış içeriği · ayrı veri akışı; yüklenmesi ağ erişimine bağlıdır.', style: TextStyle(color: muted, fontSize: 10)), const SizedBox(height: 16),
      ClipRRect(borderRadius: BorderRadius.circular(12), child: MarketChart(symbol: d.ticker, interval: d.interval)),
    ])),
    const SizedBox(height: 16),
    PatternAnalysis(chartData: d.values),
    const SizedBox(height: 16), panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Teknik özet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(height: 16), Text(d.summary, style: const TextStyle(color: muted, height: 1.8, fontSize: 13)),
      const SizedBox(height: 22), Wrap(spacing: 30, runSpacing: 18, children: [valueBlock('ATR (14)', price(d.atr)), valueBlock('Fiyat − 2 × ATR', price(d.stop)), valueBlock('Fiyat + 3 × ATR', price(d.target))]),
      const SizedBox(height: 22), const Divider(),
      ...['Recommend.MA','Recommend.Other','RSI','ADX','MACD.macd','MACD.signal','EMA10','EMA20','EMA50','EMA200','SMA20','SMA50','SMA200','CCI20','Stoch.K','Stoch.D','W.R','AO','Mom','UO'].map((key) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text({'Recommend.MA':'Hareketli ortalama skoru','Recommend.Other':'Osilatör skoru'}[key] ?? key, style: const TextStyle(color: muted, fontSize: 12))), Text(number(d.value(key), 3), style: const TextStyle(fontSize: 12))]))),
    ])),
  ]);
  Widget settings() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Bağlantı ayarları', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 14),
      Text(kIsWeb ? 'Web sürümünde boş bırakırsan bu sitenin veri servisi kullanılır.' : 'Mobil uygulama için yayımlanmış TradeMind HTTPS adresini gir.', style: const TextStyle(color: muted, height: 1.6)),
      const SizedBox(height: 20), TextField(controller: service, decoration: const InputDecoration(labelText: 'Servis adresi', hintText: 'https://projen.vercel.app'), keyboardType: TextInputType.url),
      const SizedBox(height: 16), FilledButton.icon(onPressed: checking ? null : () async {
        setState(() { checking = true; connection = null; });
        final previous = api.base;
        try {
          api.base = service.text.trim();
          await api.get('/api/health', {});
          await preferences?.setString('trademind.api', api.base);
          if (mounted) setState(() { connection = 'Servis bağlantısı doğrulandı. Piyasa erişimini tarama yaparak kontrol edebilirsin.'; result = null; selected = null; });
        } catch (e) { api.base = previous; if (mounted) setState(() => connection = cleanError(e)); }
        finally { if (mounted) setState(() => checking = false); }
      }, icon: const Icon(Icons.link), label: Text(checking ? 'Kontrol ediliyor…' : 'Doğrula ve kaydet')),
      if (connection != null) Padding(padding: const EdgeInsets.only(top: 18), child: Text(connection!, style: const TextStyle(color: muted))),
    ])),
    const SizedBox(height: 20),
    const SettingsPanel(),
  ]);
}
Color scoreColor(num? score) => score == null || score == 0 ? muted : score > 0 ? green : red;
Widget panel(Widget child) => SizedBox(width: double.infinity, child: Material(color: surface.withValues(alpha: .94), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: edge)), child: Padding(padding: const EdgeInsets.all(20), child: child)));
Widget badge(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withValues(alpha: .20))), child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)));
Widget valueBlock(String title, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: muted, fontSize: 11)), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600))]);
Widget notice(String text, {VoidCallback? retry}) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: .08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha: .25))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text, style: const TextStyle(color: Color(0xffffd38c), fontSize: 12, height: 1.6)), if (retry != null) TextButton(onPressed: retry, child: const Text('Yeniden dene'))])));
