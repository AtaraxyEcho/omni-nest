param(
    [string]$Env = "dev",
    [string]$WebPort = "3000"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$envFile = Join-Path $projectRoot "env/$Env.json"

if (-not (Test-Path -LiteralPath $envFile)) {
    Write-Error "Env file not found: $envFile`nCopy env/$Env.example.json to env/$Env.json and edit as needed."
    exit 1
}

Set-Location -LiteralPath $projectRoot
flutter run -d chrome --web-port $WebPort --dart-define-from-file=$envFile
