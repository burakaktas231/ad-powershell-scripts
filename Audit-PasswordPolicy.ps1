<#
.SYNOPSIS
    Şifre Politikası ve Ayrıcalıklı Hesap Denetimi
.DESCRIPTION
    Domain şifre politikasını raporlar, şifresi hiç bitmeyen hesapları,
    admin grubundaki kullanıcıları ve servis hesaplarını denetler.
    Güvenlik uyumluluğu (compliance) kontrolü için kullanılır.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Audit-PasswordPolicy.ps1
#>

Write-Host "`n=== ŞİFRE POLİTİKASI & AYRICALIKLI HESAP DENETİMİ ===" -ForegroundColor Cyan
Write-Host "Tarih: $(Get-Date -Format 'dd.MM.yyyy HH:mm')`n"

# ============================================
# 1) DOMAIN ŞİFRE POLİTİKASI
# ============================================
Write-Host "--- Domain Şifre Politikası ---`n" -ForegroundColor Cyan

$Policy = Get-ADDefaultDomainPasswordPolicy

Write-Host "Min. Şifre Uzunluğu   : $($Policy.MinPasswordLength) karakter"
Write-Host "Şifre Geçmişi         : $($Policy.PasswordHistoryCount) eski şifre"
Write-Host "Max. Şifre Yaşı       : $($Policy.MaxPasswordAge.Days) gün"
Write-Host "Min. Şifre Yaşı       : $($Policy.MinPasswordAge.Days) gün"
Write-Host "Karmaşıklık Zorunlu   : $($Policy.ComplexityEnabled)"
Write-Host "Hesap Kilitleme Eşiği : $($Policy.LockoutThreshold) deneme"
Write-Host "Kilitleme Süresi      : $($Policy.LockoutDuration.TotalMinutes) dakika"
Write-Host "Kilitleme Sayaç Reset : $($Policy.LockoutObservationWindow.TotalMinutes) dakika"

# Politika uyarıları
$Warnings = @()
if ($Policy.MinPasswordLength -lt 8)  { $Warnings += "Min. şifre uzunluğu 8'den az" }
if (-not $Policy.ComplexityEnabled)    { $Warnings += "Karmaşıklık zorunluluğu kapalı" }
if ($Policy.MaxPasswordAge.Days -gt 90){ $Warnings += "Max. şifre yaşı 90 günden fazla" }
if ($Policy.LockoutThreshold -eq 0)    { $Warnings += "Hesap kilitleme eşiği yok (brute-force riski)" }
if ($Policy.LockoutThreshold -gt 10)   { $Warnings += "Kilitleme eşiği çok yüksek ($($Policy.LockoutThreshold))" }

if ($Warnings) {
    Write-Host "`n⚠ Politika Uyarıları:" -ForegroundColor Yellow
    $Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

# ============================================
# 2) ŞİFRESİ HİÇ BİTMEYEN HESAPLAR
# ============================================
Write-Host "`n--- Şifresi Hiç Bitmeyen Hesaplar ---`n" -ForegroundColor Cyan

$NeverExpire = Get-ADUser -Filter { PasswordNeverExpires -eq $true -and Enabled -eq $true } `
    -Properties PasswordNeverExpires, PasswordLastSet, LastLogonDate, Description |
    Select-Object Name, SamAccountName, PasswordLastSet, LastLogonDate, Description |
    Sort-Object PasswordLastSet

if ($NeverExpire) {
    foreach ($User in $NeverExpire) {
        $PwdAge = if ($User.PasswordLastSet) {
            ((Get-Date) - $User.PasswordLastSet).Days
        } else { "Hiç değişmemiş" }

        $Color = if ($PwdAge -is [int] -and $PwdAge -gt 365) { "Red" } else { "Yellow" }
        Write-Host ("{0,-25} | Şifre yaşı: {1} gün | {2}" -f `
            $User.SamAccountName, $PwdAge, $User.Description) -ForegroundColor $Color
    }
    Write-Host "`nToplam: $($NeverExpire.Count) hesap" -ForegroundColor Yellow
}
else {
    Write-Host "Şifresi hiç bitmeyen aktif hesap yok." -ForegroundColor Green
}

