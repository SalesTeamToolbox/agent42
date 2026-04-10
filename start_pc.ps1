$ErrorActionPreference = "Continue"
$env:Path = "C:\Users\rickw\AppData\Roaming\npm;$env:Path"
$proc = Start-Process -FilePath "node" -ArgumentList "node_modules/pnpm/bin/pnpm.cjs", "dev" -WorkingDirectory "C:\Users\rickw\projects\paperclip" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 12
if ($proc -and -not $proc.HasExited) {
    Write-Host "Paperclip running, PID: $($proc.Id)"
} else {
    Write-Host "Paperclip exited with code: $($proc.ExitCode)"
}