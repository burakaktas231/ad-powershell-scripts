# 🔐 AD PowerShell Scripts

PowerShell scripts for Active Directory user lifecycle management, security auditing, Group Policy reporting, and compliance checks. Built for a 150-user single-domain environment.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![Active Directory](https://img.shields.io/badge/Active%20Directory-2019%2F2022-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📋 Scripts

### User Lifecycle

| Script | Description |
|--------|-------------|
| `New-ADUser-Onboard.ps1` | Create AD user + Exchange mailbox + department-based group assignments. Turkish character conversion for email |
| `Disable-OffboardUser.ps1` | Full offboarding: disable, randomize password, strip groups, mail forward, move to Disabled OU |
| `Reset-UserPassword.ps1` | Single or CSV-based bulk password reset with forced change |
| `Unlock-And-Trace.ps1` | Unlock account + trace lockout source from PDC (Event ID 4740) |

### Reporting

| Script | Description |
|--------|-------------|
| `AD-UserHealthReport.ps1` | Locked, expired, inactive, disabled account dashboard |
| `Get-ComputerInventory.ps1` | Domain computer inventory with OS distribution stats |
| `Get-GroupAudit.ps1` | Security group membership audit — empty groups, nested groups |
| `Clean-StaleComputers.ps1` | Find and disable/remove stale computer accounts |

### Security & Compliance

| Script | Description |
|--------|-------------|
| `Get-LoginAudit.ps1` | Failed/successful logon analysis with brute-force detection |
| `Audit-PasswordPolicy.ps1` | Password policy review with security score out of 100 |
| `Audit-LocalAdmins.ps1` | Local admin audit across domain workstations |
| `Get-ScheduledTaskAudit.ps1` | Scheduled task inventory with failure detection |

### Group Policy

| Script | Description |
|--------|-------------|
| `Get-GPOReport.ps1` | GPO listing, link audit, unlinked detection, HTML report, backup |

---

## 🚀 Usage

```powershell
git clone https://github.com/burakaktas231/ad-powershell-scripts.git

.\New-ADUser-Onboard.ps1 -FirstName "Ali" -LastName "Yılmaz" -Title "Avukat" -Department "Dava"
.\AD-UserHealthReport.ps1
.\Audit-PasswordPolicy.ps1
.\Unlock-And-Trace.ps1 -UserName "kilitli.kullanici"
.\Disable-OffboardUser.ps1 -UserName "eski.calisan" -ForwardTo "yonetici@domain.com"
.\Get-GPOReport.ps1 -Backup -HTMLReport
```

## ⚙️ Requirements

- PowerShell 5.1+
- Windows Server 2016 / 2019 / 2022
- RSAT Active Directory & Group Policy modules
- Domain Admin or delegated permissions

## Author

**Burak** — IT Specialist | 7+ Years Infrastructure & Systems Administration
