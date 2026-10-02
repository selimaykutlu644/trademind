'use strict';
// Optional, documented provider. Keys stay on the server.
async function dataset(ticker, fetcher = fetch) {
  const key=process.env.ALPHAVANTAGE_API_KEY;
  if (!/^(NASDAQ|NYSE|AMEX):[A-Z0-9.\-]{1,20}$/.test(ticker || '')) {
    const e=new Error('Otomatik bilanço/fiyat sağlayıcısı bu sürümde ABD hisseleriyle sınırlı. BIST için KAP verilerini ve düzeltilmiş günlük fiyatları veri formundan girin.'); e.status=422; throw e;
  }
  if (!key) { const e=new Error('Otomatik fiyat ve bilanço kaynağı bağlı değil. Sunucuda ALPHAVANTAGE_API_KEY tanımlayın veya veri formunu kullanın.'); e.status=503; throw e; }
  const symbol=ticker.split(':')[1];
  async function get(fn) {
    const url=new URL('https://www.alphavantage.co/query');
    url.search=new URLSearchParams({function:fn,symbol,apikey:key,outputsize:'compact'}).toString();
    let result;
    try { const r=await fetcher(url,{signal:AbortSignal.timeout(15000)}); if(!r.ok) throw new Error(); result=await r.json(); }
    catch { const e=new Error('Finansal veri sağlayıcısına ulaşılamadı.'); e.status=502; throw e; }
    if (result.Information || result.Note || result['Error Message']) { const e=new Error('Finansal veri sağlayıcısı istek kotası, abonelik veya sembol nedeniyle yanıt vermedi. Günlük düzeltilmiş fiyat servisi abonelik gerektirebilir.'); e.status=502; throw e; }
    return result;
  }
  const [prices,income,balance,cash]=await Promise.all(['TIME_SERIES_DAILY_ADJUSTED','INCOME_STATEMENT','BALANCE_SHEET','CASH_FLOW'].map(get));
  const series=prices['Time Series (Daily)'];
  const reports=income.quarterlyReports;
  if(!series || !Array.isArray(reports) || !reports.length) { const e=new Error('Sağlayıcı fiyat veya çeyrek verilerini döndürmedi.'); e.status=502; throw e; }
  const n=v=>v==null || v==='' || v==='None' || !Number.isFinite(Number(v)) ? null:Number(v);
  let splitFactor=1;
  const bars=Object.entries(series).sort((a,b)=>b[0].localeCompare(a[0])).map(([date,row])=>{
    const factor=Number(row['5. adjusted close'])/Number(row['4. close']);
    const result={date,open:Number(row['1. open'])*factor,high:Number(row['2. high'])*factor,low:Number(row['3. low'])*factor,close:Number(row['5. adjusted close']),volume:Number(row['6. volume'])*splitFactor};
    splitFactor*=Number(row['8. split coefficient'])||1;
    return result;
  }).reverse();
  const current=reports[0];
  const period=current.fiscalDateEnding;
  const prior=reports.find(r=>{const days=(new Date(period)-new Date(r.fiscalDateEnding))/86400000;return days>=350&&days<=380;})||{};
  const b=balance.quarterlyReports?.find(r=>r.fiscalDateEnding===period)||{};
  const cf=cash.quarterlyReports?.find(r=>r.fiscalDateEnding===period)||{};
  const recent=reports.slice(0,4);
  const ttmValid=recent.length===4 && recent.every((r,i)=>n(r.netIncome)!=null && (i===0 || ((new Date(recent[i-1].fiscalDateEnding)-new Date(r.fiscalDateEnding))/86400000>=70 && (new Date(recent[i-1].fiscalDateEnding)-new Date(r.fiscalDateEnding))/86400000<=110)));
  return {ticker,priceSource:'Alpha Vantage TIME_SERIES_DAILY_ADJUSTED',priceCurrency:current.reportedCurrency,priceInterval:'1D',priceAdjustment:'total-return-adjusted',bars,verification:'provider data; financial comparability and publication date require user review',
    financials:{source:'Alpha Vantage financial reports; compare with original company filing',periodEnd:period,previousYearPeriodEnd:prior.fiscalDateEnding||null,publishedAt:null,periodType:'standalone-quarter',currency:current.reportedCurrency,unit:'unit',sectorProfile:'unconfirmed',previousYearComparable:false,
      revenue:n(current.totalRevenue),previousYearRevenue:n(prior.totalRevenue),netIncome:n(current.netIncome),previousYearNetIncome:n(prior.netIncome),netIncomeTTM:ttmValid?recent.reduce((s,r)=>s+Number(r.netIncome),0):null,
      commonEquity:null,sharesOutstanding:n(b.commonStockSharesOutstanding),currentAssets:n(b.totalCurrentAssets),currentLiabilities:n(b.totalCurrentLiabilities),cash:n(b.cashAndCashEquivalentsAtCarryingValue),interestBearingDebt:n(b.shortLongTermDebtTotal),operatingCashFlow:n(cf.operatingCashflow),sectorMedianPE:null,sectorMedianPB:null},
    note:'Bilanço yayın tarihi, ana ortaklık/adi paylara ait özkaynak, sektör tipi ve karşılaştırma bazını rapordan doğrulayın. Sağlayıcı verisini onaysız puanlamayın.'};
}
module.exports={dataset};
