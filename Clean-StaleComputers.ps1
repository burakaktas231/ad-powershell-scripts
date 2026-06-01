<#
.SYNOPSIS
    Eski/Kullanılmayan Bilgisayar Hesaplarını Temizleme
.DESCRIPTION
    Belirli süre boyunca domain'e giriş yapmamış bilgisayar hesaplarını
    tespit eder. Rapor, devre dışı bırakma veya silme modlarında çalışır.
    AD'yi temiz tutmak ve lisans yönetimi için kullanılır.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Clean-StaleComputers.ps1                          # Sadece raporla
    .\Clean-StaleComputers.ps1 -Action Disable          # Devre dışı bırak
    .\Clean-StaleComputers.ps1 -Action Disable -Days 90 # 90 gün eşik
#>

param(
    [int]$Days = 60,

    [ValidateSet("Report", "Disable", "Delete")]
    [string]$Action = "Report",

    [string]$ExcludeOU,       # Bu OU'daki bilgisayarları atla
    [switch]$ExportCSV
)

Write-Host "`n=== ESKİ BİLGİSAYAR HESABI TEMİZLİĞİ ===" -ForegroundColor Cyan
Write-Host "Eşik    : $Days gün"
Write-Host "İşlem   : $Action"
Write-Host "Tarih   : $(Get-Date -Format 'dd.MM.yyyy HH:mm')`n"

$CutoffDate = (Get-Date).AddDays(-$Days)

# ============================================
# ESKİ BİLGİSAYARLARI BUL
# ============================================
try {
    $StaleComputers = Get-ADComputer -Filter {
        LastLogonDate -lt $CutoffDate -and Enabled -eq $true
    } -Properties LastLogonDate, OperatingSystem, Description, DistinguishedName |
    Where-Object {
        # Sunucuları hariç tut (yanlışlıkla devre dışı bırakmamak için)
        $_.OperatingSystem -notmatch "Server" -and
        # Belirli OU'yu hariç tut
        ($ExcludeOU -eq $null -or $_.DistinguishedName -notmatch $ExcludeOU)
    } |
    Sort-Object LastLogonDate

    if (-not $StaleComputers) {
        Write-Host "$Days günden eski aktif bilgisayar hesabı bulunamadı." -ForegroundColor Green
        exit
    }

    Write-Host "Bulunan eski bilgisayar: $($StaleComputers.Count)`n" -ForegroundColor Yellow

    # ============================================
    # LİSTELE
    # ============================================
    foreach ($PC in $StaleComputers) {
        $LastLogin = if ($PC.LastLogonDate) { $PC.LastLogonDate.ToString('dd.MM.yyyy') } else { "Hiç" }
        $AgeDays   = if ($PC.LastLogonDate) { ((Get-Date) - $PC.LastLogonDate).Days } else { "N/A" }

        Write-Host ("{0,-20} | {1,-25} | Son Giriş: {2} ({3} gün)" -f `
            $PC.Name, $PC.OperatingSystem, $LastLogin, $AgeDays) -ForegroundColor White
    }

    # ============================================
    # AKSİYON
    # ============================================
    if ($Action -eq "Report") {
        Write-Host "`n[BİLGİ] Sadece rapor modu. İşlem yapılmadı." -ForegroundColor Cyan
        Write-Host "Devre dışı bırakmak için: -Action Disable parametresi ekleyin."
    }
    elseif ($Action -eq "Disable") {
        $Confirm = Read-Host "`n$($StaleComputers.Count) bilgisayar devre dışı bırakılacak. Onaylıyor musunuz? (E/H)"
        if ($Confirm -eq "E") {
            $DisabledCount = 0
            foreach ($PC in $StaleComputers) {
                try {
                    Set-ADComputer -Identity $PC -Enabled $false `
                        -Description "IT: $Days+ gün inaktif - $(Get-Date -Format 'dd.MM.yyyy') devre dışı"
                    $DisabledCount++
                    Write-Host "[OK] $($PC.Name) devre dışı bırakıldı." -ForegroundColor Green
                }
                catch {
                    Write-Host "[HATA] $($PC.Name): $_" -ForegroundColor Red
                }
            }
            Write-Host "`n$DisabledCount bilgisayar devre dışı bırakıldı." -ForegroundColor Cyan
        }
        else {
            Write-Host "İşlem iptal edildi." -ForegroundColor Yellow
        }
    }
    elseif ($Action -eq "Delete") {
        Write-Host "`n[UYARI] Silme işlemi geri alınamaz!" -ForegroundColor Red
        $Confirm = Read-Host "$($StaleComputers.Count) bilgisayar SİLİNECEK. Onaylıyor musunuz? (EVET yazın)"
        if ($Confirm -eq "EVET") {
            foreach ($PC in $StaleComputers) {
                try {
                    Remove-ADComputer -Identity $PC -Confirm:$false
                    Write-Host "[OK] $($PC.Name) silindi." -ForegroundColor Green
                }
                catch {
                    Write-Host "[HATA] $($PC.Name): $_" -ForegroundColor Red
                }
            }
        }
    }

    # ============================================
    # CSV EXPORT
    # ============================================
    if ($ExportCSV) {
        $ReportPath = "$PSScriptRoot\StaleComputers_$(Get-Date -Format 'yyyy-MM-dd').csv"
        $StaleComputers | Select-Object Name, OperatingSystem, LastLogonDate, DistinguishedName |
            Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nRapor kaydedildi: $ReportPath" -ForegroundColor Green
    }
}
catch {
    Write-Host "[HATA] AD sorgusu başarısız: $_" -ForegroundColor Red
}
