import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/market.dart';

const _cyan = Color(0xff56dcf2), _muted = Color(0xff97a7c3), _edge = Color(0xff202b43);
const _names = {'technical':'Teknik göstergeler', 'chart':'Grafik yapısı', 'valuation':'Değerleme', 'financial':'Üç aylık finansallar', 'risk':'Risk / dayanıklılık'};
class ScorePanel extends StatefulWidget {
  final MarketApi api;
  final Detail detail;
  const ScorePanel({super.key, required this.api, required this.detail});
  @override State<ScorePanel> createState() => _ScorePanelState();
}
class _ScorePanelState extends State<ScorePanel> {
  Map<String, dynamic> data = {};
  Map<String, dynamic>? report;
  Map<String, double> weights = {'technical':30,'chart':20,'valuation':20,'financial':20,'risk':10};
  bool busy = false;
  String? message;
  @override void initState() {super.initState();load();}
  Future<void> load() async {
    try {
      final prefs=await SharedPreferences.getInstance();
      final raw=prefs.getString('trademind.dataset.${widget.detail.ticker}');
      if(raw!=null && mounted) setState(()=>data=jsonDecode(raw) as Map<String,dynamic>);
    } catch (_) {if(mounted)setState(()=>message='Kaydedilmiş veri seti okunamadı.');}
  }
  Future<void> save() async {
    try {final prefs=await SharedPreferences.getInstance();await prefs.setString('trademind.dataset.${widget.detail.ticker}',jsonEncode(data));}
    catch(_){if(mounted)setState(()=>message='Veri bu cihazda kalıcı saklanamadı.');}
  }
  Future<void> calculate() async {
    setState((){busy=true;message=null;report=null;});
    try {
      final dataset=Map<String,dynamic>.from(data)..['ticker']=widget.detail.ticker;
      if(dataset['financialsEnabled']!=true)dataset.remove('financials');
      final response=await widget.api.client.post(widget.api.uri('/api/score', {}),headers:{'Content-Type':'application/json'},body:jsonEncode({
        'ticker':widget.detail.ticker,'market':marketFor(widget.detail.ticker),'tf':widget.detail.interval,'weights':weights,'dataset':dataset,
      })).timeout(const Duration(seconds:45));
      final decoded=jsonDecode(utf8.decode(response.bodyBytes));
      if(response.statusCode!=200 || decoded['error']!=null)throw Exception(decoded['error']??'Skor servisi yanıt vermedi.');
      if(mounted)setState(()=>report=Map<String,dynamic>.from(decoded));
    }catch(e){if(mounted)setState(()=>message=cleanError(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> fetchData() async {
    setState((){busy=true;message=null;});
    try {
      final result=await widget.api.get('/api/dataset',{'ticker':widget.detail.ticker});
      if(mounted)setState((){data=result;report=null;message='Kaynak verileri alındı. Finansal alanları ve yayın tarihini raporla karşılaştırıp veri formundan etkinleştir.';});
      await save();
    }catch(e){if(mounted)setState(()=>message=cleanError(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> fetchKapData() async {
    setState((){busy=true;message=null;});
    try {
      final result=await widget.api.get('/api/kap',{'ticker':widget.detail.ticker});
      if(mounted){
        setState((){
          if(result['financials']!=null){
            data['financials']=result['financials'];
            data['financialsEnabled']=true;
            data['priceSource']=result['provenance']?['source']??'KAP';
            report=null;
            message='KAP verisi başarıyla alındı. Verileri kontrol edip skoru hesaplayabilirsiniz.';
          }else{
            message='KAP verisi alınamadı. Veri formatını kontrol edin.';
          }
        });
        await save();
      }
    }catch(e){if(mounted)setState(()=>message='KAP hatası: ${cleanError(e)}');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context) {
    final sum=weights.values.fold(0.0,(a,b)=>a+b);
    final r=report;
    return SizedBox(width:double.infinity,child:Material(color:const Color(0xff0c1327),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:const BorderSide(color:_edge)),child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Çok boyutlu TradeMind skoru',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),const SizedBox(height:10),
      const Text('Ağırlıklar skora katkıyı gösterir; kazanç olasılığı değildir. Eksik veride tam skor yerine kapsamı belirtilmiş geçici skor hesaplanır.',style:TextStyle(color:_muted,fontSize:12,height:1.6)),
      const SizedBox(height:18),
      ExpansionTile(tilePadding:EdgeInsets.zero,title:Text('Ağırlıkları ayarla · toplam %${sum.toStringAsFixed(0)}'),children:[
        ...weights.keys.map((key)=>Column(children:[Row(children:[Expanded(child:Text(_names[key]!,style:const TextStyle(color:_muted,fontSize:12))),Text('%${weights[key]!.round()}')]),Slider(value:weights[key]!,min:0,max:100,divisions:20,onChanged:busy?null:(v)=>setState((){weights[key]=v;report=null;}))])),
        if(marketFor(widget.detail.ticker)=='crypto')TextButton(onPressed:()=>setState((){weights={'technical':50,'chart':50,'valuation':0,'financial':0,'risk':0};report=null;}),child:const Text('Kripto: teknik %50 / grafik %50')),
      ]),
      const SizedBox(height:10),Wrap(spacing:10,runSpacing:10,children:[
        FilledButton.icon(onPressed:busy || (sum-100).abs()>.01?null:calculate,icon:const Icon(Icons.calculate_outlined),label:Text(busy?'İşleniyor…':'Skoru hesapla')),
        OutlinedButton.icon(onPressed:busy?null:()async{
          final edited=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>_DataEditor(ticker:widget.detail.ticker,initial:data));
          if(edited!=null && mounted){setState((){data=edited;report=null;});await save();}
        },icon:const Icon(Icons.edit_note),label:const Text('Bilanço ve fiyat verileri')),
        OutlinedButton.icon(onPressed:busy?null:fetchData,icon:const Icon(Icons.cloud_download_outlined),label:const Text('Bağlı kaynaktan al')),
        if(marketFor(widget.detail.ticker)=='turkey')OutlinedButton.icon(onPressed:busy?null:fetchKapData,icon:const Icon(Icons.account_balance),label:const Text('KAP\'tan çek')),
      ]),
      if((sum-100).abs()>.01)const Padding(padding:EdgeInsets.only(top:12),child:Text('Ağırlıkların toplamı %100 olmalı.',style:TextStyle(color:Colors.amber))),
      if(message!=null)Padding(padding:const EdgeInsets.only(top:14),child:Text(message!,style:const TextStyle(color:Colors.amber,fontSize:12,height:1.6))),
      if(busy)const Padding(padding:EdgeInsets.symmetric(vertical:20),child:LinearProgressIndicator()),
      if(r!=null)...[
        const SizedBox(height:22),Wrap(spacing:36,runSpacing:20,children:[
          _stat(r['complete']==true?'Toplam skor':'Geçici skor',r['provisionalScore']==null?'—':'${r['provisionalScore']} / 100'),
          _stat('Veri kapsamı','%${r['coverage']}'),
          _stat('Bilanço dönemi','${r['provenance']['periodEnd']??'Veri yok'}'),
        ]),const SizedBox(height:20),
        ...(r['groups'] as List).map((g)=>ExpansionTile(tilePadding:EdgeInsets.zero,title:Text('${g['title']} · ${g['score']??'—'}/100',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600)),
          subtitle:Text('Ağırlık %${g['weight']} · veri kapsamı %${((g['coverage'] as num)*100).round()} · katkı ${g['contribution']} puan',style:const TextStyle(color:_muted,fontSize:10)),
          children:(g['metrics'] as List).map((m)=>ListTile(contentPadding:EdgeInsets.zero,title:Text('${m['label']}: ${m['value']??'—'}',style:const TextStyle(fontSize:12)),subtitle:Text('${m['formula']}',style:const TextStyle(color:_muted,fontSize:10)),trailing:Text('${m['score']??'—'}',style:const TextStyle(color:_cyan)))).toList())),
        const SizedBox(height:14),Wrap(spacing:22,runSpacing:12,children:[
          _stat('Defter değeri / pay','${r['derived']['bookValuePerShare']??'—'}'),
          _stat('Destek · 20 mum','${r['derived']['support20']??'—'}'),
          _stat('Direnç · 20 mum','${r['derived']['resistance20']??'—'}'),
        ]),
        const SizedBox(height:14),Wrap(spacing:22,runSpacing:12,children:[
          _stat('EV/EBITDA','${r['derived']['evEbitda']??'—'}'),
          _stat('EV/Sales','${r['derived']['evSales']??'—'}'),
          _stat('ROE %','${r['derived']['roe']??'—'}'),
          _stat('ROA %','${r['derived']['roa']??'—'}'),
        ]),
        const SizedBox(height:14),Wrap(spacing:22,runSpacing:12,children:[
          _stat('Brüt Kar Marjı %','${r['derived']['grossMargin']??'—'}'),
          _stat('İşletme Kar Marjı %','${r['derived']['operatingMargin']??'—'}'),
        ]),
        const SizedBox(height:18),...(r['warnings'] as List).map((w)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Text('• $w',style:const TextStyle(color:Colors.amber,fontSize:11,height:1.6)))),
        const SizedBox(height:12),Text('Fiyat kaynağı: ${r['provenance']['priceSource']??'Yok'}\nBilanço kaynağı: ${r['provenance']['financialSource']??'Yok'}\nGrafik analizi günlük OHLCV serisinden hesaplanır. Mum şekilleri veya ekran görüntüsü üzerinden yapay zekâ yorumu değildir.',style:const TextStyle(color:_muted,fontSize:10,height:1.6)),
      ],
    ]))));
  }
}
Widget _stat(String label,String value)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:_muted,fontSize:11)),const SizedBox(height:7),Text(value,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w600))]);
const _fields={
  'source':'Rapor kaynağı / KAP bildirim bağlantısı', 'periodEnd':'Çeyrek sonu · YYYY-MM-DD','previousYearPeriodEnd':'Önceki yıl aynı çeyrek sonu · YYYY-MM-DD', 'publishedAt':'Rapor yayın tarihi · YYYY-MM-DD',
  'revenue':'Üç aylık hasılat','previousYearRevenue':'Önceki yıl aynı çeyrek hasılat', 'netIncome':'Üç aylık adi paylara ait net kâr','previousYearNetIncome':'Önceki yıl aynı çeyrek net kâr', 'netIncomeTTM':'Son 4 çeyrek toplam adi paylara ait net kâr',
  'commonEquity':'Adi pay sahiplerine ait özkaynak','sharesOutstanding':'Dolaşımdaki toplam adi pay sayısı · adet', 'currentAssets':'Dönen varlıklar','currentLiabilities':'Kısa vadeli yükümlülükler', 'cash':'Nakit ve nakit benzerleri','interestBearingDebt':'Faiz taşıyan finansal borç', 'operatingCashFlow':'Üç aylık faaliyetlerden nakit akışı','sectorMedianPB':'Aynı sektör PD/DD medyanı','sectorMedianPE':'Aynı sektör pozitif F/K medyanı',
};
class _DataEditor extends StatefulWidget {
  final String ticker;final Map<String,dynamic> initial;
  const _DataEditor({required this.ticker,required this.initial});
  @override State<_DataEditor> createState()=>_DataEditorState();
}
class _DataEditorState extends State<_DataEditor> {
  final fields=<String,TextEditingController>{};
  late final TextEditingController csv,priceSource,priceCurrency;
  String unit='unit',currency='TRY',sector='non-financial',adjustment='split-adjusted';
  bool enabled=false,comparable=false;
  String? error;
  @override void initState(){
    super.initState();
    final f=widget.initial['financials'] is Map?Map<String,dynamic>.from(widget.initial['financials']):<String,dynamic>{};
    for(final key in _fields.keys){fields[key]=TextEditingController(text:f[key]?.toString()??'');}
    currency=f['currency'] as String? ?? (marketFor(widget.ticker)=='turkey'?'TRY':'USD');
    unit=f['unit'] as String? ?? 'unit';sector=f['sectorProfile']=='non-financial'?'non-financial':'financial';
    if(f.isEmpty)sector='non-financial';
    comparable=f['previousYearComparable']==true;enabled=widget.initial['financialsEnabled']==true;
    adjustment=widget.initial['priceAdjustment'] as String? ?? 'split-adjusted';
    priceSource=TextEditingController(text:widget.initial['priceSource'] as String? ?? '');
    priceCurrency=TextEditingController(text:widget.initial['priceCurrency'] as String? ?? currency);
    csv=TextEditingController(text:(widget.initial['bars'] as List? ?? []).map((b)=>['date','open','high','low','close','volume'].map((k)=>b[k]).join(',')).join('\n'));
  }
  @override void dispose(){for(final c in fields.values){c.dispose();}csv.dispose();priceSource.dispose();priceCurrency.dispose();super.dispose();}
  void submit(){
    try{
      final f=<String,dynamic>{'unit':unit,'currency':currency.toUpperCase(),'sectorProfile':sector,'periodType':'standalone-quarter','previousYearComparable':comparable};
      for(final key in fields.keys){final v=fields[key]!.text.trim(); if(['source','periodEnd','previousYearPeriodEnd','publishedAt'].contains(key)){f[key]=v;}else{f[key]=v.isEmpty?null:double.parse(v.replaceAll(',','.'));}}
      final bars=<Map<String,dynamic>>[];
      for(final line in csv.text.split('\n')){
        if(line.trim().isEmpty || line.trim().toLowerCase().startsWith('date,'))continue;
        final c=line.trim().split(',');if(c.length!=6)throw const FormatException('Her fiyat satırı 6 alan içermeli.');
        bars.add({'date':c[0].trim(),'open':double.parse(c[1]),'high':double.parse(c[2]),'low':double.parse(c[3]),'close':double.parse(c[4]),'volume':double.parse(c[5])});
      }
      bars.sort((a,b)=>(a['date'] as String).compareTo(b['date'] as String));
      if(enabled && (!comparable || ['source','periodEnd','previousYearPeriodEnd','publishedAt'].any((k)=>(f[k] as String).isEmpty)))throw const FormatException('Bilanço puanını açmak için kaynak, tarihler ve karşılaştırma onayı gerekli.');
      Navigator.pop(context,{'ticker':widget.ticker,'financials':f,'financialsEnabled':enabled,'bars':bars,'priceSource':priceSource.text.trim(),'priceCurrency':priceCurrency.text.trim().toUpperCase(),'priceInterval':'1D','priceAdjustment':adjustment,'verification':'user-supplied; not independently verified'});
    }catch(e){setState(()=>error='Veriler kaydedilemedi: ${cleanError(e)}');}
  }
  @override Widget build(BuildContext context)=>AlertDialog(title:Text('${widget.ticker} · Analiz verileri'),content:SizedBox(width:760,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Bilanço verilerini kaynak rapordan gir. Altı veya dokuz aylık kümülatif tutarı üç aylık tutar gibi kullanma. Hasılat, kâr ve nakit akışını bağımsız çeyreğe dönüştür; karşılaştırmayı aynı muhasebe/enflasyon bazında yap.',style:TextStyle(color:_muted,fontSize:12,height:1.6)),
    SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Bilanço verilerini skora kat'),value:enabled,onChanged:(v)=>setState(()=>enabled=v)),
    Wrap(spacing:12,runSpacing:12,children:[
      SizedBox(width:160,child:TextFormField(initialValue:currency,decoration:const InputDecoration(labelText:'Rapor para birimi'),onChanged:(v)=>currency=v)),
      SizedBox(width:160,child:DropdownButtonFormField<String>(initialValue:unit,decoration:const InputDecoration(labelText:'Tutar ölçeği'),items:const [DropdownMenuItem(value:'unit',child:Text('Birim')),DropdownMenuItem(value:'thousand',child:Text('Bin')),DropdownMenuItem(value:'million',child:Text('Milyon'))],onChanged:(v)=>setState(()=>unit=v!))),
      SizedBox(width:230,child:DropdownButtonFormField<String>(initialValue:sector,decoration:const InputDecoration(labelText:'Şirket türü'),items:const [DropdownMenuItem(value:'non-financial',child:Text('Finans dışı şirket')),DropdownMenuItem(value:'financial',child:Text('Banka / finans / belirsiz'))],onChanged:(v)=>setState(()=>sector=v!))),
    ]),const SizedBox(height:16),
    ...fields.entries.map((e)=>Padding(padding:const EdgeInsets.only(bottom:14),child:TextField(controller:e.value,decoration:InputDecoration(labelText:_fields[e.key],helperText:e.key=='sharesOutstanding'?'Tutar ölçeğinden bağımsız; pay adedi.':null)))),
    CheckboxListTile(contentPadding:EdgeInsets.zero,value:comparable,onChanged:(v)=>setState(()=>comparable=v!),title:const Text('Önceki yıl verileri aynı karşılaştırma bazında; dönemler ve birimler kontrol edildi.',style:TextStyle(fontSize:12))),
    const Divider(),const SizedBox(height:16),const Text('Günlük fiyat geçmişi',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:10),
    const Text('En az 50 günlük, bölünmelere göre düzeltilmiş OHLCV. Kolonlar: date,open,high,low,close,volume. Tarih YYYY-MM-DD; ondalık ayırıcı nokta. Destek/direnç ve hacim teyidi bu veriden hesaplanır.',style:TextStyle(color:_muted,fontSize:12,height:1.6)),
    const SizedBox(height:16),TextField(controller:priceSource,decoration:const InputDecoration(labelText:'Fiyat kaynağı / veri dosyası bilgisi')),const SizedBox(height:12),
    TextField(controller:priceCurrency,decoration:const InputDecoration(labelText:'Fiyat para birimi · TRY / USD')),const SizedBox(height:12),
    DropdownButtonFormField<String>(initialValue:adjustment,decoration:const InputDecoration(labelText:'Fiyat düzeltmesi'),items:const [DropdownMenuItem(value:'split-adjusted',child:Text('Bölünmelere göre düzeltilmiş')),DropdownMenuItem(value:'total-return-adjusted',child:Text('Bölünme ve temettüye göre'))],onChanged:(v)=>setState(()=>adjustment=v!)),
    const SizedBox(height:14),TextField(controller:csv,minLines:5,maxLines:10,decoration:const InputDecoration(labelText:'OHLCV satırlarını yapıştır',hintText:'date,open,high,low,close,volume')),
    if(error!=null)Padding(padding:const EdgeInsets.only(top:14),child:Text(error!,style:const TextStyle(color:Colors.amber))),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Vazgeç')),FilledButton(onPressed:submit,child:const Text('Verileri kaydet'))]);
}
