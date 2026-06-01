<#
.SYNOPSIS
    Toplu veya tekli şifre sıfırlama scripti
.DESCRIPTION
    Tek kullanıcı veya CSV dosyasından toplu şifre sıfırlama yapar.
    Kullanıcıyı bir sonraki girişte şifre değiştirmeye zorlar.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Reset-UserPassword.ps1 -UserName "mehmet.yilmaz"
    .\Reset-UserPassword.ps1 -CSVPath ".\sifre-listesi.csv"
#>

param(
    [string]$UserName,
    [string]$CSVPath,
    [string]$NewPassword = "AsC2026!reset"
)

$SecurePass = ConvertTo-SecureString $NewPassword -AsPlainText -Force
$ResetCount = 0
$ErrorCount = 0

function Reset-SingleUser {
    param([string]$User)

    try {
        # Kullanıcının var olup olmadığını kontrol et
        $ADUser = Get-ADUser -Identity $User -ErrorAction Stop

        # Şifreyi sıfırla
        Set-ADAccountPassword -Identity $User -NewPassword $SecurePass -Reset
        Set-ADUser -Identity $User -ChangePasswordAtLogon $true

        Write-Host "[OK] $($ADUser.Name) ($User) - Şifre sıfırlandı" -ForegroundColor Green
        $script:ResetCount++
    }
    catch {
        Write-Host "[HATA] $User - $_" -ForegroundColor Red
        $script:ErrorCount++
    }
}

# ============================================
# TEK KULLANICI
# ============================================
if ($UserName) {
    Write-Host "`n=== TEK KULLANICI ŞİFRE SIFIRLAMA ===" -ForegroundColor Cyan
    Reset-SingleUser -User $UserName
}

# ============================================
# CSV'DEN TOPLU SIFIRLAMA
# ============================================
# CSV formatı: SamAccountName sütunu olmalı
# Örnek:
# SamAccountName
# mehmet.yilmaz
# ayse.demir
# ============================================
elseif ($CSVPath) {
    if (-not (Test-Path $CSVPath)) {
        Write-Host "[HATA] CSV dosyası bulunamadı: $CSVPath" -ForegroundColor Red
        exit 1
    }

    $Users = Import-Csv $CSVPath
    Write-Host "`n=== TOPLU ŞİFRE SIFIRLAMA ===" -ForegroundColor Cyan
    Write-Host "Toplam kullanıcı: $($Users.Count)`n"

    foreach ($Row in $Users) {
        Reset-SingleUser -User $Row.SamAccountName
    }
}
else {
    Write-Host "Kullanım:" -ForegroundColor Yellow
    Write-Host "  .\Reset-UserPassword.ps1 -UserName 'mehmet.yilmaz'"
    Write-Host "  .\Reset-UserPassword.ps1 -CSVPath '.\liste.csv'"
    exit
}

# ============================================
# ÖZET
# ============================================
Write-Host "`n--- Sonuç ---" -ForegroundColor Cyan
Write-Host "Başarılı: $ResetCount | Hatalı: $ErrorCount"
Write-Host "Yeni şifre: $NewPassword (ilk girişte değiştirilecek)`n"
