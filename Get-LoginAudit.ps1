<#
.SYNOPSIS
    Giriş (Logon) Denetim Raporu
.DESCRIPTION
    Domain Controller'lardan başarılı ve başarısız giriş denemelerini çeker.
    Brute-force tespiti ve güvenlik denetimi için kullanılır.
    Event ID 4624 (başarılı), 4625 (başarısız) loglarını analiz eder.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Get-LoginAudit.ps1
    .\Get-LoginAudit.ps1 -Hours 48 -FailedOnly
#>

param(
    [int]$Hours = 24,          # Son kaç saatlik loglar
    [switch]$FailedOnly,       # Sadece başarısız girişleri göster
    [string]$TargetUser,       # Belirli bir kullanıcıyı filtrele
    [int]$FailThreshold = 5   # Bu sayıdan fazla başarısız giriş varsa uyarı
)

$StartTime = (Get-Date).AddHours(-$Hours)
$DC = (Get-ADDomain).PDCEmulator

Write-Host "`n=== GİRİŞ DENETİM RAPORU ===" -ForegroundColor Cyan
Write-Host "DC       : $DC"
Write-Host "Aralık   : Son $Hours saat"
Write-Host "Başlangıç: $($StartTime.ToString('dd.MM.yyyy HH:mm'))`n"

# ============================================
# BAŞARISIZ GİRİŞLER (Event ID 4625)
# ============================================
Write-Host "=== BAŞARISIZ GİRİŞ DENEMELERİ ===" -ForegroundColor Red

try {
    $FailedEvents = Get-WinEvent -ComputerName $DC -FilterHashtable @{
        LogName   = 'Security'
        Id        = 4625
        StartTime = $StartTime
    } -ErrorAction SilentlyContinue

    if ($FailedEvents) {
        $FailedLogins = $FailedEvents | ForEach-Object {
            [PSCustomObject]@{
                Zaman      = $_.TimeCreated
                Kullanici  = $_.Properties[5].Value
                Kaynak_IP  = $_.Properties[19].Value
                Kaynak_PC  = $_.Properties[13].Value
                Neden      = switch ($_.Properties[8].Value) {
                    '0xC0000064' { "Kullanıcı bulunamadı" }
                    '0xC000006A' { "Yanlış şifre" }
                    '0xC0000234' { "Hesap kilitli" }
                    '0xC0000072' { "Hesap devre dışı" }
                    '0xC000006F' { "Saat kısıtlaması" }
                    '0xC0000070' { "İstasyon kısıtlaması" }
                    '0xC0000193' { "Hesap süresi dolmuş" }
                    default      { $_.Properties[8].Value }
                }
            }
        }

        if ($TargetUser) {
            $FailedLogins = $FailedLogins | Where-Object { $_.Kullanici -eq $TargetUser }
        }

        # Kullanıcıya göre grupla ve say
        $FailedSummary = $FailedLogins | Group-Object Kullanici | Sort-Object Count -Descending

        foreach ($Entry in $FailedSummary) {
            $Color = if ($Entry.Count -ge $FailThreshold) { "Red" } else { "Yellow" }
            $Flag  = if ($Entry.Count -ge $FailThreshold) { " [!!! BRUTE-FORCE?]" } else { "" }
            Write-Host ("{0,-25} : {1} başarısız deneme{2}" -f $Entry.Name, $Entry.Count, $Flag) -ForegroundColor $Color
        }

        Write-Host "`nToplam başarısız deneme: $($FailedLogins.Count)" -ForegroundColor Yellow

        # En çok hatalı giriş yapan IP'ler
        Write-Host "`nEn çok hata yapan IP adresleri:" -ForegroundColor Yellow
        $FailedLogins | Group-Object Kaynak_IP | Sort-Object Count -Descending |
            Select-Object -First 5 | ForEach-Object {
                Write-Host ("  {0,-20} : {1} deneme" -f $_.Name, $_.Count)
            }
    }
    else {
        Write-Host "Son $Hours saatte başarısız giriş yok." -ForegroundColor Green
    }
}
catch {
    Write-Host "[HATA] Log okunamadı: $_" -ForegroundColor Red
}

# ============================================
# BAŞARILI GİRİŞLER (Event ID 4624)
# ============================================
if (-not $FailedOnly) {
    Write-Host "`n=== BAŞARILI GİRİŞLER ===" -ForegroundColor Green

    try {
        $SuccessEvents = Get-WinEvent -ComputerName $DC -FilterHashtable @{
            LogName   = 'Security'
            Id        = 4624
            StartTime = $StartTime
        } -MaxEvents 500 -ErrorAction SilentlyContinue |
        Where-Object {
            # Sistem hesaplarını filtrele
            $_.Properties[5].Value -notmatch '^(SYSTEM|LOCAL SERVICE|NETWORK SERVICE|DWM-|UMFD-)' -and
            $_.Properties[5].Value -notmatch '\$$'   # Bilgisayar hesaplarını çıkar
        }

        if ($SuccessEvents) {
            $SuccessLogins = $SuccessEvents | ForEach-Object {
                [PSCustomObject]@{
                    Zaman     = $_.TimeCreated
                    Kullanici = $_.Properties[5].Value
                    Kaynak_IP = $_.Properties[18].Value
                    Tipi      = switch ($_.Properties[8].Value) {
                        2  { "Etkileşimli (Konsol)" }
                        3  { "Ağ (Network)" }
                        7  { "Kilit Açma (Unlock)" }
                        10 { "Uzak Masaüstü (RDP)" }
                        default { "Diğer ($($_.Properties[8].Value))" }
                    }
                }
            }

            if ($TargetUser) {
                $SuccessLogins = $SuccessLogins | Where-Object { $_.Kullanici -eq $TargetUser }
            }

            $SuccessLogins | Group-Object Kullanici | Sort-Object Count -Descending |
                Select-Object -First 15 | ForEach-Object {
                    Write-Host ("{0,-25} : {1} giriş" -f $_.Name, $_.Count) -ForegroundColor White
                }

            Write-Host "`nToplam başarılı giriş: $($SuccessLogins.Count)"
        }
    }
    catch {
        Write-Host "[HATA] Başarılı giriş logları okunamadı: $_" -ForegroundColor Red
    }
}
