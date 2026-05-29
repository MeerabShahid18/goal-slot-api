$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$PSNativeCommandUseErrorActionPreference = $false

$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
$env:DATABASE_URL = 'postgresql://stub:stub@localhost:5432/stub'

Set-Location C:\app\goal-slot-api

Write-Host '=== git pull ==='
cmd /c 'git fetch --all 2>&1'
cmd /c 'git reset --hard origin/main 2>&1'

Write-Host '=== npm install ==='
cmd /c 'npm install --no-audit --no-fund --omit=optional 2>&1' | Select-Object -Last 20

Write-Host '=== prisma generate ==='
cmd /c 'npx prisma generate 2>&1' | Select-Object -Last 10

Write-Host '=== prisma migrate deploy ==='
cmd /c 'npx prisma migrate deploy 2>&1' | Select-Object -Last 20

Write-Host '=== nest build ==='
cmd /c 'npx nest build 2>&1' | Select-Object -Last 30

if (-not (Test-Path C:\app\goal-slot-api\dist\src\main.js)) {
    throw 'BUILD FAILED: dist/src/main.js missing'
}

Write-Host '=== restart service ==='
nssm restart goal-slot-api
Start-Sleep -Seconds 8

Write-Host '=== health probe ==='
$ok = $false
for ($i = 1; $i -le 12; $i++) {
    try {
        $r = Invoke-WebRequest -Uri 'http://localhost:4000/api/health' -UseBasicParsing -TimeoutSec 4
        if ($r.StatusCode -eq 200) {
            Write-Host "OK: $($r.Content)"
            $ok = $true
            break
        }
    } catch {
        Write-Host "attempt $i : $($_.Exception.Message)"
        Start-Sleep -Seconds 3
    }
}

if (-not $ok) {
    Get-Content C:\app\goal-slot-api\logs\stderr.log -Tail 30
    throw 'HEALTH PROBE FAILED'
}

Write-Host 'DEPLOY_OK'
