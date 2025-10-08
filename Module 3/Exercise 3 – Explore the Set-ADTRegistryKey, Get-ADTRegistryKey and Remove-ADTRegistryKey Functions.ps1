# Exercise 3 – Explore the Set-ADTRegistryKey, Get-ADTRegistryKey and Remove-ADTRegistryKey Functions

# Set-ADTRegistryKey
$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
Set-ADTRegistryKey -LiteralPath $RegPath -Name EnableAutomaticUploadBandwidthManagement -Type DWord -Value 1     

# Get-ADTRegistryKey
Get-ADTRegistryKey -LiteralPath $RegPath -Name EnableAutomaticUploadBandwidthManagement

# Remove-ADTRegistryKey
Remove-ADTRegistryKey -LiteralPath $RegPath -Recurse