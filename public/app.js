const $ = id => document.getElementById(id);
const QUICK = ['THYAO','ASELS','GARAN','BIMAS','EREGL','KCHOL','BTC-USD','ETH-USD','AAPL','NVDA'];
const SFX = { '1D': '', '1W': '|1W', '4H': '|240', '1H': '|60', '1M': '|1M' };
const WIDGET = { '1D': 'D', '1W': 'W', '4H': '240', '1H': '60', '1M': 'M' };
const TFNAME = { '1D': 'Günlük', '1W': 'Haftalık', '4H': '4 Saat', '1H': '1 Saat', '1M': 'Aylık' };
const NOSFX = ['name', 'description', 'change', 'volume'];
const THR = { turkey: [0, 5e6, 5e7], crypto: [0, 1e6, 2e7], america: [0, 1e7, 1e8] };
const MNAME = { turkey: 'BIST', crypto: 'Kripto', america: 'ABD' };
const STABLE = /^(USDC|FDUSD|TUSD|BUSD|DAI|USDP|USD1|PYUSD|USDE|EUR|AEUR|TRY|GBP)USDT$/;
const LABEL = { 1: 'AL', '-1': 'SAT', 0: 'NÖTR' };
const TR = { 'İ':'I','ı':'I','Ş':'S','ş':'S','Ğ':'G','ğ':'G','Ü':'U','ü':'U','Ö':'O','ö':'O','Ç':'C','ç':'C' };
let last = null, busy = false;

// ------------------------------ YARDIMCILAR ------------------------------
const fmt = (x, d = 2) => Number.isFinite(x) ? Number(x).toFixed(d) : 'n/a';
const fmtP = x => !Number.isFinite(x) ? 'n/a' : Math.abs(x) >= 100 ? x.toFixed(2) : Math.abs(x) >= 1 ? x.toFixed(3) : Math.abs(x) >= 0.01 ? x.toFixed(4) : x.toPrecision(4);
const recOf = v => v >= 0.5 ? 'GÜÇLÜ AL' : v >= 0.1 ? 'AL' : v <= -0.5 ? 'GÜÇLÜ SAT' : v <= -0.1 ? 'SAT' : 'NÖTR';
const recClass = r => r.includes('SAT') ? 'sell' : r.endsWith('AL') ? 'buy' : 'neu';
const setMsg = t => { $('msg').textContent = t || ''; };
const normSym = s => s.replace(/[İıŞşĞğÜüÖöÇç]/g, ch => TR[ch]).replace(/\s+/g, '').toUpperCase();

async function api(url, opt) {
  const r = await fetch(url, opt);
  let j;
  try { j = await r.json(); } catch (e) { throw new Error('Sunucu yanıtı okunamadı'); }
  if (!r.ok || j.error) throw new Error(j.error || 'Hata ' + r.status);
  return j;
}

function marketOfEx(ex) {
  if (ex === 'BIST') return 'turkey';
  return ['BINANCE', 'BYBIT', 'COINBASE', 'KRAKEN', 'OKX', 'BITSTAMP', 'KUCOIN', 'MEXC'].includes(ex) ? 'crypto' : 'america';
}
function candidates(input) {
  const s = normSym(input);
  if (!s) return [];
  if (s.includes(':')) return [{ market: marketOfEx(s.split(':')[0]), ticker: s }];
  if (s.endsWith('.IS')) return [{ market: 'turkey', ticker: 'BIST:' + s.slice(0, -3) }];
  const cm = s.match(/^([A-Z0-9]+)-USD$/);
  if (cm) return [{ market: 'crypto', ticker: 'BINANCE:' + cm[1] + 'USDT' }];
  if (/USDT$/.test(s) && s.length > 5) return [{ market: 'crypto', ticker: 'BINANCE:' + s }];
  return [
    { market: 'turkey', ticker: 'BIST:' + s },
    { market: 'america', ticker: 'NASDAQ:' + s },
    { market: 'america', ticker: 'NYSE:' + s },
    { market: 'crypto', ticker: 'BINANCE:' + s + 'USDT' }
  ];
}

