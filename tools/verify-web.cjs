const fs=require('node:fs');
for(const file of ['build/web/index.html','build/web/flutter_bootstrap.js','build/web/main.dart.js']) {
  if(!fs.existsSync(file))throw new Error('Önce flutter build web --release çalıştırın. Eksik: '+file);
}
console.log('Flutter web dosyaları hazır.');