# ============================================
# 3) AYRICALIKLI GRUP ÜYELERİ
# ============================================
Write-Host "`n--- Ayrıcalıklı Grup Üyeleri ---`n" -ForegroundColor Cyan

$PrivGroups = @(
    "Domain Admins",
    "Enterprise Admins",
    "Schema Admins",
    "Administrators",
    "Account Operators",
    "Server Operators",
    "Backup Operators"
)

foreach ($GroupName in $PrivGroups) {
    try {
        $Members = Get-ADGroupMember -Identity $GroupName -ErrorAction SilentlyContinue

        if ($Members) {
            $MemberCount = $Members.Count
            $Color = if ($MemberCount -gt 5) { "Yellow" } else { "White" }

            Write-Host "$GroupName ($MemberCount üye):" -ForegroundColor $Color
            foreach ($M in $Members) {
                $Type = switch ($M.objectClass) {
                    "user"     { "[Kullanıcı]" }
                    "group"    { "[Grup]" }
                    "computer" { "[Bilgisayar]" }
                }
                Write-Host "  $Type $($M.Name) ($($M.SamAccountName))"
            }
        }
        else {
            Write-Host "$GroupName (boş)" -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "$GroupName - bulunamadı" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ============================================
# 4) SERVİS HESAPLARI
# ============================================
Write-Host "--- Servis Hesapları ---`n" -ForegroundColor Cyan

$ServiceAccounts = Get-ADUser -Filter { SamAccountName -like "svc_*" -or SamAccountName -like "service*" } `
    -Properties PasswordLastSet, PasswordNeverExpires, LastLogonDate, Description, Enabled |
    Sort-Object SamAccountName

if ($ServiceAccounts) {
    foreach ($Svc in $ServiceAccounts) {
        $Status = if ($Svc.Enabled) { "Aktif" } else { "Devre Dışı" }
        $PwdExpiry = if ($Svc.PasswordNeverExpires) { "Bitmiyor" } else { "Normal" }
        $PwdAge = if ($Svc.PasswordLastSet) { ((Get-Date) - $Svc.PasswordLastSet).Days } else { "N/A" }

        $Color = if ($PwdAge -is [int] -and $PwdAge -gt 365) { "Red" }
                 elseif ($Svc.PasswordNeverExpires) { "Yellow" }
                 else { "White" }

        Write-Host ("{0,-25} | {1,-9} | Şifre: {2} ({3} gün) | {4}" -f `
            $Svc.SamAccountName, $Status, $PwdExpiry, $PwdAge, $Svc.Description) -ForegroundColor $Color
    }
    Write-Host "`nToplam: $($ServiceAccounts.Count) servis hesabı"
}
else {
    Write-Host "svc_* veya service* ile başlayan hesap bulunamadı."
}

# ============================================
# 5) GENEL SKOR
# ============================================
Write-Host "`n=== GÜVENLİK SKORU ===" -ForegroundColor Cyan

$Score = 100
$Deductions = @()

if ($Policy.MinPasswordLength -lt 8)       { $Score -= 15; $Deductions += "Zayıf şifre uzunluğu (-15)" }
if (-not $Policy.ComplexityEnabled)         { $Score -= 15; $Deductions += "Karmaşıklık kapalı (-15)" }
if ($Policy.LockoutThreshold -eq 0)         { $Score -= 20; $Deductions += "Kilitleme yok (-20)" }
if ($NeverExpire.Count -gt 5)               { $Score -= 10; $Deductions += "Çok fazla never-expire hesap (-10)" }
$OldPwdAccounts = ($NeverExpire | Where-Object { $_.PasswordLastSet -and ((Get-Date) - $_.PasswordLastSet).Days -gt 365 }).Count
if ($OldPwdAccounts -gt 0)                  { $Score -= 10; $Deductions += "$OldPwdAccounts hesabın şifresi 1+ yıl değişmemiş (-10)" }

$ScoreColor = if ($Score -ge 80) { "Green" } elseif ($Score -ge 60) { "Yellow" } else { "Red" }
Write-Host "Skor: $Score / 100" -ForegroundColor $ScoreColor

if ($Deductions) {
    $Deductions | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
}
