param(
  [Parameter(Mandatory)][string]$Name,
  [string]$Description = ""
)

$root = Split-Path $PSScriptRoot -Parent
$proj = Join-Path $root "projects"
$tmpl = Join-Path $root "templates\default"

$existing = @(Get-ChildItem $proj -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^PJT\d+" })
$next = $existing.Count + 1
$id   = "PJT{0:D3}" -f $next
$dir  = Join-Path $proj "$id-$Name"

if (Test-Path $dir) {
  Write-Error "Already exists: $dir"; exit 1
}

Copy-Item $tmpl $dir -Recurse -Force

$readme  = Join-Path $dir "README.md"
$content = [System.IO.File]::ReadAllText($readme, [System.Text.Encoding]::UTF8)
$content = $content -replace [regex]::Escape("# プロジェクト名"), "# [$id] $Name"
if ($Description -ne "") {
  $content = $content -replace [regex]::Escape("このプロジェクトの目的・概要を記載する。"), $Description
}
[System.IO.File]::WriteAllText($readme, $content, [System.Text.Encoding]::UTF8)

Write-Host "Created: $dir" -ForegroundColor Green