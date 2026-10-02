import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trademind_mobile/main.dart';
import 'package:trademind_mobile/data/market.dart';
import 'package:trademind_mobile/widgets/score_panel.dart';
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'trademind.favorites':['BIST:THYAO']}));
  test('symbol mapping and negative/positive classifications', () {
    expect(candidates('THYAO.IS'), ['BIST:THYAO']);
    expect(candidates('BTC-USD'), ['BINANCE:BTCUSDT']);
    expect(recommendation(-.8), 'GÜÇLÜ SAT');
    expect(recommendation(null), 'Veri yok');
  });
  test('scan filters stablecoins and preserves missing values', () async {
    final api = MarketApi(base:'https://example.test',client:MockClient((req) async => http.Response(jsonEncode({'fetchedAt':'2026-09-29T00:00:00Z','data':[
      {'s':'BINANCE:RLUSDUSDT','d':['RLUSDUSDT','Stable',1,0,0,.9,.9,.9,50,20,10000000]},
      {'s':'BINANCE:BTCUSDT','d':['BTCUSDT','Bitcoin',100000,1,2,.5,.6,.4,null,25,10000]},
    ]}),200)));
    final result=await api.scan('crypto','1D','desc',0);
    expect(result.rows.length,1);expect(result.rows.single.ticker,'BINANCE:BTCUSDT');expect(result.rows.single.rsi,isNull);
    api.dispose();
  });
  test('HTML response is rejected instead of showing fake data',() async {
    final api=MarketApi(base:'https://example.test',client:MockClient((req)async=>http.Response('<html>wrong deployment</html>',200)));
    expect(()=>api.get('/api/scan',{}),throwsException);api.dispose();
  });
  for(final size in [const Size(390,844),const Size(1440,1000)]) {
    testWidgets('responsive dashboard at ${size.width}',(tester)async{
      tester.view.physicalSize=size;tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:const Dashboard(autoLoad:false)));
      await tester.pumpAndSettle();
      expect(find.text('Piyasaya daha geniş bak.'),findsOneWidget);
      expect(tester.takeException(),isNull);
      if (size.width < 1100) {
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
        expect(tester.takeException(),isNull);
      }
      await tester.tap(find.text('İzleme listesi'));
      await tester.pumpAndSettle();
      expect(find.text('İzleme listem'),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('score expansion uses its own Material surface', (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = MarketApi(base: 'https://example.test', client: MockClient((_) async => http.Response('{}', 200)));
    final detail = Detail('BIST:THYAO', '1D', {
      'columns': ['name','description','close'],
      'tv': {'data': [{'d': ['THYAO','Test fixture',10]}]},
      'fetchedAt': '2026-09-29T00:00:00Z',
    });
    await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: Scaffold(
      body: Container(color: Colors.black, child: SingleChildScrollView(
        child: ScorePanel(api: api, detail: detail),
      )),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
    await tester.tap(find.textContaining('Ağırlıkları ayarla'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(5));
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    api.dispose();
  });

}
