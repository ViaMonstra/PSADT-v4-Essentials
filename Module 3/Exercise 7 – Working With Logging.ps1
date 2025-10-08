# Exercise 7 – Working With Logging

Write-ADTLogEntry "BEFORE Copy-ADTContentToCache"
Write-ADTLogEntry "DirFiles is now $($adtSession.DirFiles)"

Write-ADTLogEntry "AFTER Copy-ADTContentToCache"
Write-ADTLogEntry "DirFiles is now $($adtSession.DirFiles)"

.\Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Silent
