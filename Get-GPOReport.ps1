<#
.SYNOPSIS
    Group Policy (GPO) Raporu ve Yedekleme
.DESCRIPTION
    Tüm GPO'ları listeler, linklerini gösterir, HTML rapor üretir
    ve tüm GPO'ları dışa aktararak yedekler.
    Periyodik denetim ve DR (Disaster Recovery) için kullanılır.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Get-GPOReport.ps1
    .\Get-GPOReport.ps1 -Backup
    .\Get-GPOReport.ps1 -Backup -BackupPath "D:\GPO-Backup"
#>

param(
    [switch]$Backup,
    [string]$BackupPath = "$PSScriptRoot\GPO-Backup_$(Get-Date -Format 'yyyy-MM-dd')",
    [switch]$HTMLReport
)

Import-Module GroupPolicy -ErrorAction Stop

Write-Host "`n=== GROUP POLICY (GPO) RAPORU ===" -ForegroundColor Cyan
Write-Host "Tarih: $(Get-Date -Format 'dd.MM.yyyy HH:mm')`n"

# ============================================
# 1) TÜM GPO'LARI LİSTELE
# ============================================
$GPOs = Get-GPO -All | Sort-Object DisplayName

Write-Host "--- Tüm GPO'lar ---`n" -ForegroundColor Cyan

foreach ($GPO in $GPOs) {
    # GPO link bilgisi
    [xml]$GPOReport = Get-GPOReport -Guid $GPO.Id -ReportType XML
    $Links = $GPOReport.GPO.LinksTo

    $LinkStatus = if ($Links) {
        ($Links | ForEach-Object { $_.SOMPath }) -join ", "
    } else { "Bağlı değil" }

    $Color = if (-not $Links) { "DarkGray" }
             elseif ($GPO.GpoStatus -ne "AllSettingsEnabled") { "Yellow" }
             else { "White" }

    Write-Host "$($GPO.DisplayName)" -ForegroundColor $Color
    Write-Host ("  Durum        : {0}" -f $GPO.GpoStatus)
    Write-Host ("  Oluşturulma  : {0}" -f $GPO.CreationTime.ToString('dd.MM.yyyy'))
    Write-Host ("  Son Değişiklik: {0}" -f $GPO.ModificationTime.ToString('dd.MM.yyyy'))
    Write-Host ("  Bağlı Olduğu : {0}" -f $LinkStatus)
    Write-Host ""
}

# ============================================
# 2) BAĞLANTIKSIZ GPO'LAR (temizlik adayı)
# ============================================
$UnlinkedGPOs = @()

foreach ($GPO in $GPOs) {
    [xml]$Report = Get-GPOReport -Guid $GPO.Id -ReportType XML
    if (-not $Report.GPO.LinksTo) {
        $UnlinkedGPOs += $GPO.DisplayName
    }
}

if ($UnlinkedGPOs.Count -gt 0) {
    Write-Host "--- Bağlantısız GPO'lar (temizlik adayı) ---" -ForegroundColor Yellow
    $UnlinkedGPOs | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "Toplam: $($UnlinkedGPOs.Count) bağlantısız GPO`n"
}

# ============================================
# 3) İSTATİSTİKLER
# ============================================
$EnabledCount   = ($GPOs | Where-Object { $_.GpoStatus -eq "AllSettingsEnabled" }).Count
$DisabledCount  = ($GPOs | Where-Object { $_.GpoStatus -ne "AllSettingsEnabled" }).Count

Write-Host "--- Özet ---" -ForegroundColor Cyan
Write-Host "Toplam GPO       : $($GPOs.Count)"
Write-Host "Aktif            : $EnabledCount" -ForegroundColor Green
Write-Host "Devre Dışı/Kısmi : $DisabledCount" -ForegroundColor Yellow
Write-Host "Bağlantısız      : $($UnlinkedGPOs.Count)" -ForegroundColor DarkGray

# ============================================
# 4) HTML RAPOR
# ============================================
if ($HTMLReport) {
    $HTMLPath = "$PSScriptRoot\GPO-Rapor_$(Get-Date -Format 'yyyy-MM-dd').html"
    Get-GPOReport -All -ReportType HTML -Path $HTMLPath
    Write-Host "`n[OK] HTML rapor oluşturuldu: $HTMLPath" -ForegroundColor Green
}

# ============================================
# 5) GPO YEDEKLEME
# ============================================
if ($Backup) {
    Write-Host "`n--- GPO Yedekleme ---" -ForegroundColor Cyan

    if (-not (Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    }

    $BackupCount = 0
    foreach ($GPO in $GPOs) {
        try {
            Backup-GPO -Guid $GPO.Id -Path $BackupPath -ErrorAction Stop | Out-Null
            $BackupCount++
            Write-Host "[OK] $($GPO.DisplayName)" -ForegroundColor Green
        }
        catch {
            Write-Host "[HATA] $($GPO.DisplayName): $_" -ForegroundColor Red
        }
    }

    Write-Host "`n$BackupCount GPO yedeklendi: $BackupPath" -ForegroundColor Green
}
