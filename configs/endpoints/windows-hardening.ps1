param([string]$LogPath = "./hardening.log")
function Write-Log { param([string]$Msg) $Msg | Out-File -FilePath $LogPath -Append; Write-Host $Msg }
Write-Log "Disabling SMBv1"
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Write-Log "Enabling firewall"
Set-NetFirewallProfile -All -Enabled True
Write-Log "Enabling Defender"
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -PUAProtection Enabled
Set-MpPreference -CloudBlockLevel High
Write-Log "Windows hardening baseline applied"
