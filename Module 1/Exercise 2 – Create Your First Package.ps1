# Exercise 2 – Create Your First Package
New-ADTTemplate -Destination C:\Apps -Name "FirstPackage"

# App data
AppVendor = 'Igor Pavlov'
AppName = '7-Zip'
AppVersion = '25.01' 
AppArch = 'x64'

# Install command
Start-ADTProcess -FilePath '7z2501-x64.exe' -ArgumentList '/S'

# Uninstall command
Start-ADTProcess -FilePath "$env:ProgramFiles\7-Zip\Uninstall.exe" -ArgumentList '/S' 

# Start package install
.\Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Interactive

# Start package uninstall
.\Invoke-AppDeployToolkit.exe -DeploymentType Uninstall




