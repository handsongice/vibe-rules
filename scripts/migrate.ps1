# migrate.ps1 —— 把源项目的沉淀内容迁移到目标项目（Windows PowerShell 版）
#
# 用法：
#   pwsh C:\path\to\vibe-rules\scripts\migrate.ps1 <源项目slug> <目标项目slug>
#
# 例：把 old-app 的沉淀迁移到 new-app
#   pwsh migrate.ps1 old-app new-app

param(
    [Parameter(Mandatory=$true)]
    [string]$SrcSlug,
    [Parameter(Mandatory=$true)]
    [string]$DstSlug
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VibeHome = Resolve-Path (Join-Path $ScriptDir "..")

$SrcDir = Join-Path $VibeHome "projects\$SrcSlug"
$DstDir = Join-Path $VibeHome "projects\$DstSlug"

if (-not (Test-Path $SrcDir)) {
    Write-Host "❌ 源项目不存在：$SrcSlug"
    Write-Host "   可用项目："
    Get-ChildItem (Join-Path $VibeHome "projects") -Directory | ForEach-Object { Write-Host "     $($_.Name)" }
    exit 1
}

New-Item -ItemType Directory -Path $DstDir -Force | Out-Null

Write-Host "📤 源项目：$SrcDir"
Write-Host "📥 目标项目：$DstDir"
Write-Host ""

$copied = 0
$skipped = 0
$overwritten = 0

Get-ChildItem $SrcDir -File -Recurse | ForEach-Object {
    $rel = $_.FullName.Substring($SrcDir.Length + 1)
    $dstFile = Join-Path $DstDir $rel
    $dstParent = Split-Path -Parent $dstFile
    New-Item -ItemType Directory -Path $dstParent -Force | Out-Null

    if (-not (Test-Path $dstFile)) {
        Copy-Item $_.FullName $dstFile
        Write-Host "  ✅ 新增: $rel"
        $copied++
    } else {
        $srcHash = (Get-FileHash $_.FullName -Algorithm MD5).Hash
        $dstHash = (Get-FileHash $dstFile -Algorithm MD5).Hash
        if ($srcHash -eq $dstHash) {
            Write-Host "  ⏭️  相同: $rel（跳过）"
            $skipped++
        } else {
            Write-Host "  ⚠️  冲突: $rel"
            Write-Host "     源文件和目标都存在但内容不同"
            Write-Host "     [o]verwrite 覆盖  [s]kip 跳过  [d]iff 查看差异"
            $choice = Read-Host "     选择 [o/s/d]"
            switch ($choice.ToLower()) {
                "o" {
                    Copy-Item $_.FullName $dstFile
                    Write-Host "     ✅ 已覆盖"
                    $overwritten++
                }
                "d" {
                    Write-Host "     --- diff ---"
                    $srcContent = Get-Content $_.FullName
                    $dstContent = Get-Content $dstFile
                    Compare-Object $srcContent $dstContent | Select-Object -First 30 | ForEach-Object {
                        Write-Host "     $($_.SideIndicator) $($_.InputObject)"
                    }
                    Write-Host "     ---"
                    $confirm = Read-Host "     覆盖吗？[y/N]"
                    if ($confirm -eq "y" -or $confirm -eq "Y") {
                        Copy-Item $_.FullName $dstFile
                        Write-Host "     ✅ 已覆盖"
                        $overwritten++
                    } else {
                        Write-Host "     ⏭️  已跳过"
                        $skipped++
                    }
                }
                default {
                    Write-Host "     ⏭️  已跳过"
                    $skipped++
                }
            }
        }
    }
}

Write-Host ""
Write-Host "🎉 迁移完成。"
Write-Host "   新增: $copied  覆盖: $overwritten  跳过: $skipped"
Write-Host ""
Write-Host "📝 提醒："
Write-Host "   - 项目专属 README.md 里的项目名可能要手动改"
Write-Host "   - 跑 install.ps1 让新项目接入规则库："
Write-Host "     pwsh $VibeHome\scripts\install.ps1 C:\path\to\$DstSlug"
