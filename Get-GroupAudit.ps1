<#
.SYNOPSIS
    AD Grup Üyelik Denetim Raporu
.DESCRIPTION
    Tüm güvenlik gruplarını ve üyelerini listeler.
    Boş grupları, iç içe grupları ve yetki dağılımını raporlar.
    Periyodik güvenlik denetimi için kullanılır.
.AUTHOR
    Burak - ASC Hukuk IT
.VERSION
    1.0
.EXAMPLE
    .\Get-GroupAudit.ps1
    .\Get-GroupAudit.ps1 -SearchBase "OU=Gruplar,DC=aschukuk,DC=com"
#>

param(
    [string]$SearchBase,
    [switch]$ExportCSV
)

Write-Host "`n=== GRUP ÜYELİK DENETİM RAPORU ===" -ForegroundColor Cyan
Write-Host "Tarih: $(Get-Date -Format 'dd.MM.yyyy HH:mm')`n"

# ============================================
# GRUPLARI ÇEK
# ============================================
$GetParams = @{
    Filter     = { GroupCategory -eq "Security" }
    Properties = "Members", "Description", "Created", "ManagedBy"
}
if ($SearchBase) { $GetParams.SearchBase = $SearchBase }

try {
    $Groups = Get-ADGroup @GetParams | Sort-Object Name

    $EmptyGroups    = @()
    $AllMemberships = @()

    foreach ($Group in $Groups) {
        $Members = Get-ADGroupMember -Identity $Group -ErrorAction SilentlyContinue

        $MemberCount = if ($Members) { $Members.Count } else { 0 }

        # Boş grup kontrolü
        if ($MemberCount -eq 0) {
            $EmptyGroups += $Group.Name
        }

        # Detaylı üyelik
        if ($Members) {
            foreach ($Member in $Members) {
                $AllMemberships += [PSCustomObject]@{
                    Grup       = $Group.Name
                    Uye        = $Member.Name
                    UyeTipi    = $Member.objectClass  # user / group / computer
                    SamAccount = $Member.SamAccountName
                }
            }
        }

        # Ekrana özet
        $Color = if ($MemberCount -eq 0) { "DarkGray" } elseif ($MemberCount -gt 20) { "Yellow" } else { "White" }
        Write-Host ("{0,-40} : {1} üye" -f $Group.Name, $MemberCount) -ForegroundColor $Color
    }

    # ============================================
    # BOŞ GRUPLAR
    # ============================================
    if ($EmptyGroups.Count -gt 0) {
        Write-Host "`n--- Boş Gruplar (üyesi yok) ---" -ForegroundColor Yellow
        $EmptyGroups | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        Write-Host "Toplam: $($EmptyGroups.Count) boş grup"
    }

    # ============================================
    # İÇ İÇE GRUPLAR (nested)
    # ============================================
    $NestedGroups = $AllMemberships | Where-Object { $_.UyeTipi -eq "group" }
    if ($NestedGroups) {
        Write-Host "`n--- İç İçe Grup Üyelikleri ---" -ForegroundColor Yellow
        $NestedGroups | ForEach-Object {
            Write-Host "  $($_.Grup) --> $($_.Uye) (nested group)" -ForegroundColor Yellow
        }
    }

    # ============================================
    # ÖZET
    # ============================================
    Write-Host "`n--- Özet ---" -ForegroundColor Cyan
    Write-Host "Toplam Güvenlik Grubu : $($Groups.Count)"
    Write-Host "Boş Grup              : $($EmptyGroups.Count)"
    Write-Host "İç İçe Grup           : $($NestedGroups.Count)"
    Write-Host "Toplam Üyelik Kaydı   : $($AllMemberships.Count)"

    # ============================================
    # CSV EXPORT
    # ============================================
    if ($ExportCSV) {
        $ReportPath = "$PSScriptRoot\GrupAudit_$(Get-Date -Format 'yyyy-MM-dd').csv"
        $AllMemberships | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nRapor kaydedildi: $ReportPath" -ForegroundColor Green
    }
}
catch {
    Write-Host "[HATA] Grup sorgusu başarısız: $_" -ForegroundColor Red
}
