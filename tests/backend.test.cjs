const {test}=require('node:test');const assert=require('node:assert/strict');
const {scan,detail,handle,cache}=require('../server/core.cjs');
const {calculate}=require('../server/scoring.cjs');
const {dataset}=require('../server/provider.cjs');
const now=new Date('2026-09-29T00:00:00Z');
const query=s=>new URLSearchParams(s);
function bars(){return Array.from({length:90},(_,i)=>({date:new Date(Date.UTC(2026,6,1+i)).toISOString().slice(0,10),open:100+i,high:102+i,low:99+i,close:101+i,volume:1000000+i*1000}));}
function input(){return {ticker:'BIST:TEST',currentPrice:20,indicators:{'Recommend.All':.5,RSI:55,'MACD.macd':2,'MACD.signal':1},dataset:{ticker:'BIST:TEST',priceSource:'test fixture only',priceInterval:'1D',priceAdjustment:'split-adjusted',priceCurrency:'TRY',bars:bars(),financials:{periodEnd:'2026-06-30',previousYearPeriodEnd:'2025-06-30',publishedAt:'2026-08-01',periodType:'standalone-quarter',source:'test fixture',currency:'TRY',unit:'million',sectorProfile:'non-financial',previousYearComparable:true,revenue:100,previousYearRevenue:80,netIncome:20,previousYearNetIncome:10,netIncomeTTM:60,commonEquity:200,sharesOutstanding:100000000,currentAssets:120,currentLiabilities:60,cash:30,interestBearingDebt:50,operatingCashFlow:21,sectorMedianPB:10,sectorMedianPE:20}}};}
test('scan keeps the market-cap filter and expected indicator order',async()=>{
 let sent;const r=await scan(query('market=america&tf=1H'),async(url,opt)=>{sent=JSON.parse(opt.body);return{ok:true,json:async()=>({data:[]})};});
 assert(sent.filter.some(f=>f.left==='market_cap_basic'));assert.equal(sent.columns[5],'Recommend.All|60');assert.equal(sent.columns[2],'close');assert(r.fetchedAt);
});
test('bad market and interval rejected before upstream',async()=>{await assert.rejects(()=>scan(query('market=invalid')),/geçersiz/);await assert.rejects(()=>scan(query('tf=5H')),/geçersiz/);});
test('provider errors are reported, never replaced with demo quotes',async()=>{await assert.rejects(()=>scan(query('market=turkey'),async()=>({ok:false,status:429})),/429/);});
test('detail fallback has a visible limited flag',async()=>{let calls=0;const r=await detail(query('market=turkey&ticker=BIST:TEST&tf=1D'),async()=>++calls===1?{ok:false,status:400}:{ok:true,json:async()=>({data:[{s:'BIST:TEST',d:['TEST','Test',10,1,1000,50,.2,.3,.1]}]})});assert.equal(r.limited,true);assert.equal(calls,2);});
test('not found is not retried as a new indicator set',async()=>{let calls=0;await assert.rejects(()=>detail(query('ticker=BIST:TEST'),async()=>{calls++;return{ok:true,json:async()=>({data:[]})};}),/bulunamadı/);assert.equal(calls,1);});
test('all data produces traceable weighted total and million-unit book value',()=>{const r=calculate(input(),now);assert.equal(r.coverage,100);assert.equal(r.complete,true);assert.equal(r.derived.bookValuePerShare,2);assert.equal(r.derived.pb,10);assert(r.totalScore>=0&&r.totalScore<=100);assert.equal(r.totalScore,r.provisionalScore);assert.equal(r.groups.length,5);});
test('missing fundamentals are not zeros or a full score',()=>{const x=input();delete x.dataset.financials;const r=calculate(x,now);assert.equal(r.totalScore,null);assert(r.coverage<100);assert.equal(r.groups.find(g=>g.key==='valuation').score,null);assert(r.provisionalScore!=null);});
test('weights must total 100 and cannot contain NaN',()=>{const x=input();x.weights={technical:50,chart:50,valuation:20,financial:20,risk:10};assert.throws(()=>calculate(x,now),/%100/);x.weights.risk=NaN;assert.throws(()=>calculate(x,now),/0–100/);});
test('loss-making and negative equity do not create cheap positive ratios',()=>{const x=input();x.dataset.financials.commonEquity=-10;x.dataset.financials.netIncomeTTM=-20;const r=calculate(x,now);assert.equal(r.derived.pb,null);assert.equal(r.derived.pe,null);assert.equal(r.groups.find(g=>g.key==='valuation').metrics.find(m=>m.key==='pe').score,0);assert(r.warnings.some(w=>w.includes('negatif')));});
test('future filings and mismatched tickers rejected',()=>{const x=input();x.dataset.financials.publishedAt='2026-12-01';assert.throws(()=>calculate(x,now),/gelecekte/);x.dataset.ticker='BIST:OTHER';assert.throws(()=>calculate(x,now),/eşleşmiyor/);});
test('cumulative quarterly data and non-comparable prior year excluded',()=>{const x=input();x.dataset.financials.periodType='year-to-date';assert.throws(()=>calculate(x,now),/üç aylık/);x.dataset.financials.periodType='standalone-quarter';x.dataset.financials.previousYearComparable=false;const r=calculate(x,now);assert.equal(r.groups.find(g=>g.key==='financial').score,null);});
test('banks are excluded from the industrial balance-sheet model',()=>{const x=input();x.dataset.financials.sectorProfile='financial';const r=calculate(x,now);assert.equal(r.groups.find(g=>g.key==='financial').score,null);assert(r.warnings.some(w=>w.includes('Banka')));});
test('currency mismatch blocks valuation',()=>{const x=input();x.dataset.priceCurrency='USD';assert.equal(calculate(x,now).groups.find(g=>g.key==='valuation').score,null);});
test('unadjusted data and stale prices excluded from chart score',()=>{const x=input();x.dataset.priceAdjustment='raw';assert.equal(calculate(x,now).groups.find(g=>g.key==='chart').score,null);x.dataset.priceAdjustment='split-adjusted';assert.equal(calculate(x,new Date('2027-01-01')).groups.find(g=>g.key==='chart').score,null);});
test('invalid OHLC and duplicate dates rejected',()=>{const x=input();x.dataset.bars[0].low=9999;assert.throws(()=>calculate(x,now),/OHLCV/);x.dataset.bars=bars();x.dataset.bars[1].date=x.dataset.bars[0].date;assert.throws(()=>calculate(x,now),/benzersiz/);});
test('crypto uses technical and chart only when explicitly weighted',()=>{const x=input();x.ticker='BINANCE:BTCUSDT';x.dataset.ticker=x.ticker;x.weights={technical:50,chart:50,valuation:0,financial:0,risk:0};const r=calculate(x,now);assert.equal(r.complete,true);assert.equal(r.groups.find(g=>g.key==='financial').score,null);});
test('public upstream route cannot become an arbitrary URL proxy',async()=>{await assert.rejects(()=>dataset('https://example.invalid/'),/ABD hisseleri/);});
test('health does not claim verified upstream data',async()=>{const r=await handle('/api/health','GET',query(''));assert.equal(r.providerVerified,false);await assert.rejects(()=>handle('/api/unknown','GET',query('')),/bulunamadı/);});
test('scan cache reuses only successful data',async()=>{cache.clear();let calls=0;const fetcher=async()=>{calls++;return{ok:true,json:async()=>({data:[]})};};await handle('/api/scan','GET',query('market=turkey'),fetcher);const b=await handle('/api/scan','GET',query('market=turkey'),fetcher);assert.equal(calls,1);assert.equal(b.cached,true);});
const http=require('node:http');
const {handler:analysisHandler}=require('../server/analysis-handler.cjs');
async function postHandler(body) {
  const originalFetch=global.fetch;
  global.fetch=async(url,opt)=>{const columns=JSON.parse(opt.body).columns;return{ok:true,json:async()=>({data:[{s:'BIST:TEST',d:columns.map(c=>({name:'TEST',description:'Fixture',close:20,'Recommend.All':.5,RSI:55,'MACD.macd':2,'MACD.signal':1}[c]??null))}]})};};
  const server=http.createServer(analysisHandler('/api/score'));
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  try {return await new Promise((resolve,reject)=>{
    const req=http.request({hostname:'127.0.0.1',port:server.address().port,path:'/api/score',method:'POST',headers:{'Content-Type':'application/json'}},res=>{let data='';res.on('data',c=>data+=c);res.on('end',()=>resolve({status:res.statusCode,body:JSON.parse(data)}));});
    req.on('error',reject);req.end(typeof body==='string'?body:JSON.stringify(body));
  });} finally {await new Promise(resolve=>server.close(resolve));global.fetch=originalFetch;}
}
test('HTTP scoring fetches technical values server-side and ignores submitted indicators',async()=>{const r=await postHandler({ticker:'BIST:TEST',market:'turkey',tf:'1D',indicators:{'Recommend.All':-1}});assert.equal(r.status,200);assert.equal(r.body.groups[0].metrics[0].value,.5);assert.equal(r.body.totalScore,null);});
test('malformed HTTP score input returns JSON 400',async()=>{const r=await postHandler('{bad json');assert.equal(r.status,400);assert(r.body.error);});
