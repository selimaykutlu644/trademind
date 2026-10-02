'use strict';
// Transparent heuristic ranking, not a calibrated probability or backtested model.
const DEFAULT_WEIGHTS = { technical: 30, chart: 20, valuation: 20, financial: 20, risk: 10 };
const TITLES = { technical:'Teknik göstergeler', chart:'Grafik yapısı', valuation:'Değerleme', financial:'Üç aylık finansallar', risk:'Risk / dayanıklılık' };
const clamp = (x, a = 0, b = 100) => Math.min(b, Math.max(a, x));
const num = x => typeof x === 'number' && Number.isFinite(x) ? x : null;
const avg = xs => xs.length ? xs.reduce((a,b) => a+b,0) / xs.length : null;
const ratio = (a,b) => num(a) != null && num(b) != null && b > 0 ? a/b : null;
const round = x => x == null ? null : Math.round(x * 100) / 100;
function error(message) { const e = new Error(message); e.status = 400; throw e; }

// Candlestick pattern detection
function detectCandlestickPattern(bars) {
  if (bars.length < 3) return null;
  const candle = bars[bars.length - 1];
  const prev = bars[bars.length - 2];
  const prev2 = bars[bars.length - 3];
  
  const body = Math.abs(candle.close - candle.open);
  const upperShadow = candle.high - Math.max(candle.open, candle.close);
  const lowerShadow = Math.min(candle.open, candle.close) - candle.low;
  const range = candle.high - candle.low;
  const bodyRatio = range > 0 ? body / range : 0;
  
  // Doji: body is very small (< 10% of range)
  if (bodyRatio < 0.1 && range > 0) return { pattern: 'doji', signal: 'neutral', strength: 0.5 };
  
  // Hammer: small body at top, long lower shadow (2x body), no upper shadow
  if (lowerShadow > body * 2 && upperShadow < body * 0.5 && bodyRatio < 0.3) {
    return { pattern: 'hammer', signal: prev.close > candle.open ? 'bullish' : 'bearish', strength: 0.7 };
  }
  
  // Inverted Hammer: small body at bottom, long upper shadow
  if (upperShadow > body * 2 && lowerShadow < body * 0.5 && bodyRatio < 0.3) {
    return { pattern: 'inverted_hammer', signal: prev.close < candle.open ? 'bullish' : 'bearish', strength: 0.6 };
  }
  
  // Bullish Engulfing: previous bearish, current bullish, body engulfs previous
  if (prev.close < prev.open && candle.close > candle.open && 
      candle.open < prev.close && candle.close > prev.open) {
    return { pattern: 'bullish_engulfing', signal: 'bullish', strength: 0.8 };
  }
  
  // Bearish Engulfing: previous bullish, current bearish, body engulfs previous
  if (prev.close > prev.open && candle.close < candle.open && 
      candle.open > prev.close && candle.close < prev.open) {
    return { pattern: 'bearish_engulfing', signal: 'bearish', strength: 0.8 };
  }
  
  // Morning Star: bearish trend, doji/small body, bullish
  if (prev2.close < prev2.open && prev.close < prev.open && candle.close > candle.open &&
      Math.abs(prev.close - prev.open) < (prev2.high - prev2.low) * 0.3) {
    return { pattern: 'morning_star', signal: 'bullish', strength: 0.75 };
  }
  
  // Evening Star: bullish trend, doji/small body, bearish
  if (prev2.close > prev2.open && prev.close > prev.open && candle.close < candle.open &&
      Math.abs(prev.close - prev.open) < (prev2.high - prev2.low) * 0.3) {
    return { pattern: 'evening_star', signal: 'bearish', strength: 0.75 };
  }
  
  // Three White Soldiers: three consecutive bullish candles
  if (bars.length >= 3) {
    const last3 = bars.slice(-3);
    if (last3.every(b => b.close > b.open) && 
        last3.every((b, i) => i === 0 || b.close > last3[i-1].close)) {
      return { pattern: 'three_white_soldiers', signal: 'bullish', strength: 0.85 };
    }
  }
  
  // Three Black Crows: three consecutive bearish candles
  if (bars.length >= 3) {
    const last3 = bars.slice(-3);
    if (last3.every(b => b.close < b.open) && 
        last3.every((b, i) => i === 0 || b.close < last3[i-1].close)) {
      return { pattern: 'three_black_crows', signal: 'bearish', strength: 0.85 };
    }
  }
  
  return null;
}

