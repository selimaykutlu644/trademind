import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'chart_url.dart';
class MarketChart extends StatelessWidget {
  final String symbol, interval;
  const MarketChart({super.key, required this.symbol, required this.interval});
  @override Widget build(BuildContext context) => SizedBox(height: 420, child: HtmlElementView.fromTagName(
    key: ValueKey('$symbol-$interval'), tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      frame.src = chartUrl(symbol, interval);
      frame.title = '$symbol TradingView fiyat grafiği';
      frame.style.width = '100%'; frame.style.height = '100%'; frame.style.border = '0';
      frame.setAttribute('loading', 'lazy');
    },
  ));
}
