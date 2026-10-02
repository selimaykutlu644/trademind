import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const intervals = {'1D': 'Günlük', '4H': '4 saat', '1H': '1 saat', '1W': 'Haftalık', '1M': 'Aylık'};
const markets = {'turkey': 'BIST', 'america': 'ABD', 'crypto': 'Kripto', 'all': 'Tüm piyasalar'};
String number(num? value, [int digits = 2]) => value == null || !value.isFinite ? '—' : value.toStringAsFixed(digits);
String price(num? value) => number(value, value != null && value.abs() < 1 ? 5 : 2);
String recommendation(num? score) => score == null ? 'Veri yok' : score >= .5 ? 'GÜÇLÜ AL' : score >= .1 ? 'AL' : score <= -.5 ? 'GÜÇLÜ SAT' : score <= -.1 ? 'SAT' : 'NÖTR';
double? numeric(dynamic value) => value is num && value.isFinite ? value.toDouble() : null;
String marketFor(String ticker) => ticker.startsWith('BIST:') ? 'turkey' : RegExp(r'^(BINANCE|BYBIT|COINBASE|KRAKEN|OKX|BITSTAMP|KUCOIN|MEXC):').hasMatch(ticker) ? 'crypto' : 'america';
List<String> candidates(String input) {
  var s = input.trim().toUpperCase().replaceAll('İ', 'I').replaceAll('Ş', 'S').replaceAll('Ğ', 'G').replaceAll('Ü', 'U').replaceAll('Ö', 'O').replaceAll('Ç', 'C').replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return [];
  if (s.contains(':')) return [s];
  if (s.endsWith('.IS')) return ['BIST:${s.substring(0, s.length - 3)}'];
  if (s.endsWith('-USD')) return ['BINANCE:${s.substring(0, s.length - 4)}USDT'];
  if (s.endsWith('USDT')) return ['BINANCE:$s'];
  return ['BIST:$s', 'NASDAQ:$s', 'NYSE:$s', 'BINANCE:${s}USDT'];
}
class Quote {
  final String ticker, name, description, market;
  final double? close, day, week, score, ma, osc, rsi, adx, volume;
  Quote(Map<String, dynamic> row, this.market)
      : ticker = row['s'] as String,
        name = '${(row['d'] as List)[0]}', description = '${row['d'][1] ?? ''}',
        close = numeric(row['d'][2]), day = numeric(row['d'][3]), week = numeric(row['d'][4]), score = numeric(row['d'][5]),
        ma = numeric(row['d'][6]), osc = numeric(row['d'][7]), rsi = numeric(row['d'][8]), adx = numeric(row['d'][9]), volume = numeric(row['d'][10]);
}
class ScanResult {
  final List<Quote> rows;
  final int scanned;
  final List<String> errors;
  final DateTime? fetchedAt;
  ScanResult(this.rows, this.scanned, this.errors, this.fetchedAt);
}
class Detail {
  final String ticker, interval;
  final Map<String, dynamic> values;
  final DateTime? fetchedAt;
  final bool limited;
  Detail(this.ticker, this.interval, Map<String, dynamic> json)
      : values = Map.fromIterables((json['columns'] as List).map((e) => e.toString().split('|')[0]), json['tv']['data'][0]['d'] as List),
        fetchedAt = DateTime.tryParse('${json['fetchedAt']}'), limited = json['limited'] == true;
  double? value(String key) => numeric(values[key]);
  double? get close => value('close');
  double? get score => value('Recommend.All');
  double? get atr => value('ATR');
  String get description => '${values['description'] ?? ticker}';
  double? get stop => close != null && atr != null ? close! - 2 * atr! : null;
  double? get target => close != null && atr != null ? close! + 3 * atr! : null;
  String get summary {
    final rsi = value('RSI');
    final trend = score == null ? 'Bileşik teknik skor sağlanmadı.' : 'Bileşik teknik sınıflandırma ${recommendation(score)}; skor ${number(score! * 100, 0)} / −100…+100.';
    final momentum = rsi == null ? 'RSI verisi yok.' : rsi > 70 ? 'RSI ${number(rsi)}: aşırı alım bölgesi.' : rsi < 30 ? 'RSI ${number(rsi)}: aşırı satım bölgesi.' : 'RSI ${number(rsi)}: 30–70 bandında.';
    return '$trend\n\n$momentum Tek bir indikatör yön veya kazanç garantisi vermez. Zaman aralığı ${intervals[interval]}; günlük değişim ayrı bir ölçüdür.\n\nATR seviyeleri yalnızca uzun pozisyon için aritmetik referanstır. Bu metin kural tabanlıdır; üretken yapay zekâ çıktısı değildir.';
  }
}
class MarketApi {
  final http.Client client;
  String base;
  MarketApi({http.Client? client, String? base}) : client = client ?? http.Client(), base = base ?? const String.fromEnvironment('API_BASE_URL');
  Uri uri(String path, Map<String, String> params) {
    if (base.isEmpty && !kIsWeb) throw Exception('Ayarlar bölümünde HTTPS servis adresini girin.');
    final root = base.isEmpty ? Uri.base.origin : base.replaceAll(RegExp(r'/+$'), '');
    final url = Uri.parse(root);
    if (!['https', 'http'].contains(url.scheme) || url.host.isEmpty || url.userInfo.isNotEmpty || (url.path != '' && url.path != '/') || url.hasQuery || url.hasFragment) {
      throw Exception('Servis adresi https://alanadi biçiminde olmalı.');
    }
    return Uri.parse('$root$path').replace(queryParameters: params);
  }
  Future<Map<String, dynamic>> get(String path, Map<String, String> params) async {
    final response = await client.get(uri(path, params)).timeout(const Duration(seconds: 30));
    dynamic json;
    try { json = jsonDecode(utf8.decode(response.bodyBytes)); } catch (_) { throw Exception('API yerine HTML veya okunamayan yanıt geldi. Servis adresini kontrol edin.'); }
    if (json is! Map<String, dynamic>) throw Exception('Servis yanıtı geçersiz.');
    if (response.statusCode != 200 || json['error'] != null) throw ApiFailure(response.statusCode, '${json['error'] ?? 'Servis hatası'}');
    return json;
  }
  Future<ScanResult> scan(String market, String tf, String order, int liquidity) async {
    final rows = <Quote>[]; final errors = <String>[]; var count = 0; DateTime? fetched;
    final selected = market == 'all' ? ['turkey', 'crypto', 'america'] : [market];
    await Future.wait(selected.map((m) async {
      try {
        final json = await get('/api/scan', {'market': m, 'tf': tf, 'order': order});
        final data = json['data'] as List;
        count += data.length;
        final at = DateTime.tryParse('${json['fetchedAt']}');
        if (at != null && (fetched == null || at.isBefore(fetched!))) fetched = at;
        final threshold = (m == 'turkey' ? [0, 5e6, 5e7] : m == 'crypto' ? [0, 1e6, 2e7] : [0, 1e7, 1e8])[liquidity];
        for (final raw in data) {
          if (raw is! Map<String, dynamic> || raw['d'] is! List || (raw['d'] as List).length < 11 || raw['s'] is! String) continue;
          final row = Quote(raw, m);
          if (row.close == null || row.score == null || row.close! * (row.volume ?? 0) < threshold) continue;
          if (m == 'crypto' && (!row.ticker.startsWith('BINANCE:') || !row.name.endsWith('USDT') || RegExp(r'^(USDC|FDUSD|TUSD|BUSD|DAI|USDP|USD1|PYUSD|USDE|RLUSD|EUR|AEUR|TRY|GBP)USDT$').hasMatch(row.name))) continue;
          rows.add(row);
        }
      } catch (e) { errors.add('${markets[m]}: ${cleanError(e)}'); }
    }));
    rows.sort((a,b) { final c = a.score!.compareTo(b.score!) * (order == 'asc' ? 1 : -1); return c != 0 ? c : (b.adx ?? 0).compareTo(a.adx ?? 0); });
    return ScanResult(rows, count, errors, fetched);
  }
  Future<Detail> detail(String input, String tf) async {
    for (final ticker in candidates(input)) {
      try {
        final json = await get('/api/detail', {'market': marketFor(ticker), 'ticker': ticker, 'tf': tf});
        if ((json['tv']['data'] as List).isEmpty) continue;
        return Detail(ticker, tf, json);
      } on ApiFailure catch (e) { if (e.status != 404) rethrow; }
    }
    throw Exception('Sembol bulunamadı. BIST:THYAO veya NASDAQ:AAPL biçimini deneyin.');
  }
  void dispose() => client.close();
}
class ApiFailure implements Exception {
  final int status; final String message;
  ApiFailure(this.status, this.message);
  @override String toString() => message;
}
String cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');
