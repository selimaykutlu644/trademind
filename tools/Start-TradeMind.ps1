param([int]$Port = 5050)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PORT = [string]$Port
$env:HOST = '127.0.0.1'
& node server/local.cjs
if ($LASTEXITCODE -ne 0) { throw 'TradeMind baslatilamadi. Eski server.ps1 aciksa Ctrl+C ile durdurun.' }
