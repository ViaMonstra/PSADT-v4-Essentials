# Exercise 1 – Explore the Copy-ADTFile Function 

Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module -Name PSAppDeployToolkit
Show-ADTHelpConsole

# Copy-ADTFile
Copy-ADTFile -Path "$($adtSession.DirSupportFiles)\readme.txt" -Destination "C:\Temp"

# Run install silently
.\Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Silent