<#
.SYNOPSIS
  未処理の案件をまとめて自動処理する。Windows タスクスケジューラから定期実行する用。

.EXAMPLE
  .\run-auto.ps1
  .\run-auto.ps1 -Limit 5 -NoQa

.NOTES
  タスクスケジューラへの登録（毎日 6:00 に実行する例。PowerShell を管理者で開いて実行）:

    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
               -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PWD\run-auto.ps1`""
    $trigger = New-ScheduledTaskTrigger -Daily -At 6:00
    Register-ScheduledTask -TaskName "AI副業-自動処理" -Action $action -Trigger $trigger
#>
param(
  [int]$Limit = 0,
  [switch]$NoQa,
  [switch]$NoRevenue,
  [switch]$Retry
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# ログは logs/ に日別で残す（.gitignore 済み）
$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$log = Join-Path $logDir ("auto-{0:yyyy-MM-dd}.log" -f (Get-Date))

# 仮想環境があれば使う
$python = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) { $python = "python" }

$args = @("main.py", "auto")
if ($Limit -gt 0)  { $args += @("--limit", $Limit) }
if ($NoQa)         { $args += "--no-qa" }
if ($NoRevenue)    { $args += "--no-revenue" }
if ($Retry)        { $args += "--retry" }

"=== {0:yyyy-MM-dd HH:mm:ss} 自動処理開始 ===" -f (Get-Date) | Tee-Object -FilePath $log -Append

try {
  & $python @args 2>&1 | Tee-Object -FilePath $log -Append
  $code = $LASTEXITCODE
}
catch {
  $_.Exception.Message | Tee-Object -FilePath $log -Append
  $code = 1
}

"=== 終了 (exit={0}) ===`n" -f $code | Tee-Object -FilePath $log -Append
exit $code
