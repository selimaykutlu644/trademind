'use strict';
const suffix = { '1D': '', '1W': '|1W', '1M': '|1M', '4H': '|240', '1H': '|60' };
const markets = new Set(['turkey', 'crypto', 'america']);
const cache = new Map();
class ApiError extends Error { constructor(status, message) { super(message); this.status = status; } }
function validate(query, detail = false) {
  const market = query.get('market') || 'turkey';
  const tf = query.get('tf') || '1D';
  if (!markets.has(market) || !Object.hasOwn(suffix, tf)) throw new ApiError(400, 'Piyasa veya zaman aralığı geçersiz.');
  const ticker = (query.get('ticker') || '').toUpperCase();
  if (detail && !/^[A-Z0-9_.!\-]{1,20}:[A-Z0-9_.!\-]{1,30}$/.test(ticker)) throw new ApiError(400, 'Sembol geçersiz.');
  const order = query.get('order') || 'desc';
  if (!['asc', 'desc'].includes(order)) throw new ApiError(400, 'Sıralama geçersiz.');
  return { market, tf, ticker, order, sfx: suffix[tf] };
}
async function tvRequest(market, columns, options = {}, fetcher = fetch) {
  const body = { filter: options.filter || [], options: { lang: 'en' }, markets: [market],
    symbols: { query: { types: [] }, tickers: options.ticker ? [options.ticker] : [] }, columns,
    sort: { sortBy: options.sort || 'name', sortOrder: options.order || 'asc' }, range: [0, options.count || 1] };
  let response;
  try {
    response = await fetcher(`https://scanner.tradingview.com/${market}/scan`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'User-Agent': 'TradeMind/2.0', Accept: 'application/json' },
      body: JSON.stringify(body), signal: AbortSignal.timeout(12000),
    });
  } catch { throw new ApiError(502, 'Veri sağlayıcısına ulaşılamadı. Biraz sonra yeniden deneyin.'); }
  if (!response.ok) throw new ApiError(502, `Veri sağlayıcısı isteği kabul etmedi (HTTP ${response.status}).`);
  let result;
  try { result = await response.json(); } catch { throw new ApiError(502, 'Veri sağlayıcısından okunamayan yanıt geldi.'); }
  if (!Array.isArray(result.data)) throw new ApiError(502, 'Veri sağlayıcısının yanıt biçimi değişmiş.');
  return { ...result, fetchedAt: new Date().toISOString(), source: 'TradingView', delayedPossible: true };
}
async function scan(query, fetcher) {
  const { market, sfx, order } = validate(query);
  const columns = ['name', 'description', 'close', 'change', 'Perf.W', `Recommend.All${sfx}`, `Recommend.MA${sfx}`, `Recommend.Other${sfx}`, `RSI${sfx}`, `ADX${sfx}`, 'volume'];
  const filter = market === 'crypto' ? [{ left: 'exchange', operation: 'equal', right: 'BINANCE' }] : [{ left: 'type', operation: 'equal', right: 'stock' }];
  if (market === 'america') filter.push({ left: 'market_cap_basic', operation: 'greater', right: 2000000000 });
  return tvRequest(market, columns, { filter, sort: `Recommend.All${sfx}`, order, count: market === 'crypto' ? 1500 : market === 'turkey' ? 900 : 1200 }, fetcher);
}
async function detail(query, fetcher) {
  const { market, sfx, ticker } = validate(query, true);
  const plain = new Set(['name', 'description', 'change', 'volume']);
  const full = ['name','description','close','change','volume','ATR','RSI','Stoch.K','Stoch.D','CCI20','ADX','ADX+DI','ADX-DI','AO','Mom','MACD.macd','MACD.signal','Stoch.RSI.K','W.R','BBPower','UO','EMA10','EMA20','EMA30','EMA50','EMA100','EMA200','SMA10','SMA20','SMA30','SMA50','SMA100','SMA200','Ichimoku.BLine','VWMA','HullMA9','Recommend.All','Recommend.MA','Recommend.Other'];
  const minimal = ['name','description','close','change','volume','RSI','Recommend.All','Recommend.MA','Recommend.Other'];
  for (const names of [full, minimal]) {
    const columns = names.map(n => plain.has(n) ? n : n + sfx);
    try {
      const tv = await tvRequest(market, columns, { ticker }, fetcher);
      if (!tv.data.length) throw new ApiError(404, 'Bu piyasada sembol bulunamadı.');
      return { columns, tv, fetchedAt: tv.fetchedAt, limited: names === minimal };
    } catch (error) { if (error.status === 404 || names === minimal) throw error; }
  }
}
async function handle(path, method, query, fetcher = fetch) {
  if (!['/api/health', '/api/scan', '/api/detail'].includes(path)) throw new ApiError(404, 'API yolu bulunamadı.');
  if (method !== 'GET') throw new ApiError(405, 'Yalnızca GET destekleniyor.');
  if (path === '/api/health') return { ok: true, service: 'TradeMind API', version: '2.0.0', providerVerified: false };
  validate(query, path === '/api/detail');
  const key = path + '?' + query.toString();
  const hit = cache.get(key);
  if (hit && Date.now() < hit.expires) return { ...hit.value, cached: true };
  const value = await (path === '/api/scan' ? scan(query, fetcher) : detail(query, fetcher));
  if (cache.size > 200) cache.clear();
  cache.set(key, { value, expires: Date.now() + (path === '/api/scan' ? 60000 : 30000) });
  return { ...value, cached: false };
}
function handler(path) {
  return async (req, res) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    try {
      const query = new URL(req.url, 'http://localhost').searchParams;
      res.statusCode = 200; res.end(JSON.stringify(await handle(path, req.method, query)));
    } catch (error) { res.statusCode = error.status || 500; res.end(JSON.stringify({ error: error.status ? error.message : 'Sunucu hatası.' })); }
  };
}
module.exports = { validate, scan, detail, handle, handler, ApiError, cache };
