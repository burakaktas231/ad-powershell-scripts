<#
.SYNOPSIS
    Yeni kullanıcı oluşturma scripti
.DESCRIPTION
    AD'de kullanıcı hesabı açar, Exchange mailbox oluşturur,
    ilgili gruplara ekler. Tek komutla tüm işlemleri yapar.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$FirstName,

    [Parameter(Mandatory=$true)]
    [string]$LastName,

    [Parameter(Mandatory=$true)]
    [string]$Title,          # Örn: "Avukat", "Stajyer", "Sekreter"

    [Parameter(Mandatory=$true)]
    [string]$Department,     # Örn: "Dava", "İcra", "İdari"

    [string]$Password = "AsC2026!ilk",   # İlk giriş şifresi
    [string]$Domain = "aschukuk.com",
    [string]$OUPath = "OU=Kullanicilar,DC=aschukuk,DC=com"
)

# ============================================
# KULLANICI BİLGİLERİ OLUŞTUR
# ============================================

# Türkçe karakter dönüşümü (mail adresi için)
function Convert-TurkishChars {
    param([string]$Text)
    $Text = $Text.ToLower()
    $Text = $Text -replace 'ç','c' -replace 'ğ','g' -replace 'ı','i'
    $Text = $Text -replace 'ö','o' -replace 'ş','s' -replace 'ü','u'
    return $Text
}

$SamAccount = (Convert-TurkishChars $FirstName) + "." + (Convert-TurkishChars $LastName)
$UPN        = "$SamAccount@$Domain"
$DisplayName = "$FirstName $LastName"
$EmailAlias  = $SamAccount

Write-Host "`n=== YENİ KULLANICI OLUŞTURULUYOR ===" -ForegroundColor Cyan
Write-Host "Ad Soyad     : $DisplayName"
Write-Host "Kullanıcı Adı: $SamAccount"
Write-Host "E-posta      : $UPN"
Write-Host "Unvan        : $Title"
Write-Host "Departman    : $Department"
Write-Host "OU           : $OUPath"

# ============================================
# 1) AD HESABI OLUŞTUR
# ============================================
try {
    $SecurePass = ConvertTo-SecureString $Password -AsPlainText -Force

    New-ADUser `
        -Name $DisplayName `
        -GivenName $FirstName `
        -Surname $LastName `
        -SamAccountName $SamAccount `
        -UserPrincipalName $UPN `
        -DisplayName $DisplayName `
        -Title $Title `
        -Department $Department `
        -Path $OUPath `
        -AccountPassword $SecurePass `
        -ChangePasswordAtLogon $true `
        -Enabled $true

    Write-Host "`n[OK] AD hesabı oluşturuldu." -ForegroundColor Green
}
catch {
    Write-Host "`n[HATA] AD hesabı oluşturulamadı: $_" -ForegroundColor Red
    exit 1
}

# ============================================
# 2) GRUPLARA EKLE
# ============================================
$Groups = @("Tum-Kullanicilar")

# Departmana göre ek grup
switch ($Department) {
    "Dava"  { $Groups += "Dava-Departmani" }
    "İcra"  { $Groups += "Icra-Departmani" }
    "İdari" { $Groups += "Idari-Personel" }
}

foreach ($Group in $Groups) {
    try {
        Add-ADGroupMember -Identity $Group -Members $SamAccount
        Write-Host "[OK] '$Group' grubuna eklendi." -ForegroundColor Green
    }
    catch {
        Write-Host "[UYARI] '$Group' grubuna eklenemedi: $_" -ForegroundColor Yellow
    }
}

# ============================================
# 3) EXCHANGE MAILBOX (opsiyonel)
# ============================================
Write-Host "`n--- Exchange Mailbox ---" -ForegroundColor Cyan

try {
    # Exchange Management Shell yüklüyse
    Enable-Mailbox -Identity $SamAccount -Alias $EmailAlias
    Write-Host "[OK] Exchange mailbox oluşturuldu." -ForegroundColor Green
}
catch {
    Write-Host "[BİLGİ] Exchange mailbox manuel oluşturulmalı (Exchange shell bulunamadı)." -ForegroundColor Yellow
}

# ============================================
# ÖZET
# ============================================
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "KULLANICI BAŞARIYLA OLUŞTURULDU"
Write-Host "Kullanıcı Adı : $SamAccount"
Write-Host "İlk Şifre     : $Password"
Write-Host "Şifre Değişimi: İlk girişte zorunlu"
Write-Host "============================================`n" -ForegroundColor Cyan
