param([switch]$Production)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
foreach ($Tool in @('flutter','node','vercel')) {
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) { throw "$Tool bulunamadi. Vercel icin npm install -g vercel; sonra vercel login." }
}
if (-not (Test-Path -LiteralPath "$Root\.vercel\project.json")) { throw 'Mevcut Vercel proje baglantisi bulunamadi. Dogru proje kokunde vercel link calistirin.' }
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Flutter bagimliliklari alinamadi.' }
& flutter analyze --no-fatal-infos --no-fatal-warnings
if ($LASTEXITCODE -ne 0) { throw 'Flutter analiz hatasi; yayin durduruldu.' }
& flutter test test/widget_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Flutter testleri gecmedi; yayin durduruldu.' }
& node --test tests/backend.test.cjs
if ($LASTEXITCODE -ne 0) { throw 'Backend testleri gecmedi; yayin durduruldu.' }
& flutter build web --release
if ($LASTEXITCODE -ne 0) { throw 'Flutter web derlenemedi; yayin durduruldu.' }
$Stage = Join-Path ([IO.Path]::GetTempPath()) ('TradeMind_Deploy_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Stage | Out-Null
Copy-Item -LiteralPath "$Root\build\web" -Destination "$Stage\public" -Recurse
Copy-Item -LiteralPath "$Root\api" -Destination "$Stage\api" -Recurse
Copy-Item -LiteralPath "$Root\server" -Destination "$Stage\server" -Recurse
New-Item -ItemType Directory -Path "$Stage\.vercel" | Out-Null
Copy-Item -LiteralPath "$Root\.vercel\project.json" -Destination "$Stage\.vercel\project.json"
Copy-Item -LiteralPath "$Root\tools\node-package.json" -Destination "$Stage\package.json"
$Config = Get-Content -LiteralPath "$Root\vercel.json" -Raw | ConvertFrom-Json
$Config.outputDirectory = 'public'
$Config.buildCommand = 'node -e "console.log(''Flutter already built'')"'
$Utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText("$Stage\vercel.json", ($Config | ConvertTo-Json -Depth 10), $Utf8)
Write-Host "Yayin dizini: $Stage" -ForegroundColor Cyan
Write-Host 'Vercel baglantisi icin mevcut hesabin proje kapsaminda yetkili olmasi gerekir.'
Push-Location -LiteralPath $Stage
try {
    if ($Production) { & vercel deploy --prod } else { & vercel deploy }
    if ($LASTEXITCODE -ne 0) { throw 'Vercel yayini basarisiz. Proje yetkisini ve loglari kontrol edin.' }
} finally { Pop-Location }
Write-Host 'Olusan URL uzerinde /api/health ve sembol taramasini kontrol edin.' -ForegroundColor Green
