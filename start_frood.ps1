$ErrorActionPreference = "Continue"
$proc = Start-Process python -ArgumentList "frood.py" -WorkingDirectory "C:\Users\rickw\projects\frood" -PassThru -RedirectStandardOutput "C:\Users\rickw\projects\frood\frood_out.txt" -RedirectStandardError "C:\Users\rickw\projects\frood\frood_err.txt"
Start-Sleep -Seconds 10
if ($proc -and -not $proc.HasExited) {
    Write-Host "Frood running, PID: $($proc.Id)"
} else {
    Write-Host "Frood exited with code: $($proc.ExitCode)"
}
if (Test-Path "C:\Users\rickw\projects\frood\frood_err.txt") {
    Write-Host "=== STDERR ==="
    Get-Content "C:\Users\rickw\projects\frood\frood_err.txt" | Select-Object -First 20
}