// ------------------------------ TARAYICI ------------------------------
async function scan() {
  if (busy) return;
  busy = true; $('scanBtn').disabled = true;
  const tf = $('tf').value, order = $('order').value, lvl = +$('liq').value, uni = $('uni').value;
  const markets = uni === 'all' ? ['turkey', 'crypto', 'america'] : [uni];
  const rows = [], errs = [];
  let raw = 0;
  $('scanCard').hidden = false; $('scanBody').innerHTML = '';
  for (const m of markets) {
    setMsg(`${MNAME[m]} taranıyor...`);
    try {
      const j = await api(`/api/scan?market=${m}&tf=${tf}&order=${order}`);
      const data = j.data || [];
      raw += data.length;
      let part = [];
      for (const r of data) {
        const d = r.d, price = d[2], rec = d[5], vol = d[10] || 0;
        if (rec == null || price == null) continue;
        if (price * vol < THR[m][lvl]) continue;
        if (m === 'crypto' && (!/USDT$/.test(d[0]) || STABLE.test(d[0]))) continue;
        part.push({ m, s: r.s, name: d[0], desc: d[1] || '', price, d1: d[3], w1: d[4], rec, ma: d[6], osc: d[7], rsi: d[8], adx: d[9] });
      }
      if (m === 'crypto' && part.some(x => x.s.startsWith('BINANCE:'))) part = part.filter(x => x.s.startsWith('BINANCE:'));
      rows.push(...part);
    } catch (e) { errs.push(`${MNAME[m]}: ${e.message}`); }
  }
  const dir = order === 'asc' ? 1 : -1;
  rows.sort((a, b) => dir * (a.rec - b.rec) || (b.adx || 0) - (a.adx || 0));
  renderScan(rows.slice(0, 50), order);
  $('scanInfo').textContent = `${TFNAME[tf]} • ${raw} sembol tarandı, ${rows.length} tanesi filtreden geçti`;
  setMsg(errs.length ? 'Hata: ' + errs.join(' | ') : '');
  busy = false; $('scanBtn').disabled = false;
}

function renderScan(top, order) {
  const body = $('scanBody'); body.innerHTML = '';
  $('scanTitle').textContent = order === 'asc' ? 'En düşük skorlu 50 (SAT eğilimi)' : 'En yüksek skorlu 50 (AL eğilimi)';
  top.forEach((r, k) => {
    const tr = document.createElement('tr'); tr.className = 'click';
    const label = recOf(r.rec);
    const cells = [k + 1, r.s, r.desc.slice(0, 28), fmtP(r.price), fmt(r.d1) + '%', fmt(r.w1) + '%', label,
      Math.round(r.rec * 100), r.ma == null ? '-' : Math.round(r.ma * 100), r.osc == null ? '-' : Math.round(r.osc * 100),
      fmt(r.rsi, 0), fmt(r.adx, 0)];
    cells.forEach((t, c) => {
      const td = document.createElement('td'); td.textContent = t;
      if (c === 6) td.className = recClass(label);
      if (c === 4 || c === 5) td.className = parseFloat(t) >= 0 ? 'buy' : 'sell';
      tr.appendChild(td);
    });
    tr.onclick = () => { $('sym').value = r.s; analyzeTicker([{ market: r.m, ticker: r.s }]); window.scrollTo({ top: 0, behavior: 'smooth' }); };
    body.appendChild(tr);
  });
}

