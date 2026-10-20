# Stop the headless VoiceStudio backend (and its Supertonic sidecar) listening on port 3900.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File D:\VoiceStudio\stop-voicestudio-backend.ps1
$conn = Get-NetTCPConnection -LocalPort 3900 -State Listen -ErrorAction SilentlyContinue
$pids = @()
if ($conn) { $pids += $conn.OwningProcess }
$pidFile = 'D:\VoiceStudioData\backend.pid'
if (Test-Path $pidFile) { $pids += [int](Get-Content $pidFile) }
$pids = $pids | Sort-Object -Unique
if (-not $pids) { Write-Host 'VoiceStudio backend is not running.'; exit 0 }
foreach ($id in $pids) {
    if (Get-Process -Id $id -ErrorAction SilentlyContinue) {
        & taskkill.exe /PID $id /T /F | Out-Null
        Write-Host "Stopped process tree $id"
    }
}
Remove-Item $pidFile -ErrorAction SilentlyContinue
