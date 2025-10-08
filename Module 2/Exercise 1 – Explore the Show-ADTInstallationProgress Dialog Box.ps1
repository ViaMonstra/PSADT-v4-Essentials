# Exercise 1 – Explore the Show-ADTInstallationProgress Dialog Box

Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module -Name PSAppDeployToolkit
Show-ADTHelpConsole

# Show-ADTInstallationProgress
Show-ADTInstallationProgress -StatusMessage 'Installation in Progress...' -Title 'PSADT Lab Guide' -Subtitle 'Module 2'
Show-ADTInstallationProgress -StatusMessage 'Installation in Progress...' -Title 'PSADT Lab Guide' -Subtitle 'Module 2' -WindowLocation BottomLeft
Show-ADTInstallationProgress -StatusMessage 'Installation in Progress...' -Title 'PSADT Lab Guide' -Subtitle 'Module 2' -AllowMove





