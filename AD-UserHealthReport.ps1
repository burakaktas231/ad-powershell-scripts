<#
.SYNOPSIS
    Active Directory Kullanıcı Sağlık Raporu
.DESCRIPTION
    Domain ortamındaki kullanıcı hesaplarının durumunu kontrol eder:
    - Kilitli hesaplar
    - Şifresi süresi dolmuş kullanıcılar
    - 30+ gündür giriş yapmayan kullanıcılar
    - Devre dışı hesaplar
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.DATE
    2026-05-31
#>

# ============================================
# AYARLAR
# ============================================
$InactiveDays = 30                          # Kaç gündür giriş yapmayan "inaktif" sayılsın
$ReportPath   = "$PSScriptRoot\AD-Rapor_$(Get-Date -Format 'yyyy-MM-dd').txt"

# ============================================
# 1) KİLİTLİ HESAPLAR
# ============================================
Write-Host "`n=== KİLİTLİ HESAPLAR ===" -ForegroundColor Red

$LockedUsers = Search-ADAccount -LockedOut -UsersOnly |
    Select-Object Name, SamAccountName, LastLogonDate, LockedOut

if ($LockedUsers) {
    $LockedUsers | Format-Table -AutoSize
    Write-Host "Toplam: $($LockedUsers.Count) kilitli hesap" -ForegroundColor Yellow
} else {
    Write-Host "Kilitli hesap yok." -ForegroundColor Green
}

# ============================================
# 2) SİFRESİ SURESI DOLMUS KULLANICILAR
# ============================================
Write-Host "`n=== ŞİFRESİ SÜRESI DOLMUŞ ===" -ForegroundColor Red

$ExpiredPwd = Search-ADAccount -PasswordExpired -UsersOnly |
    Where-Object { $_.Enabled -eq $true } |
    Select-Object Name, SamAccountName, LastLogonDate

if ($ExpiredPwd) {
    $ExpiredPwd | Format-Table -AutoSize
    Write-Host "Toplam: $($ExpiredPwd.Count) kullanıcı" -ForegroundColor Yellow
} else {
    Write-Host "Şifresi süresi dolmuş aktif kullanıcı yok." -ForegroundColor Green
}

# ============================================
# 3) 30+ GÜNDÜR GİRİŞ YAPMAYAN AKTİF HESAPLAR
# ============================================
Write-Host "`n=== $InactiveDays+ GÜNDÜR İNAKTİF ===" -ForegroundColor Red

$CutoffDate = (Get-Date).AddDays(-$InactiveDays)

$InactiveUsers = Get-ADUser -Filter { Enabled -eq $true -and LastLogonDate -lt $CutoffDate } `
    -Properties LastLogonDate, Department |
    Select-Object Name, SamAccountName, Department, LastLogonDate |
    Sort-Object LastLogonDate

if ($InactiveUsers) {
    $InactiveUsers | Format-Table -AutoSize
    Write-Host "Toplam: $($InactiveUsers.Count) inaktif hesap" -ForegroundColor Yellow
} else {
    Write-Host "$InactiveDays günden uzun süredir giriş yapmayan aktif hesap yok." -ForegroundColor Green
}

# ============================================
# 4) DEVRE DIŞI HESAPLAR (bilgi amaçlı)
# ============================================
Write-Host "`n=== DEVRE DIŞI HESAPLAR ===" -ForegroundColor DarkGray

$DisabledUsers = Get-ADUser -Filter { Enabled -eq $false } -Properties LastLogonDate |
    Select-Object Name, SamAccountName, LastLogonDate

if ($DisabledUsers) {
    $DisabledUsers | Format-Table -AutoSize
    Write-Host "Toplam: $($DisabledUsers.Count) devre dışı hesap" -ForegroundColor Yellow
} else {
    Write-Host "Devre dışı hesap yok." -ForegroundColor Green
}

# ============================================
# 5) ÖZET
# ============================================
$Summary = @"

============================================
AD KULLANICI SAGLIK RAPORU - $(Get-Date -Format 'dd.MM.yyyy HH:mm')
============================================
Kilitli Hesaplar     : $( if ($LockedUsers)   { $LockedUsers.Count }   else { 0 } )
Sifresi Dolmus       : $( if ($ExpiredPwd)    { $ExpiredPwd.Count }    else { 0 } )
Inaktif ($InactiveDays+ gun) : $( if ($InactiveUsers) { $InactiveUsers.Count } else { 0 } )
Devre Disi           : $( if ($DisabledUsers) { $DisabledUsers.Count } else { 0 } )
============================================
"@

Write-Host $Summary -ForegroundColor Cyan

# Raporu dosyaya kaydet
$Summary | Out-File -FilePath $ReportPath -Encoding UTF8
Write-Host "Rapor kaydedildi: $ReportPath" -ForegroundColor Green