// Bollinger Bands calculation
function calculateBollingerBands(bars, period = 20, stdDev = 2) {
  if (bars.length < period) return null;
  const closes = bars.slice(-period).map(b => b.close);
  const sma = avg(closes);
  const variance = avg(closes.map(c => Math.pow(c - sma, 2)));
  const std = Math.sqrt(variance);
  
  return {
    middle: sma,
    upper: sma + stdDev * std,
    lower: sma - stdDev * std,
    bandwidth: std > 0 && sma > 0 ? (stdDev * std * 2) / sma : null,
    lastClose: bars[bars.length - 1].close
  };
}

// Fisher Transform calculation
function calculateFisherTransform(bars, period = 10) {
  if (bars.length < period + 1) return null;
  
  let fisher = [];
  let fisherPrev = 0;
  
  for (let i = period; i < bars.length; i++) {
    const maxH = Math.max(...bars.slice(i - period, i).map(b => b.high));
    const minL = Math.min(...bars.slice(i - period, i).map(b => b.low));
    const range = maxH - minL;
    
    if (range === 0) {
      fisher.push(fisherPrev);
      continue;
    }
    
    const x = 0.33 * 2 * ((bars[i].close - minL) / range - 0.5) + 0.67 * (fisher[i - 1] || 0);
    const fx = 0.5 * Math.log((1 + x) / (1 - x)) || 0;
    fisher.push(fx);
    fisherPrev = fx;
  }
  
  const current = fisher[fisher.length - 1];
  const prev = fisher[fisher.length - 2];
  
  if (current == null || prev == null) return null;
  
  // Signal: cross above 0 = buy, cross below 0 = sell
  let signal = 'neutral';
  if (prev < 0 && current > 0) signal = 'buy';
  else if (prev > 0 && current < 0) signal = 'sell';
  
  return { current, prev, signal };
}

// Double Top/Bottom detection
function detectDoublePattern(bars, lookback = 20, tolerance = 0.02) {
  if (bars.length < lookback * 2) return null;
  
  const recent = bars.slice(-lookback);
  const highs = recent.map(b => b.high);
  const lows = recent.map(b => b.low);
  
  const maxHigh = Math.max(...highs);
  const minLow = Math.min(...lows);
  
  // Find peaks
  const peaks = [];
  for (let i = 2; i < highs.length - 2; i++) {
    if (highs[i] > highs[i-1] && highs[i] > highs[i-2] && 
        highs[i] > highs[i+1] && highs[i] > highs[i+2]) {
      peaks.push({ index: i, value: highs[i] });
    }
  }
  
  // Double Top: two similar peaks
  if (peaks.length >= 2) {
    const lastTwo = peaks.slice(-2);
    const diff = Math.abs(lastTwo[0].value - lastTwo[1].value);
    const avg = (lastTwo[0].value + lastTwo[1].value) / 2;
    if (diff / avg < tolerance) {
      return { pattern: 'double_top', signal: 'bearish', strength: 0.7, 
               level: avg, index1: lastTwo[0].index, index2: lastTwo[1].index };
    }
  }
  
  // Find troughs
  const troughs = [];
  for (let i = 2; i < lows.length - 2; i++) {
    if (lows[i] < lows[i-1] && lows[i] < lows[i-2] && 
        lows[i] < lows[i+1] && lows[i] < lows[i+2]) {
      troughs.push({ index: i, value: lows[i] });
    }
  }
  
  // Double Bottom: two similar troughs
  if (troughs.length >= 2) {
    const lastTwo = troughs.slice(-2);
    const diff = Math.abs(lastTwo[0].value - lastTwo[1].value);
    const avg = (lastTwo[0].value + lastTwo[1].value) / 2;
    if (diff / avg < tolerance) {
      return { pattern: 'double_bottom', signal: 'bullish', strength: 0.7,
               level: avg, index1: lastTwo[0].index, index2: lastTwo[1].index };
    }
  }
  
  return null;
}

