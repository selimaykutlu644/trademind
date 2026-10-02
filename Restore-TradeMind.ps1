param([Parameter(Mandatory=$true)][string]$BackupPath)
$ErrorActionPreference = 'Stop'
$BackupPath = [IO.Path]::GetFullPath($BackupPath)
$State = Get-Content -LiteralPath "$BackupPath\state.json" -Raw | ConvertFrom-Json
$Root = [IO.Path]::GetFullPath($State.projectRoot).TrimEnd('\')
if (-not (Test-Path -LiteralPath "$Root\pubspec.yaml")) { throw 'Yedegin proje kokune ulasilamiyor.' }
foreach ($Item in $State.files) {
    $Target = [IO.Path]::GetFullPath((Join-Path $Root $Item.path))
    if (-not $Target.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Gecersiz yedek yolu.' }
    if ($Item.existed) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path "$BackupPath\files" $Item.path) -Destination $Target -Force
    } elseif (Test-Path -LiteralPath $Target -PathType Leaf) { Remove-Item -LiteralPath $Target -Force }
}
if (Test-Path -LiteralPath "$Root\build\web") { Remove-Item -LiteralPath "$Root\build\web" -Recurse -Force }
if ($State.hadWeb) { Copy-Item -LiteralPath "$BackupPath\web" -Destination "$Root\build\web" -Recurse }
Write-Host "Kaynak dosyalar geri yuklendi: $Root" -ForegroundColor Green
Write-Host 'Flutter paket kaydini yenilemek icin proje klasorunde flutter pub get calistir.'
