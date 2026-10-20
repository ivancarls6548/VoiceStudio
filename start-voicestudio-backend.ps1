# Start the VoiceStudio backend headless (CPU, Supertonic-3) on http://127.0.0.1:3900
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File D:\VoiceStudio\start-voicestudio-backend.ps1
# All data, models and caches live on D:. Analytics are hard-disabled.
$ErrorActionPreference = 'Stop'
$repo = 'D:\VoiceStudio'
$data = 'D:\VoiceStudioData'
$logs = Join-Path $data 'logs'
New-Item -ItemType Directory -Force $data, $logs, "$data\hf\hub", "$data\torch" | Out-Null

$existing = Get-NetTCPConnection -LocalPort 3900 -State Listen -ErrorAction SilentlyContinue
if ($existing) { Write-Host "Port 3900 already in use by PID $($existing[0].OwningProcess) - backend probably running."; exit 0 }

$env:OMNIVOICE_DATA_DIR = $data
$env:HF_HOME = "$data\hf"
$env:HF_HUB_CACHE = "$data\hf\hub"
$env:TORCH_HOME = "$data\torch"
$env:AUDIOSEAL_CACHE_DIR = "$data\cache"   # AudioSeal watermark checkpoint (MIT, ~56 MB)
$env:UV_CACHE_DIR = 'D:\uv-cache'
$env:UV_PYTHON_INSTALL_DIR = 'D:\uv-python'
$env:OMNIVOICE_ANALYTICS_DISABLED = '1'
$env:OMNIVOICE_DEVICE = 'cpu'
$env:OMNIVOICE_TTS_BACKEND = 'supertonic3'
$env:OMNIVOICE_PRELOAD_CAPTURE_ASR = '0'
$env:OMNIVOICE_PORT = '3900'
$env:PATH = 'C:\ffmpeg\bin;' + $env:PATH

$py = Join-Path $repo '.venv\Scripts\python.exe'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$p = Start-Process -FilePath $py -WorkingDirectory $repo -WindowStyle Hidden -PassThru `
    -ArgumentList '-m','uvicorn','main:app','--app-dir','backend','--host','127.0.0.1','--port','3900' `
    -RedirectStandardOutput (Join-Path $logs "backend-$stamp.out.log") `
    -RedirectStandardError (Join-Path $logs "backend-$stamp.err.log")
Set-Content -Path (Join-Path $data 'backend.pid') -Value $p.Id -Encoding ascii
Write-Host "Started VoiceStudio backend PID $($p.Id); logs in $logs"

# Wait for /health = 200 (heavy init continues after the port opens)
$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 'http://127.0.0.1:3900/health'
        if ($r.StatusCode -eq 200) { Write-Host "HEALTH OK: $($r.Content)"; exit 0 }
    } catch { }
    Start-Sleep -Seconds 3
}
Write-Host 'Backend did not report healthy within 5 minutes; check the logs.'
exit 1
