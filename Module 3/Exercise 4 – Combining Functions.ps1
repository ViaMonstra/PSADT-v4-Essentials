# Exercise 4 – Combining Functions

Invoke-ADTAllUsersRegistryAction -ScriptBlock {
    $RegPath = "HKCU:\SOFTWARE\Policies\Microsoft\OneDrive"
    Set-ADTRegistryKey -LiteralPath $RegPath -Name DisablePersonalSync -Type DWord -Value 1 -SID $_.SID 
}
