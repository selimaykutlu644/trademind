import 'dart:convert';
String chartUrl(String symbol, String tf) {
  final interval = {'1D':'D','1W':'W','1M':'M','4H':'240','1H':'60'}[tf] ?? 'D';
  return 'https://www.tradingview.com/widgetembed/?${Uri(queryParameters: {'symbol':symbol, 'interval':interval, 'theme':'dark', 'style':'1', 'locale':'tr', 'toolbar_bg':'#0b1124', 'hide_side_toolbar':'0', 'allow_symbol_change':'0', 'save_image':'0', 'studies':jsonEncode([])}).query}';
}
