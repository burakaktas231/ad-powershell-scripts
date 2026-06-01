<#
.SYNOPSIS
    Hesap kilit açma ve kilitlenme kaynağını bulma
.DESCRIPTION
    Kilitli hesabı açar ve Security loglarından kilitlenmenin
    hangi bilgisayardan/servisten geldiğini tespit eder.
    Phantom lockout sorunlarının teşhisinde kullanılır.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Unlock-And-Trace.ps1 -UserName "ayse.demir"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$UserName,

    [switch]$UnlockOnly   # Sadece kilidi aç, log araması yapma
)

# ============================================
# 1) KULLANICI DURUMUNU GÖSTER
# ============================================
Write-Host "`n=== HESAP DURUMU: $UserName ===" -ForegroundColor Cyan

try {
    $User = Get-ADUser -Identity $UserName -Properties `
        LockedOut, LockoutTime, LastLogonDate, `
        LastBadPasswordAttempt, BadLogonCount, PasswordLastSet

    Write-Host "Ad Soyad            : $($User.Name)"
    Write-Host "Kilitli mi          : $($User.LockedOut)"
    Write-Host "Kilitlenme Zamanı   : $($User.LockoutTime)"
    Write-Host "Son Hatalı Giriş    : $($User.LastBadPasswordAttempt)"
    Write-Host "Hatalı Giriş Sayısı : $($User.BadLogonCount)"
    Write-Host "Son Başarılı Giriş  : $($User.LastLogonDate)"
    Write-Host "Şifre Son Değişim   : $($User.PasswordLastSet)"
}
catch {
    Write-Host "[HATA] Kullanıcı bulunamadı: $UserName" -ForegroundColor Red
    exit 1
}

# ============================================
# 2) KİLİDİ AÇ
# ============================================
if ($User.LockedOut) {
    try {
        Unlock-ADAccount -Identity $UserName
        Write-Host "`n[OK] Hesap kilidi açıldı." -ForegroundColor Green
    }
    catch {
        Write-Host "`n[HATA] Kilit açılamadı: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "`n[BİLGİ] Hesap zaten kilitli değil." -ForegroundColor Yellow
}

if ($UnlockOnly) { exit }

# ============================================
# 3) KİLİTLENME KAYNAĞINI BUL (PDC'de)
# ============================================
Write-Host "`n=== KİLİTLENME KAYNAĞI ARAŞTIRMASI ===" -ForegroundColor Cyan

# PDC Emulator'ü bul
$PDC = (Get-ADDomain).PDCEmulator
Write-Host "PDC: $PDC`n"

# Event ID 4740 = Account Lockout
try {
    $LockoutEvents = Get-WinEvent -ComputerName $PDC -FilterHashtable @{
        LogName   = 'Security'
        Id        = 4740
        StartTime = (Get-Date).AddDays(-1)
    } -ErrorAction Stop |
    Where-Object { $_.Properties[0].Value -eq $UserName }

    if ($LockoutEvents) {
        Write-Host "Son 24 saatteki kilitlenme olayları:`n" -ForegroundColor Yellow

        foreach ($Event in $LockoutEvents) {
            $CallerComputer = $Event.Properties[1].Value
            $TimeStamp      = $Event.TimeCreated

            Write-Host "  Zaman   : $TimeStamp" -ForegroundColor White
            Write-Host "  Kaynak  : $CallerComputer" -ForegroundColor Red
            Write-Host "  ---"
        }

        Write-Host "`n[İPUCU] Kaynakları kontrol et:" -ForegroundColor Yellow
        Write-Host "  - Eski şifreyle bağlı Outlook profili"
        Write-Host "  - Mapped drive (net use) eski credential"
        Write-Host "  - Zamanlanmış görev (Task Scheduler) eski şifre"
        Write-Host "  - Mobil cihazda eski Exchange şifresi"
        Write-Host "  - RDP oturumu eski credential ile"
    }
    else {
        Write-Host "Son 24 saatte bu kullanıcı için kilitlenme olayı bulunamadı." -ForegroundColor Green
    }
}
catch {
    Write-Host "[UYARI] PDC loglarına erişilemedi: $_" -ForegroundColor Yellow
    Write-Host "PDC'ye admin yetkisiyle bağlı olduğunuzdan emin olun."
}
