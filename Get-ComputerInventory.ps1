<#
.SYNOPSIS
    Domain bilgisayar envanteri
.DESCRIPTION
    AD'deki tüm bilgisayarları listeler: işletim sistemi, son giriş,
    IP adresi, OU konumu. Envanter takibi ve lisans denetimi için kullanılır.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Get-ComputerInventory.ps1
    .\Get-ComputerInventory.ps1 -ExportCSV
#>

param(
    [switch]$ExportCSV,
    [int]$StaleDays = 60    # Bu kadar gündür görülmeyen bilgisayarları işaretle
)

Write-Host "`n=== DOMAIN BİLGİSAYAR ENVANTERİ ===" -ForegroundColor Cyan
Write-Host "Tarih: $(Get-Date -Format 'dd.MM.yyyy HH:mm')`n"

$CutoffDate = (Get-Date).AddDays(-$StaleDays)

# ============================================
# TÜM BİLGİSAYARLARI ÇEK
# ============================================
try {
    $Computers = Get-ADComputer -Filter * -Properties `
        Name, OperatingSystem, OperatingSystemVersion, `
        LastLogonDate, IPv4Address, Created, DistinguishedName, Enabled |
    Select-Object `
        Name,
        OperatingSystem,
        OperatingSystemVersion,
        @{Name="Son_Giris"; Expression={ $_.LastLogonDate }},
        IPv4Address,
        @{Name="OU"; Expression={
            ($_.DistinguishedName -split ',', 2)[1]
        }},
        Enabled,
        @{Name="Eski_mi"; Expression={
            if ($_.LastLogonDate -and $_.LastLogonDate -lt $CutoffDate) { "EVET" } else { "Hayır" }
        }},
        Created |
    Sort-Object OperatingSystem, Name

    # ============================================
    # EKRANA YAZDIR
    # ============================================
    $Computers | Format-Table Name, OperatingSystem, IPv4Address, Son_Giris, Eski_mi -AutoSize

    # ============================================
    # İSTATİSTİKLER
    # ============================================
    Write-Host "--- İstatistikler ---" -ForegroundColor Cyan

    # İşletim sistemine göre dağılım
    Write-Host "`nİşletim Sistemi Dağılımı:"
    $Computers | Group-Object OperatingSystem | Sort-Object Count -Descending |
        ForEach-Object {
            Write-Host ("  {0,-40} : {1}" -f $_.Name, $_.Count)
        }

    $TotalCount  = $Computers.Count
    $ActiveCount = ($Computers | Where-Object { $_.Eski_mi -eq "Hayır" -and $_.Enabled }).Count
    $StaleCount  = ($Computers | Where-Object { $_.Eski_mi -eq "EVET" }).Count
    $DisabledCount = ($Computers | Where-Object { -not $_.Enabled }).Count

    Write-Host "`nToplam Bilgisayar : $TotalCount"
    Write-Host "Aktif             : $ActiveCount" -ForegroundColor Green
    Write-Host "Eski ($StaleDays+ gün)    : $StaleCount" -ForegroundColor Yellow
    Write-Host "Devre Dışı        : $DisabledCount" -ForegroundColor DarkGray

    # ============================================
    # CSV EXPORT
    # ============================================
    if ($ExportCSV) {
        $ReportPath = "$PSScriptRoot\Envanter_$(Get-Date -Format 'yyyy-MM-dd').csv"
        $Computers | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nRapor kaydedildi: $ReportPath" -ForegroundColor Green
    }
}
catch {
    Write-Host "[HATA] AD sorgusu başarısız: $_" -ForegroundColor Red
}
