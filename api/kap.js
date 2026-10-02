'use strict';
const KapApi = require('../server/kap.cjs');
const kap = new KapApi();

module.exports = async (req, res) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  
  try {
    const query = new URL(req.url, 'http://localhost').searchParams;
    const ticker = query.get('ticker');
    
    if (!ticker) {
      res.statusCode = 400;
      return res.end(JSON.stringify({ error: 'Ticker parameter required' }));
    }
    
    // Only process Turkish stocks
    if (!ticker.startsWith('BIST:')) {
      res.statusCode = 400;
      return res.end(JSON.stringify({ error: 'KAP integration only for BIST stocks' }));
    }
    
    let data;
    try {
      data = await kap.fetchFinancialReports(ticker);
    } catch (kapError) {
      // Fallback to Yahoo Finance
      try {
        data = await kap.fetchFromYahooFinance(ticker);
      } catch (yahooError) {
        res.statusCode = 502;
        return res.end(JSON.stringify({ error: `KAP: ${kapError.message}, Yahoo Finance: ${yahooError.message}` }));
      }
    }
    
    res.statusCode = 200;
    res.end(JSON.stringify(data));
  } catch (error) {
    res.statusCode = 500;
    res.end(JSON.stringify({ error: error.message || 'KAP service error' }));
  }
};