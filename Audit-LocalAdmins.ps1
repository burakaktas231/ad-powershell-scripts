<#
.SYNOPSIS
    Local Admin Hesap Denetimi
.DESCRIPTION
    Domain bilgisayarlarındaki local Administrators grubunun
    üyelerini denetler. Yetkisiz local admin hesaplarını tespit eder.
    Güvenlik denetimi ve compliance için kritik bir scripttir.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Audit-LocalAdmins.ps1
    .\Audit-LocalAdmins.ps1 -ExportCSV
#>

param(
    [string]$TargetOU,        # Belirli OU'daki bilgisayarları tara
    [switch]$ExportCSV
)

Write-Host "`n=== LOCAL ADMIN HESAP DENETİMİ ===" -ForegroundColor Cyan
Write-Host "Tarih: $(Get-Date -Format 'dd.MM.yyyy HH:mm')`n"

# İzin verilen admin hesapları (bunlar normal)
$AllowedAdmins = @(
    "Administrator",
    "Domain Admins",
    "ASCHUKUK\Domain Admins",
    "ASCHUKUK\IT-Admins"
)

# Bilgisayarları çek
$GetParams = @{
    Filter     = { OperatingSystem -notlike "*Server*" -and Enabled -eq $true }
    Properties = "OperatingSystem", "LastLogonDate"
}
if ($TargetOU) { $GetParams.SearchBase = $TargetOU }

$Computers = Get-ADComputer @GetParams |
    Where-Object { $_.LastLogonDate -gt (Get-Date).AddDays(-30) } |
    Sort-Object Name

Write-Host "Taranacak bilgisayar: $($Computers.Count)`n"

$AllResults     = @()
$Violations     = @()
$ScannedCount   = 0
$ErrorCount     = 0

foreach ($PC in $Computers) {
    $ScannedCount++
    Write-Host "[$ScannedCount/$($Computers.Count)] $($PC.Name) ..." -NoNewline

    try {
        $LocalAdmins = Invoke-Command -ComputerName $PC.Name -ScriptBlock {
            Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop |
            Select-Object Name, ObjectClass, PrincipalSource
        } -ErrorAction Stop

        $UnauthorizedAdmins = $LocalAdmins | Where-Object {
            $CleanName = $_.Name -replace '^.*\\', ''
            $_.Name -notin $AllowedAdmins -and $CleanName -notin $AllowedAdmins
        }

        if ($UnauthorizedAdmins) {
            Write-Host " [UYARI]" -ForegroundColor Red
            foreach ($Admin in $UnauthorizedAdmins) {
                Write-Host "    --> $($Admin.Name) ($($Admin.ObjectClass))" -ForegroundColor Red

                $Violations += [PSCustomObject]@{
                    Bilgisayar = $PC.Name
                    Hesap      = $Admin.Name
                    Tipi       = $Admin.ObjectClass
                    Kaynak     = $Admin.PrincipalSource
                }
            }
        }
        else {
            Write-Host " [OK]" -ForegroundColor Green
        }

        foreach ($Admin in $LocalAdmins) {
            $AllResults += [PSCustomObject]@{
                Bilgisayar = $PC.Name
                Hesap      = $Admin.Name
                Tipi       = $Admin.ObjectClass
                Yetkili_mi = if ($UnauthorizedAdmins.Name -contains $Admin.Name) { "HAYIR" } else { "Evet" }
            }
        }
    }
    catch {
        Write-Host " [ERİŞİLEMEDİ]" -ForegroundColor DarkGray
        $ErrorCount++
    }
}

# ============================================
# ÖZET
# ============================================
Write-Host "`n--- Özet ---" -ForegroundColor Cyan
Write-Host "Taranan      : $ScannedCount"
Write-Host "Erişilemez   : $ErrorCount" -ForegroundColor $(if ($ErrorCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "İhlal Sayısı : $($Violations.Count)" -ForegroundColor $(if ($Violations.Count -gt 0) { "Red" } else { "Green" })

if ($Violations.Count -gt 0) {
    Write-Host "`n⚠ Yetkisiz local admin hesapları tespit edildi!" -ForegroundColor Red
    Write-Host "Etkilenen bilgisayarlar:" -ForegroundColor Yellow

    $Violations | Group-Object Bilgisayar | ForEach-Object {
        Write-Host "  $($_.Name): $(($_.Group.Hesap) -join ', ')" -ForegroundColor Yellow
    }
}

if ($ExportCSV) {
    $ReportPath = "$PSScriptRoot\LocalAdminAudit_$(Get-Date -Format 'yyyy-MM-dd').csv"
    $AllResults | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
    Write-Host "`nRapor kaydedildi: $ReportPath" -ForegroundColor Green
}
