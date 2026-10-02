'use strict';
const {calculate}=require('./scoring.cjs');
const {detail,validate}=require('./core.cjs');
const provider=require('./provider.cjs');
async function readBody(req) {
  if(req.body != null) {
    const text=typeof req.body==='string'?req.body:JSON.stringify(req.body);
    if(Buffer.byteLength(text)>500000) { const e=new Error('Veri seti çok büyük.'); e.status=413; throw e; }
    return typeof req.body==='string'?JSON.parse(req.body):req.body;
  }
  const chunks=[];let size=0;
  for await(const chunk of req) { size+=chunk.length; if(size>500000) {const e=new Error('Veri seti çok büyük.');e.status=413;throw e;} chunks.push(chunk); }
  try {return JSON.parse(Buffer.concat(chunks).toString());}catch {const e=new Error('Geçersiz veri biçimi.');e.status=400;throw e;}
}
function handler(route) {return async(req,res)=>{
  res.setHeader('Content-Type','application/json; charset=utf-8');res.setHeader('Cache-Control','no-store');
  try {
    const q=new URL(req.url,'http://localhost').searchParams;
    let result;
    if(route==='/api/dataset'&&req.method==='GET') result=await provider.dataset(q.get('ticker'));
    else if(route==='/api/score'&&req.method==='POST') {
      const body=await readBody(req);
      const query=new URLSearchParams({market:body.market||'turkey',ticker:body.ticker||'',tf:body.tf||'1D'});
      validate(query,true);
      let indicators={},source=null,warning=null;
      try {const data=await detail(query); indicators=Object.fromEntries(data.columns.map((name,i)=>[name.split('|')[0],data.tv.data[0].d[i]]));source={name:'TradingView',fetchedAt:data.fetchedAt,interval:body.tf||'1D'};}
      catch(e){warning='Güncel teknik veriler alınamadı: '+e.message;}
      result=calculate({ticker:body.ticker,weights:body.weights,dataset:body.dataset,indicators,currentPrice:indicators.close,technicalSource:source});
      if(warning)result.warnings.push(warning);
    } else {const e=new Error('Yöntem desteklenmiyor.');e.status=405;throw e;}
    res.statusCode=200;res.end(JSON.stringify(result));
  }catch(e){res.statusCode=e.status||500;res.end(JSON.stringify({error:e.status?e.message:'Analiz servisi hatası.'}));}
};}
module.exports={handler,readBody};