// ------------------------------ DETAY ANALİZ ------------------------------
function makeVotes(num, p) {
  const out = [];
  const add = (name, value, s, note) => out.push({ name, value, s, label: LABEL[s], note });
  const MAS = ['EMA10','EMA20','EMA30','EMA50','EMA100','EMA200','SMA10','SMA20','SMA30','SMA50','SMA100','SMA200','Ichimoku.BLine','VWMA','HullMA9'];
  MAS.forEach(n => {
    const m = num(n);
    if (m == null || p == null) return;
    add(n === 'Ichimoku.BLine' ? 'Ichimoku Kijun' : n, fmtP(m), p > m ? 1 : p < m ? -1 : 0, 'Fiyat ortalamanın üstünde mi');
  });
  let x = num('RSI');
  if (x != null) add('RSI(14)', fmt(x), x < 30 ? 1 : x > 70 ? -1 : 0, '<30 aşırı satım, >70 aşırı alım');
  const k = num('Stoch.K'), dd = num('Stoch.D');
  if (k != null && dd != null) add('Stochastic', `K=${fmt(k)} D=${fmt(dd)}`, k < 20 && dd < 20 && k > dd ? 1 : k > 80 && dd > 80 && k < dd ? -1 : 0, '20 altı dönüş AL, 80 üstü dönüş SAT');
  x = num('CCI20');
  if (x != null) add('CCI(20)', fmt(x), x < -100 ? 1 : x > 100 ? -1 : 0, '±100 eşikleri');
  const a = num('ADX'), pd = num('ADX+DI'), md = num('ADX-DI');
  if (a != null && pd != null && md != null) add('ADX(14)', `ADX=${fmt(a)} +DI=${fmt(pd)} -DI=${fmt(md)}`, a > 20 ? (pd > md ? 1 : -1) : 0, 'ADX>20 ise trend var, yönü DI belirler');
  x = num('AO');
  if (x != null) add('Awesome Osc.', fmtP(x), x > 0 ? 1 : x < 0 ? -1 : 0, 'Sıfır çizgisine göre');
  x = num('Mom');
  if (x != null) add('Momentum(10)', fmtP(x), x > 0 ? 1 : -1, 'Sıfırın üstü yükseliş');
  const mc = num('MACD.macd'), ms = num('MACD.signal');
  if (mc != null && ms != null) add('MACD', `${fmtP(mc)} / ${fmtP(ms)}`, mc > ms ? 1 : -1, 'MACD çizgisi sinyal çizgisine göre');
  x = num('Stoch.RSI.K');
  if (x != null) add('Stoch RSI', fmt(x), x < 20 ? 1 : x > 80 ? -1 : 0, '20 altı AL, 80 üstü SAT');
  x = num('W.R');
  if (x != null) add('Williams %R', fmt(x), x < -80 ? 1 : x > -20 ? -1 : 0, '-80 altı aşırı satım, -20 üstü aşırı alım');
  x = num('BBPower');
  if (x != null) add('Bull/Bear Power', fmtP(x), x > 0 ? 1 : x < 0 ? -1 : 0, 'Sıfırın üstü alıcı baskısı');
  x = num('UO');
  if (x != null) add('Ultimate Osc.', fmt(x), x < 30 ? 1 : x > 70 ? -1 : 0, '<30 AL, >70 SAT');
  return out;
}

function showChart(tvSymbol, tf) {
  const box = $('tvchart'); box.innerHTML = '';
  if (!window.TradingView) { box.textContent = 'TradingView grafiği yüklenemedi (tv.js erişilemedi).'; return; }
  new TradingView.widget({
    autosize: true, symbol: tvSymbol, interval: WIDGET[tf], timezone: 'Europe/Istanbul', theme: 'dark', style: '1',
    locale: 'tr', enable_publishing: false, allow_symbol_change: false, container_id: 'tvchart',
    studies: ['RSI@tv-basicstudies', 'MACD@tv-basicstudies', 'BB@tv-basicstudies']
  });
}

