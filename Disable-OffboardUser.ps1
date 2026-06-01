<#
.SYNOPSIS
    Kullanıcı çıkış (offboarding) scripti
.DESCRIPTION
    İşten ayrılan kullanıcının hesabını güvenli şekilde kapatır:
    - AD hesabını devre dışı bırakır
    - Şifresini rastgele değiştirir
    - Tüm gruplardan çıkarır
    - Exchange mailbox'ına yönlendirme (forward) ayarlar
    - Açıklamaya çıkış tarihini yazar
    - Disabled OU'ya taşır
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Disable-OffboardUser.ps1 -UserName "eski.calisan" -ForwardTo "yonetici@aschukuk.com"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$UserName,

    [string]$ForwardTo,          # Mail yönlendirme adresi (opsiyonel)
    [string]$DisabledOU = "OU=Devre_Disi,DC=aschukuk,DC=com"
)

Write-Host "`n=== KULLANICI ÇIKIŞ İŞLEMİ ===" -ForegroundColor Cyan
Write-Host "Kullanıcı: $UserName"
Write-Host "Tarih    : $(Get-Date -Format 'dd.MM.yyyy')`n"

# ============================================
# KULLANICIYI DOĞRULA
# ============================================
try {
    $User = Get-ADUser -Identity $UserName -Properties MemberOf, Description, DisplayName
    Write-Host "Ad Soyad: $($User.DisplayName)" -ForegroundColor White
}
catch {
    Write-Host "[HATA] Kullanıcı bulunamadı: $UserName" -ForegroundColor Red
    exit 1
}

# Onay iste
$Confirm = Read-Host "`nBu kullanıcının hesabı kapatılacak. Onaylıyor musunuz? (E/H)"
if ($Confirm -ne "E") {
    Write-Host "İşlem iptal edildi." -ForegroundColor Yellow
    exit
}

# ============================================
# 1) HESABI DEVRE DIŞI BIRAK
# ============================================
try {
    Disable-ADAccount -Identity $UserName
    Write-Host "[OK] Hesap devre dışı bırakıldı." -ForegroundColor Green
}
catch {
    Write-Host "[HATA] Hesap devre dışı bırakılamadı: $_" -ForegroundColor Red
}

# ============================================
# 2) ŞİFREYİ RASTGELE DEĞİŞTİR
# ============================================
try {
    $RandomPass = -join ((65..90) + (97..122) + (48..57) + (33,35,37,42) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
    $SecurePass = ConvertTo-SecureString $RandomPass -AsPlainText -Force
    Set-ADAccountPassword -Identity $UserName -NewPassword $SecurePass -Reset
    Write-Host "[OK] Şifre rastgele değiştirildi." -ForegroundColor Green
}
catch {
    Write-Host "[HATA] Şifre değiştirilemedi: $_" -ForegroundColor Red
}

# ============================================
# 3) TÜM GRUPLARDAN ÇIKAR
# ============================================
try {
    $Groups = (Get-ADUser -Identity $UserName -Properties MemberOf).MemberOf
    $RemovedCount = 0

    foreach ($GroupDN in $Groups) {
        try {
            Remove-ADGroupMember -Identity $GroupDN -Members $UserName -Confirm:$false
            $RemovedCount++
        }
        catch {
            Write-Host "[UYARI] Gruptan çıkarılamadı: $GroupDN" -ForegroundColor Yellow
        }
    }
    Write-Host "[OK] $RemovedCount gruptan çıkarıldı." -ForegroundColor Green
}
catch {
    Write-Host "[HATA] Grup işlemi başarısız: $_" -ForegroundColor Red
}

# ============================================
# 4) EXCHANGE MAIL YÖNLENDIRME
# ============================================
if ($ForwardTo) {
    try {
        Set-Mailbox -Identity $UserName -ForwardingSmtpAddress $ForwardTo -DeliverToMailboxAndForward $false
        Write-Host "[OK] Mailler $ForwardTo adresine yönlendirildi." -ForegroundColor Green
    }
    catch {
        Write-Host "[UYARI] Mail yönlendirme ayarlanamadı (Exchange shell gerekli): $_" -ForegroundColor Yellow
    }
}

# ============================================
# 5) AÇIKLAMA EKLE & OU'YA TAŞI
# ============================================
try {
    $Description = "Çıkış: $(Get-Date -Format 'dd.MM.yyyy') - IT tarafından kapatıldı"
    Set-ADUser -Identity $UserName -Description $Description
    Write-Host "[OK] Açıklama eklendi." -ForegroundColor Green
}
catch {
    Write-Host "[UYARI] Açıklama eklenemedi: $_" -ForegroundColor Yellow
}

try {
    Move-ADObject -Identity $User.DistinguishedName -TargetPath $DisabledOU
    Write-Host "[OK] Devre Dışı OU'ya taşındı." -ForegroundColor Green
}
catch {
    Write-Host "[UYARI] OU'ya taşınamadı (OU mevcut olmayabilir): $_" -ForegroundColor Yellow
}

# ============================================
# ÖZET
# ============================================
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "ÇIKIŞ İŞLEMİ TAMAMLANDI"
Write-Host "Kullanıcı     : $($User.DisplayName) ($UserName)"
Write-Host "Hesap          : Devre dışı"
Write-Host "Şifre          : Rastgele değiştirildi"
Write-Host "Gruplar        : $RemovedCount gruptan çıkarıldı"
Write-Host "Mail Yönlendirme: $(if ($ForwardTo) { $ForwardTo } else { 'Ayarlanmadı' })"
Write-Host "============================================`n" -ForegroundColor Cyan