// Advanced Support/Resistance
function detectSupportResistance(bars, lookback = 50, touches = 2) {
  if (bars.length < lookback) return { support: [], resistance: [] };
  
  const period = bars.slice(-lookback);
  const highs = period.map(b => b.high);
  const lows = period.map(b => b.low);
  
  // Find resistance levels (price touched multiple times from below)
  const resistanceLevels = [];
  for (let i = 0; i < highs.length; i++) {
    const level = highs[i];
    let touches = 0;
    for (let j = 0; j < highs.length; j++) {
      if (Math.abs(highs[j] - level) / level < 0.01) touches++;
    }
    if (touches >= 2 && !resistanceLevels.find(r => Math.abs(r - level) / level < 0.01)) {
      resistanceLevels.push(level);
    }
  }
  
  // Find support levels (price touched multiple times from above)
  const supportLevels = [];
  for (let i = 0; i < lows.length; i++) {
    const level = lows[i];
    let touches = 0;
    for (let j = 0; j < lows.length; j++) {
      if (Math.abs(lows[j] - level) / level < 0.01) touches++;
    }
    if (touches >= 2 && !supportLevels.find(s => Math.abs(s - level) / level < 0.01)) {
      supportLevels.push(level);
    }
  }
  
  // Sort and take top levels
  const sortedResistance = resistanceLevels.sort((a, b) => b - a).slice(0, 3);
  const sortedSupport = supportLevels.sort((a, b) => a - b).slice(0, 3);
  
  return { 
    support: sortedSupport, 
    resistance: sortedResistance,
    nearestSupport: sortedSupport.length > 0 ? sortedSupport[0] : null,
    nearestResistance: sortedResistance.length > 0 ? sortedResistance[0] : null
  };
}
function weights(input) {
  const w = input == null ? { ...DEFAULT_WEIGHTS } : input;
  if (Object.keys(w).length !== 5 || Object.keys(DEFAULT_WEIGHTS).some(k => num(w[k]) == null || w[k] < 0 || w[k] > 100)) error('Beş ağırlık 0–100 arasında sayı olmalı.');
  if (Math.abs(Object.values(w).reduce((a,b)=>a+b,0) - 100) > .001) error('Ağırlıkların toplamı %100 olmalı.');
  return w;
}
function date(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const d = new Date(value + 'T00:00:00Z');
  return !Number.isNaN(d.valueOf()) && d.toISOString().slice(0,10) === value ? d : null;
}
const days = (a,b) => (a-b)/86400000;
function metric(key, label, value, score, formula) { return { key, label, value: round(value), score: score == null ? null : round(clamp(score)), formula }; }
function group(key, items, totalExpected) {
  const valid = items.filter(x => x.score != null);
  return { key, title:TITLES[key], score:round(avg(valid.map(x=>x.score))), coverage:valid.length/totalExpected, metrics:items };
}
function validateBars(bars, now) {
  if (!Array.isArray(bars) || bars.length > 1500) error('Fiyat serisi en fazla 1500 mum içeren dizi olmalı.');
  let previous = '';
  return bars.map(b => {
    const d = date(b.date);
    if (!d || d > now || b.date <= previous) error('Mum tarihleri geçmişte, benzersiz ve eskiden yeniye sıralı olmalı.');
    if (['open','high','low','close'].some(k => num(b[k]) == null || b[k] <= 0) || num(b.volume) == null || b.volume < 0 || b.low > Math.min(b.open,b.close) || b.high < Math.max(b.open,b.close)) error('OHLCV verisi geçersiz.');
    previous = b.date; return b;
  });
}
function chartMetrics(bars) {
  const close = bars.map(b=>b.close), last = close.at(-1);
  const ma20 = bars.length >= 20 ? avg(close.slice(-20)) : null;
  const ma50 = bars.length >= 50 ? avg(close.slice(-50)) : null;
  const prior20 = bars.length >= 21 ? bars.slice(-21,-1) : [];
  const resistance = prior20.length ? Math.max(...prior20.map(b=>b.high)) : null;
  const support = prior20.length ? Math.min(...prior20.map(b=>b.low)) : null;
  const breakout = resistance != null && support != null ? last > resistance ? 100 : last < support ? 0 : clamp((last-support)/(resistance-support || 1)*100) : null;
  const meanVolume = prior20.length ? avg(prior20.map(b=>b.volume)) : null;
  const volumeRatio = ratio(bars.at(-1)?.volume,meanVolume);
  const direction = close.length > 1 ? Math.sign(last-close.at(-2)) : 0;
  const volumeScore = volumeRatio == null ? null : clamp(50 + direction * Math.min(volumeRatio,3) * 15);
  const trend = ma20 != null && ma50 != null ? (last > ma20 ? 35 : 0) + (last > ma50 ? 35 : 0) + (ma20 > ma50 ? 30 : 0) : null;
  
  // Advanced pattern detection
  const candlestick = detectCandlestickPattern(bars);
  const bollinger = calculateBollingerBands(bars);
  const fisher = calculateFisherTransform(bars);
  const doublePattern = detectDoublePattern(bars);
  const srLevels = detectSupportResistance(bars);
  
  // Bollinger score
  let bollingerScore = null;
  if (bollinger) {
    if (bollinger.lastClose >= bollinger.upper) bollingerScore = 90;
    else if (bollinger.lastClose <= bollinger.lower) bollingerScore = 90;
    else if (bollinger.bandwidth < 0.02) bollingerScore = 50; // Squeeze
    else bollingerScore = 50;
  }
  
  // Fisher score
  const fisherScore = fisher ? (fisher.signal === 'buy' ? 75 : fisher.signal === 'sell' ? 25 : 50) : null;
  
  // Pattern score
  const patternScore = candlestick ? (candlestick.signal === 'bullish' ? 75 : candlestick.signal === 'bearish' ? 25 : 50) : null;
  
  return { group:group('chart',[
    metric('trend','20 / 50 dönem trendi',last,trend,'Fiyat>SMA20:35; fiyat>SMA50:35; SMA20>SMA50:30'),
    metric('range','Önceki 20 mum aralığı',last,breakout,'Direnç üstü:100; destek altı:0; aralık içindeki konum ×100'),
    metric('volume','Hacim teyidi',volumeRatio,volumeScore,'50 + günlük yön × min(hacim / önceki 20 ortalama,3) ×15'),
    metric('candlestick','Mum şekli analizi',candlestick?.pattern,patternScore,'Boğa sinyali:75; ayı sinyali:25; nötr:50'),
    metric('bollinger','Bollinger Bantları',bollinger?.bandwidth,bollingerScore,'Üst/alt bant:90; sıkışma:50; orta:50'),
    metric('fisher','Fisher Dönüşümü',fisher?.signal,fisherScore,'Al sinyali:75; sat sinyali:25; nötr:50'),
  ],6), levels:{ support20:round(support), resistance20:round(resistance), sma20:round(ma20), sma50:round(ma50), lastClose:round(last),
    candlestick, bollinger, fisher, doublePattern, supportResistance: srLevels } };
}
function calculate(input, now = new Date()) {
  if (!input || typeof input !== 'object') error('Skor girdisi gerekli.');
  const w = weights(input.weights);
  const ticker = input.ticker;
  if (typeof ticker !== 'string' || !/^[A-Z0-9_.!\-]{1,20}:[A-Z0-9_.!\-]{1,30}$/.test(ticker)) error('Sembol geçersiz.');
  const dataset = input.dataset || {};
  if (Object.keys(dataset).length && dataset.ticker !== ticker) error('Veri setindeki sembol seçilen sembolle eşleşmiyor.');
  const crypto = /^(BINANCE|BYBIT|COINBASE|KRAKEN|OKX|BITSTAMP|KUCOIN|MEXC):/.test(ticker);
  const warnings = ['Skor deneysel bir sıralama kuralıdır; başarı olasılığı değildir. Geriye dönük kalibrasyon yapılmadı.'];
  const indicators = input.indicators || {};
  const rawScore = num(indicators['Recommend.All']);
  const rsi = num(indicators.RSI);
  const macd = num(indicators['MACD.macd']), macdSignal = num(indicators['MACD.signal']);
  const technical = group('technical',[
    metric('recommend','Bileşik teknik skor',rawScore,rawScore != null && rawScore >= -1 && rawScore <= 1 ? (rawScore+1)*50:null,'(TradingView Recommend.All +1) ×50'),
    metric('rsi','RSI dengesi',rsi,rsi != null && rsi >= 0 && rsi <=100 ? rsi <30 ? 35 : rsi <=65 ? 50+(rsi-30)*50/35 : Math.max(10,100-(rsi-65)*3):null,'30–65 bandında 50→100; >65 aşırı alım cezası; <30:35'),
    metric('macd','MACD yönü',macd != null && macdSignal != null ? macd-macdSignal:null,macd != null && macdSignal != null ? macd>macdSignal ? 75 : macd<macdSignal ? 25 : 50:null,'MACD>sinyal:75; eşit:50; altında:25'),
  ],3);
  let bars = validateBars(dataset.bars || [], now);
  if (bars.length && (!dataset.priceSource || !['split-adjusted','total-return-adjusted'].includes(dataset.priceAdjustment) || dataset.priceInterval !== '1D')) {
    warnings.push('Grafik skoru için kaynak, günlük seri ve kurumsal işlemlere göre düzeltilmiş fiyat beyanı gerekli.'); bars=[];
  }
  if (bars.length && days(now,date(bars.at(-1).date))>10) { warnings.push('Fiyat serisi 10 günden eski; grafik/risk puanına katılmadı.'); bars=[]; }
  const chart = chartMetrics(bars);
  const f = dataset.financials || {};
  let usable = !!Object.keys(f).length;
  if (usable && crypto) { usable=false; warnings.push('Kriptoda şirket bilançosu ve PD/DD uygulanmaz.'); }
  if (usable) {
    if (!date(f.periodEnd) || !date(f.previousYearPeriodEnd) || !date(f.publishedAt) || f.periodType !== 'standalone-quarter' || !f.source || !f.currency || !f.unit || !['unit','thousand','million'].includes(f.unit)) error('Finansallarda kaynak, yayın tarihi, üç aylık dönem, karşılaştırma dönemi, para birimi ve ölçek gerekli.');
    if (date(f.periodEnd)>now || date(f.publishedAt)>now || date(f.publishedAt)<date(f.periodEnd)) error('Finansal dönem / yayın tarihi geçersiz veya gelecekte.');
    const delta = days(date(f.periodEnd),date(f.previousYearPeriodEnd));
    if (delta < 350 || delta > 380) error('Karşılaştırma aynı çeyreğin önceki yılıyla yapılmalı.');
    if (f.previousYearComparable !== true) { usable=false; warnings.push('Önceki yıl verilerinin aynı muhasebe / enflasyon düzeltme bazında olduğu doğrulanmadı.'); }
    if (days(now,date(f.periodEnd)) > 200) { usable=false; warnings.push('Finansal dönem 200 günden eski; puana katılmadı.'); }
    if (f.sectorProfile !== 'non-financial') { usable=false; warnings.push('Banka, sigorta ve finans şirketleri için ayrı sektör modeli gerekir; genel bilanço modeli uygulanmadı.'); }
  }
  const get = key => usable ? num(f[key]) : null;
  const scale = { unit:1, thousand:1000, million:1000000 }[f.unit] || 1;
  const shares = get('sharesOutstanding');
  const commonEquity = get('commonEquity');
  const bookPerShare = ratio(commonEquity == null ? null : commonEquity*scale, shares);
  const priceValue = num(input.currentPrice);
  const currencyMatch = dataset.priceCurrency && dataset.priceCurrency === f.currency;
  if (usable && !currencyMatch) warnings.push('Fiyat ile bilanço para birimi eşleşmiyor; değerleme hesaplanmadı.');
  const bookRatio = currencyMatch ? ratio(priceValue,bookPerShare):null;
  const ttm = get('netIncomeTTM');
  const eps = ttm == null ? null : ratio(ttm*scale,shares);
  const pe = currencyMatch ? ratio(priceValue,eps):null;
  const peerPB = get('sectorMedianPB'), peerPE = get('sectorMedianPE');
  if (usable && commonEquity != null && commonEquity <=0) warnings.push('Özkaynak sıfır veya negatif; PD/DD olumlu bir ucuzluk göstergesi olarak kullanılamaz.');
  const peerScore = (value,reference) => value == null || reference == null || reference <=0 ? null : clamp(100 - value/reference*50);
  
  // Advanced valuation metrics
  const currentPrice = num(input.currentPrice);
  const ebitda = get('ebitda'); // EBITDA from financials
  const totalRevenue = get('revenue');
  const grossProfit = get('grossProfit');
  const operatingIncome = get('operatingIncome');
  const totalAssets = get('totalAssets');
  const marketCap = currentPrice != null && shares != null ? currentPrice * shares : null;
  
  // EV/EBITDA calculation
  const enterpriseValue = marketCap != null && debt != null && cash != null ? marketCap + debt - cash : null;
  const evEbitda = ratio(enterpriseValue, ebitda == null ? null : ebitda * scale);
  
  // EV/Sales
  const evSales = ratio(enterpriseValue, totalRevenue == null ? null : totalRevenue * scale);
  
  // ROE (Return on Equity)
  const roe = ratio(netIncome == null ? null : netIncome * scale, commonEquity);
  
  // ROA (Return on Assets)
  const roa = ratio(netIncome == null ? null : netIncome * scale, totalAssets == null ? null : totalAssets * scale);
  
  // Gross Margin
  const grossMargin = ratio(grossProfit, totalRevenue);
  
  // Operating Margin
  const operatingMargin = ratio(operatingIncome, totalRevenue);
  
  const valuation = group('valuation',[
    metric('pb','PD/DD',bookRatio,peerScore(bookRatio,peerPB),'Puan=100−(PD/DD / sektör medyanı)×50; 0–100 sınırı'),
    metric('pe','F/K (son 12 ay)',pe,usable && currencyMatch && ttm != null && ttm <=0 ? 0 : peerScore(pe,peerPE),'Puan=100−(F/K / sektör medyanı)×50; zarar varsa 0'),
    metric('ev_ebitda','EV/EBITDA',evEbitda,peerScore(evEbitda,peerPB != null ? peerPB * 8 : null),'Puan=100−(EV/EBITDA / referans)×50'),
    metric('ev_sales','EV/Sales',evSales,peerScore(evSales,peerPB != null ? peerPB * 3 : null),'Puan=100−(EV/Sales / referans)×50'),
  ],4);
  if (usable && (peerPB == null || peerPE == null)) warnings.push('Değerleme puanı için aynı sektöre ait PD/DD ve F/K medyanlarını girin; oranlar medyan olmadan da gösterilir.');
  const revenue = get('revenue'), prevRevenue = get('previousYearRevenue');
  const netIncome = get('netIncome'), prevNet = get('previousYearNetIncome');
  const growth = prevRevenue != null && prevRevenue >0 && revenue != null ? (revenue/prevRevenue-1)*100:null;
  const margin = ratio(netIncome,revenue), prevMargin = ratio(prevNet,prevRevenue);
  const deltaMargin = margin != null && prevMargin != null ? (margin-prevMargin)*100:null;
  const cashConversion = ratio(get('operatingCashFlow'), netIncome);
  const financial = group('financial',[
    metric('revenueGrowth','Hasılat yıllık büyümesi (%)',growth,growth == null?null:50+growth,'50+büyüme yüzdesi; 0–100 sınırı'),
    metric('marginChange','Net kâr marjı değişimi (puan)',deltaMargin,deltaMargin==null?null:50+deltaMargin*5,'50 + marj değişimi ×5; 0–100 sınırı'),
    metric('cashQuality','Faaliyet nakdi / net kâr',cashConversion,netIncome != null && netIncome <=0 ? 0 : cashConversion == null?null:cashConversion*75,'Nakit / pozitif net kâr ×75; zarar varsa 0'),
    metric('roe','Özkaynak Karlılığı (ROE %)',roe,roe == null?null:clamp(roe * 2),'ROE ×2; 0–100 sınırı'),
    metric('roa','Varlık Karlılığı (ROA %)',roa,roa == null?null:clamp(roa * 5),'ROA ×5; 0–100 sınırı'),
    metric('grossMargin','Brüt Kar Marjı (%)',grossMargin == null?null:grossMargin*100,grossMargin == null?null:clamp(grossMargin*100*2),'Brüt marj % ×2; 0–100 sınırı'),
    metric('operatingMargin','İşletme Kar Marjı (%)',operatingMargin == null?null:operatingMargin*100,operatingMargin == null?null:clamp(operatingMargin*100*2),'İşletme marjı % ×2; 0–100 sınırı'),
  ],7);
  const currentRatio = ratio(get('currentAssets'),get('currentLiabilities'));
  const cash = get('cash'), debt = get('interestBearingDebt');
  const netDebtEquity = debt != null && cash != null ? ratio(debt-cash,commonEquity):null;
  let drawdown=null;
  if (bars.length>=50) { let peak=bars[0].close, max=0; for (const b of bars) { peak=Math.max(peak,b.close); max=Math.max(max,(peak-b.close)/peak); } drawdown=max*100; }
  const risk = group('risk',[
    metric('liquidity','Cari oran',currentRatio,currentRatio==null?null:currentRatio/2*100,'Cari oran /2 ×100; 0–100 sınırı'),
    metric('leverage','Net finansal borç / özkaynak',netDebtEquity,usable && commonEquity!=null && commonEquity<=0 ? 0:netDebtEquity==null?null:100-Math.max(0,netDebtEquity)*50,'100−max(0,net borç/özkaynak)×50'),
    metric('drawdown','Fiyat serisi azami düşüş (%)',drawdown,drawdown==null?null:100-drawdown*2,'100−azami düşüş yüzdesi ×2'),
  ],3);
  const groups=[technical,chart.group,valuation,financial,risk].map(g => ({...g,weight:w[g.key],effectiveWeight:round(w[g.key]*g.coverage),contribution:g.score==null?0:round(g.score*w[g.key]*g.coverage/100)}));
  const coverage=groups.reduce((a,g)=>a+g.weight*g.coverage,0);
  const earned=groups.reduce((a,g)=>a+(g.score ?? 0)*g.weight*g.coverage/100,0);
  const provisional=coverage>0 ? earned/(coverage/100):null;
  const complete=coverage>=99.999;
  if (!bars.length) warnings.push('Grafik okuması için en az 50 günlük düzeltilmiş OHLCV veri seti önerilir; görüntüdeki grafik skor motoruna otomatik veri sağlamaz.');
  if (!usable) warnings.push('Kullanılabilir bilanço verisi yok; temel analiz tamamlanmadı.');
  if (!complete) warnings.push('Eksik veriler yeniden ağırlıklandırılarak yalnızca geçici skor gösterilir; tam kapsamlı toplam skor yayımlanmaz.');
  if (crypto) warnings.push('Bu model hisse odaklıdır; kripto için bilanço ağırlıkları sıfırlanıp teknik/grafik ağırlıkları yeniden ayarlanmalıdır.');
  return { version:'TradeMind-score-1.0', ticker, calculatedAt:now.toISOString(), weights:w, totalScore:complete?round(provisional):null, provisionalScore:round(provisional), coverage:round(coverage), complete, groups,
    derived:{bookValuePerShare:round(bookPerShare),pe:round(pe),pb:round(bookRatio),revenueGrowth:round(growth),netMargin:round(margin==null?null:margin*100),currentRatio:round(currentRatio),
      evEbitda:round(evEbitda),evSales:round(evSales),roe:round(roe == null?null:roe*100),roa:round(roa == null?null:roa*100),grossMargin:round(grossMargin == null?null:grossMargin*100),operatingMargin:round(operatingMargin == null?null:operatingMargin*100),
      ...chart.levels},
    provenance:{technicalSource:input.technicalSource || null,priceSource:dataset.priceSource || null,priceAsOf:bars.at(-1)?.date || null,financialSource:usable?f.source:null,periodEnd:usable?f.periodEnd:null,publishedAt:usable?f.publishedAt:null,verification:dataset.verification || 'user-supplied; not independently verified'}, warnings };
}
module.exports={calculate,weights,DEFAULT_WEIGHTS,validateBars};