function renderDetail(ticker, cols, d, tf) {
  const sfx = SFX[tf];
  const v = n => { const k = cols.indexOf(NOSFX.includes(n) ? n : n + sfx); return k >= 0 ? d[k] : null; };
  const num = n => { const x = v(n); return typeof x === 'number' ? x : null; };
  const p = num('close'), all = num('Recommend.All'), ma = num('Recommend.MA'), osc = num('Recommend.Other');
  const sig = makeVotes(num, p);
  const buy = sig.filter(x => x.s === 1).length, sell = sig.filter(x => x.s === -1).length, neu = sig.length - buy - sell;
  const total = sig.reduce((a, x) => a + x.s, 0);
  const score = all != null ? all : (sig.length ? total / sig.length : 0);
  const rec = recOf(score);
  const atrv = num('ATR'), ch = num('change');

  $('out').hidden = false;
  $('title').textContent = `${ticker} — ${v('description') || v('name') || ''}`;
  $('price').textContent = fmtP(p) + (ch != null ? `  (${ch >= 0 ? '+' : ''}${fmt(ch)}%)` : '');
  const el = $('rec'); el.textContent = rec; el.className = 'rec ' + recClass(rec);
  $('score').textContent = `TradingView skoru ${Math.round(score * 100)}` +
    (ma != null && osc != null ? ` (MA ${Math.round(ma * 100)}, Osilatör ${Math.round(osc * 100)})` : '') +
    ` • Tablo: AL ${buy} · SAT ${sell} · NÖTR ${neu} • ${TFNAME[tf]}`;
  const stop = atrv != null && p != null ? p - 2 * atrv : NaN, target = atrv != null && p != null ? p + 3 * atrv : NaN;
  $('stop').textContent = fmtP(stop);
  $('target').textContent = fmtP(target);
  $('atr').textContent = atrv != null ? fmtP(atrv) : 'n/a';
  $('mark').style.left = ((score + 1) / 2 * 100) + '%';

  $('tbody').innerHTML = '';
  sig.forEach(x => {
    const tr = document.createElement('tr');
    [x.name, x.value, x.label, x.note].forEach((t, k) => {
      const td = document.createElement('td'); td.textContent = t;
      if (k === 2) td.className = x.s === 1 ? 'buy' : x.s === -1 ? 'sell' : 'neu';
      tr.appendChild(td);
    });
    $('tbody').appendChild(tr);
  });

  last = { sym: ticker, tf: TFNAME[tf], price: fmtP(p), rec, score: Math.round(score * 100), stop: fmtP(stop), target: fmtP(target),
    signals: sig.map(x => ({ name: x.name, value: x.value, signal: x.label })) };
  $('aiText').textContent = 'Yorum almak için düğmeye basın (ANTHROPIC_API_KEY gerekir).';
  showChart(ticker, tf);
}

async function analyzeTicker(cands) {
  if (busy || !cands.length) return;
  busy = true;
  const tf = $('tf').value;
  let lastErr = '';
  try {
    for (const c of cands) {
      setMsg(`${c.ticker} analiz ediliyor...`);
      let j;
      try { j = await api(`/api/detail?market=${c.market}&ticker=${encodeURIComponent(c.ticker)}&tf=${tf}`); }
      catch (e) { lastErr = e.message; continue; }
      const row = j.tv && j.tv.data && j.tv.data[0];
      if (!row) continue;
      renderDetail(c.ticker, j.columns, row.d, tf);
      setMsg('');
      return;
    }
    setMsg('Sembol bulunamadı' + (lastErr ? ' — ' + lastErr : '. BIST için THYAO, ABD için AAPL, kripto için BTC-USD deneyin.'));
  } finally { busy = false; }
}

// ------------------------------ OLAYLAR ------------------------------
$('f').addEventListener('submit', e => { e.preventDefault(); analyzeTicker(candidates($('sym').value)); });
$('scanBtn').onclick = scan;
QUICK.forEach(s => {
  const b = document.createElement('span'); b.className = 'chip'; b.textContent = s;
  b.onclick = () => { $('sym').value = s; analyzeTicker(candidates(s)); };
  $('chips').appendChild(b);
});

$('aiBtn').onclick = async () => {
  if (!last) return;
  const btn = $('aiBtn'); btn.disabled = true;
  $('aiText').textContent = 'Yorum hazırlanıyor...';
  try {
    const j = await api('/api/ai', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(last) });
    $('aiText').textContent = j.text;
  } catch (e) { $('aiText').textContent = 'Hata: ' + e.message; }
  btn.disabled = false;
};

analyzeTicker(candidates('THYAO'));