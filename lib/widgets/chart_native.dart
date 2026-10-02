import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'chart_url.dart';
class MarketChart extends StatefulWidget {
  final String symbol, interval;
  const MarketChart({super.key, required this.symbol, required this.interval});
  @override State<MarketChart> createState() => _MarketChartState();
}
class _MarketChartState extends State<MarketChart> {
  WebViewController? controller;
  bool get supported => [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS].contains(defaultTargetPlatform);
  @override void initState() {
    super.initState();
    if (supported) controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadRequest(Uri.parse(chartUrl(widget.symbol, widget.interval)));
  }
  @override void didUpdateWidget(covariant MarketChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol || oldWidget.interval != widget.interval) controller?.loadRequest(Uri.parse(chartUrl(widget.symbol, widget.interval)));
  }
  @override Widget build(BuildContext context) => controller != null
      ? SizedBox(height: 420, child: WebViewWidget(controller: controller!))
      : SizedBox(height: 180, child: Center(child: OutlinedButton.icon(
          onPressed: () async { await launchUrl(Uri.parse('https://www.tradingview.com/chart/?symbol=${Uri.encodeComponent(widget.symbol)}')); },
          icon: const Icon(Icons.open_in_new), label: const Text('TradingView grafiğini aç'))));
}
