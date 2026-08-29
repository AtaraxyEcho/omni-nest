param(
    [string]$Env = "dev",
    [string]$DeviceId
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$envFile = Join-Path $projectRoot "env/$Env.json"

if (-not (Test-Path -LiteralPath $envFile)) {
    Write-Error "Env file not found: $envFile`nCopy env/$Env.example.json to env/$Env.json and edit as needed."
    exit 1
}

Set-Location -LiteralPath $projectRoot

$runArgs = @("run")
if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
    $runArgs += "-d"
    $runArgs += $DeviceId
}
$runArgs += "--dart-define-from-file=$envFile"

& flutter @runArgs
