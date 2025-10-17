<#

.SYNOPSIS
PSAppDeployToolkit - Dynamic Detection Logic Demo Script

.DESCRIPTION
This script demonstrates real-world examples of dynamic detection logic to prevent redundant installs:
- Check application version at script start
- Exit gracefully if already at desired version
- Compare versions and determine if update is needed
- Handle different version formats and comparison methods

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

.PARAMETER DeploymentType
The type of deployment to perform.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive (shows dialogs), Silent (no dialogs), NonInteractive (dialogs without prompts) mode, or Auto (shows dialogs if a user is logged on, device is not in the OOBE, and there's no running apps to close).

Silent mode is automatically set if it is detected that the process is not user interactive, no users are logged on, the device is in Autopilot mode, or there's specified processes to close that are currently running.

.PARAMETER SuppressRebootPassThru
Suppresses the 3010 return code (requires restart) from being passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Silent

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Invoke-AppDeployToolkit.ps1, and Invoke-AppDeployToolkit.exe
- 69000 - 69999: Recommended for user customized exit codes in Invoke-AppDeployToolkit.ps1
- 70000 - 79999: Recommended for user customized exit codes in PSAppDeployToolkit.Extensions module.

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    # Default is 'Install'.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType,

    # Default is 'Auto'. Don't hard-code this unless required.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Interactive', 'NonInteractive', 'Silent')]
    [System.String]$DeployMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$SuppressRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

# Zero-Config MSI support is provided when "AppName" is null or empty.
# By setting the "AppName" property, Zero-Config MSI will be disabled.
$adtSession = @{
    # App variables.
    AppVendor = 'PSAppDeployToolkit'
    AppName = 'DynamicDetectionDemo'
    AppVersion = '2.1.0'
    AppArch = 'x64'
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppProcessesToClose = @()
    AppScriptVersion = '1.0.0'
    AppScriptDate = '2025-01-27'
    AppScriptAuthor = 'PSAppDeployToolkit'
    RequireAdmin = $true

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ''
    InstallTitle = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters = $PSBoundParameters
    DeployAppScriptVersion = '4.1.5'
}

##================================================
## MARK: Dynamic Detection Functions
##================================================

function Test-ADTApplicationVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]$ApplicationName,
        
        [Parameter(Mandatory = $true)]
        [System.String]$RequiredVersion,
        
        [Parameter(Mandatory = $false)]
        [System.String]$NameMatch = 'Contains'
    )
    
    try
    {
        Write-ADTLogEntry -Message "Checking for application: $ApplicationName"
        
        $installedApps = Get-ADTApplication -Name $ApplicationName -NameMatch $NameMatch
        if ($installedApps.Count -eq 0)
        {
            Write-ADTLogEntry -Message "Application not found: $ApplicationName"
            return @{
                Found = $false
                CurrentVersion = $null
                RequiredVersion = $RequiredVersion
                NeedsUpdate = $true
            }
        }
        
        $installedApp = $installedApps[0]
        $currentVersion = $installedApp.DisplayVersion
        
        Write-ADTLogEntry -Message "Found application: $($installedApp.DisplayName) version $currentVersion"
        
        ## Compare versions
        $needsUpdate = $false
        if ($currentVersion)
        {
            $versionComparison = Compare-ADTVersion -CurrentVersion $currentVersion -RequiredVersion $RequiredVersion
            $needsUpdate = $versionComparison -lt 0
        }
        else
        {
            $needsUpdate = $true
        }
        
        return @{
            Found = $true
            CurrentVersion = $currentVersion
            RequiredVersion = $RequiredVersion
            NeedsUpdate = $needsUpdate
            Application = $installedApp
        }
    }
    catch
    {
        Write-ADTLogEntry -Message "Error checking application version: $($_.Exception.Message)" -Severity 2
        return @{
            Found = $false
            CurrentVersion = $null
            RequiredVersion = $RequiredVersion
            NeedsUpdate = $true
            Error = $_.Exception.Message
        }
    }
}

function Compare-ADTVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]$CurrentVersion,
        
        [Parameter(Mandatory = $true)]
        [System.String]$RequiredVersion
    )
    
    try
    {
        ## Convert versions to System.Version objects for comparison
        $currentVer = [System.Version]::new($CurrentVersion)
        $requiredVer = [System.Version]::new($RequiredVersion)
        
        return $currentVer.CompareTo($requiredVer)
    }
    catch
    {
        Write-ADTLogEntry -Message "Error comparing versions: $($_.Exception.Message)" -Severity 2
        return -1  # Assume update needed if comparison fails
    }
}

function Test-ADTFileVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [System.String]$RequiredVersion
    )
    
    try
    {
        if (!(Test-Path -LiteralPath $FilePath -PathType Leaf))
        {
            Write-ADTLogEntry -Message "File not found: $FilePath"
            return @{
                Found = $false
                CurrentVersion = $null
                RequiredVersion = $RequiredVersion
                NeedsUpdate = $true
            }
        }
        
        $fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
        $currentVersion = $fileVersion.FileVersion
        
        Write-ADTLogEntry -Message "Found file: $FilePath version $currentVersion"
        
        ## Compare versions
        $needsUpdate = $false
        if ($currentVersion)
        {
            $versionComparison = Compare-ADTVersion -CurrentVersion $currentVersion -RequiredVersion $RequiredVersion
            $needsUpdate = $versionComparison -lt 0
        }
        else
        {
            $needsUpdate = $true
        }
        
        return @{
            Found = $true
            CurrentVersion = $currentVersion
            RequiredVersion = $RequiredVersion
            NeedsUpdate = $needsUpdate
            FileVersion = $fileVersion
        }
    }
    catch
    {
        Write-ADTLogEntry -Message "Error checking file version: $($_.Exception.Message)" -Severity 2
        return @{
            Found = $false
            CurrentVersion = $null
            RequiredVersion = $RequiredVersion
            NeedsUpdate = $true
            Error = $_.Exception.Message
        }
    }
}

function Test-ADTRegistryVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]$RegistryPath,
        
        [Parameter(Mandatory = $true)]
        [System.String]$ValueName,
        
        [Parameter(Mandatory = $true)]
        [System.String]$RequiredVersion
    )
    
    try
    {
        if (!(Test-Path -LiteralPath $RegistryPath))
        {
            Write-ADTLogEntry -Message "Registry path not found: $RegistryPath"
            return @{
                Found = $false
                CurrentVersion = $null
                RequiredVersion = $RequiredVersion
                NeedsUpdate = $true
            }
        }
        
        $currentVersion = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $ValueName
        
        if (!$currentVersion)
        {
            Write-ADTLogEntry -Message "Registry value not found: $RegistryPath\$ValueName"
            return @{
                Found = $false
                CurrentVersion = $null
                RequiredVersion = $RequiredVersion
                NeedsUpdate = $true
            }
        }
        
        Write-ADTLogEntry -Message "Found registry value: $RegistryPath\$ValueName = $currentVersion"
        
        ## Compare versions
        $needsUpdate = $false
        if ($currentVersion)
        {
            $versionComparison = Compare-ADTVersion -CurrentVersion $currentVersion -RequiredVersion $RequiredVersion
            $needsUpdate = $versionComparison -lt 0
        }
        else
        {
            $needsUpdate = $true
        }
        
        return @{
            Found = $true
            CurrentVersion = $currentVersion
            RequiredVersion = $RequiredVersion
            NeedsUpdate = $needsUpdate
        }
    }
    catch
    {
        Write-ADTLogEntry -Message "Error checking registry version: $($_.Exception.Message)" -Severity 2
        return @{
            Found = $false
            CurrentVersion = $null
            RequiredVersion = $RequiredVersion
            NeedsUpdate = $true
            Error = $_.Exception.Message
        }
    }
}

function Install-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close processes if specified, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt.
    $saiwParams = @{
        AllowDeferCloseProcesses = $true
        DeferTimes = 3
        PersistPrompt = $true
    }
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        $saiwParams.Add('CloseProcesses', $adtSession.AppProcessesToClose)
    }
    Show-ADTInstallationWelcome @saiwParams

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Installation tasks here>


    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Installation tasks here>
    
    ## DEMO: Dynamic Detection Logic Examples
    
    ## Example 1: Check application version and exit if already at desired version
    Write-ADTLogEntry -Message "=== DEMO: Check application version and exit if already at desired version ==="
    
    $appVersionCheck = Test-ADTApplicationVersion -ApplicationName "DynamicDetectionDemo" -RequiredVersion "2.1.0" -NameMatch "Exact"
    
    if ($appVersionCheck.Found -and !$appVersionCheck.NeedsUpdate)
    {
        Write-ADTLogEntry -Message "Application is already at the required version ($($appVersionCheck.CurrentVersion)). Exiting gracefully."
        Show-ADTInstallationPrompt -Message "DynamicDetectionDemo is already at version $($appVersionCheck.CurrentVersion). No update needed." -ButtonRightText 'OK' -Icon Information -NoWait
        return
    }
    
    if ($appVersionCheck.Found)
    {
        Write-ADTLogEntry -Message "Application found at version $($appVersionCheck.CurrentVersion). Update needed to reach $($appVersionCheck.RequiredVersion)"
    }
    else
    {
        Write-ADTLogEntry -Message "Application not found. Installation needed."
    }
    
    ## Example 2: Check multiple applications and their versions
    Write-ADTLogEntry -Message "=== DEMO: Check multiple applications and their versions ==="
    
    $applicationsToCheck = @(
        @{ Name = "Microsoft Visual C++ 2015-2022 Redistributable (x64)"; RequiredVersion = "14.30.30704.0"; NameMatch = "Exact" },
        @{ Name = "Microsoft .NET Framework 4.8"; RequiredVersion = "4.8.0.0"; NameMatch = "Exact" },
        @{ Name = "Java"; RequiredVersion = "8.0.0.0"; NameMatch = "Contains" }
    )
    
    $allApplicationsReady = $true
    foreach ($app in $applicationsToCheck)
    {
        $versionCheck = Test-ADTApplicationVersion -ApplicationName $app.Name -RequiredVersion $app.RequiredVersion -NameMatch $app.NameMatch
        
        if ($versionCheck.Found)
        {
            if ($versionCheck.NeedsUpdate)
            {
                Write-ADTLogEntry -Message "✗ $($app.Name): Current version $($versionCheck.CurrentVersion) is older than required $($versionCheck.RequiredVersion)"
                $allApplicationsReady = $false
            }
            else
            {
                Write-ADTLogEntry -Message "✓ $($app.Name): Version $($versionCheck.CurrentVersion) meets requirements"
            }
        }
        else
        {
            Write-ADTLogEntry -Message "✗ $($app.Name): Not found"
            $allApplicationsReady = $false
        }
    }
    
    if (!$allApplicationsReady)
    {
        Write-ADTLogEntry -Message "Some applications need to be updated or installed"
    }
    else
    {
        Write-ADTLogEntry -Message "All applications meet version requirements"
    }
    
    ## Example 3: Check file version
    Write-ADTLogEntry -Message "=== DEMO: Check file version ==="
    
    $systemFiles = @(
        @{ Path = "C:\Windows\System32\kernel32.dll"; RequiredVersion = "10.0.19041.1" },
        @{ Path = "C:\Windows\System32\user32.dll"; RequiredVersion = "10.0.19041.1" }
    )
    
    foreach ($file in $systemFiles)
    {
        $fileVersionCheck = Test-ADTFileVersion -FilePath $file.Path -RequiredVersion $file.RequiredVersion
        
        if ($fileVersionCheck.Found)
        {
            if ($fileVersionCheck.NeedsUpdate)
            {
                Write-ADTLogEntry -Message "✗ $($file.Path): Version $($fileVersionCheck.CurrentVersion) is older than required $($fileVersionCheck.RequiredVersion)"
            }
            else
            {
                Write-ADTLogEntry -Message "✓ $($file.Path): Version $($fileVersionCheck.CurrentVersion) meets requirements"
            }
        }
        else
        {
            Write-ADTLogEntry -Message "✗ $($file.Path): File not found"
        }
    }
    
    ## Example 4: Check registry version
    Write-ADTLogEntry -Message "=== DEMO: Check registry version ==="
    
    $registryChecks = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"; ValueName = "CurrentVersion"; RequiredVersion = "10.0" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"; ValueName = "CurrentBuild"; RequiredVersion = "19041" }
    )
    
    foreach ($reg in $registryChecks)
    {
        $regVersionCheck = Test-ADTRegistryVersion -RegistryPath $reg.Path -ValueName $reg.ValueName -RequiredVersion $reg.RequiredVersion
        
        if ($regVersionCheck.Found)
        {
            if ($regVersionCheck.NeedsUpdate)
            {
                Write-ADTLogEntry -Message "✗ $($reg.Path)\$($reg.ValueName): Value $($regVersionCheck.CurrentVersion) is older than required $($regVersionCheck.RequiredVersion)"
            }
            else
            {
                Write-ADTLogEntry -Message "✓ $($reg.Path)\$($reg.ValueName): Value $($regVersionCheck.CurrentVersion) meets requirements"
            }
        }
        else
        {
            Write-ADTLogEntry -Message "✗ $($reg.Path)\$($reg.ValueName): Registry value not found"
        }
    }
    
    ## Example 5: Check PowerShell version
    Write-ADTLogEntry -Message "=== DEMO: Check PowerShell version ==="
    
    $psVersion = $PSVersionTable.PSVersion
    $requiredPSVersion = [System.Version]::new("5.1.0.0")
    
    if ($psVersion -ge $requiredPSVersion)
    {
        Write-ADTLogEntry -Message "✓ PowerShell version $($psVersion.ToString()) meets requirements (>= $($requiredPSVersion.ToString()))"
    }
    else
    {
        Write-ADTLogEntry -Message "✗ PowerShell version $($psVersion.ToString()) is older than required $($requiredPSVersion.ToString())" -Severity 2
    }
    
    ## Example 6: Check Windows version
    Write-ADTLogEntry -Message "=== DEMO: Check Windows version ==="
    
    $osVersion = [System.Environment]::OSVersion.Version
    $requiredOSVersion = [System.Version]::new("10.0.0.0")
    
    if ($osVersion -ge $requiredOSVersion)
    {
        Write-ADTLogEntry -Message "✓ Windows version $($osVersion.ToString()) meets requirements (>= $($requiredOSVersion.ToString()))"
    }
    else
    {
        Write-ADTLogEntry -Message "✗ Windows version $($osVersion.ToString()) is older than required $($requiredOSVersion.ToString())" -Severity 2
    }
    
    ## Example 7: Check available disk space
    Write-ADTLogEntry -Message "=== DEMO: Check available disk space ==="
    
    $systemDrive = $env:SystemDrive
    $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$systemDrive'"
    $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    $requiredSpaceGB = 5.0
    
    if ($freeSpaceGB -ge $requiredSpaceGB)
    {
        Write-ADTLogEntry -Message "✓ Available disk space: $freeSpaceGB GB (>= $requiredSpaceGB GB required)"
    }
    else
    {
        Write-ADTLogEntry -Message "✗ Available disk space: $freeSpaceGB GB (< $requiredSpaceGB GB required)" -Severity 2
    }
    
    ## Example 8: Check memory
    Write-ADTLogEntry -Message "=== DEMO: Check memory ==="
    
    $totalMemory = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
    $totalMemoryGB = [math]::Round($totalMemory / 1GB, 2)
    $requiredMemoryGB = 4.0
    
    if ($totalMemoryGB -ge $requiredMemoryGB)
    {
        Write-ADTLogEntry -Message "✓ Total memory: $totalMemoryGB GB (>= $requiredMemoryGB GB required)"
    }
    else
    {
        Write-ADTLogEntry -Message "✗ Total memory: $totalMemoryGB GB (< $requiredMemoryGB GB required)" -Severity 2
    }

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>
    
    ## Example 9: Final version verification
    Write-ADTLogEntry -Message "=== DEMO: Final version verification ==="
    
    $finalVersionCheck = Test-ADTApplicationVersion -ApplicationName "DynamicDetectionDemo" -RequiredVersion "2.1.0" -NameMatch "Exact"
    
    if ($finalVersionCheck.Found)
    {
        Write-ADTLogEntry -Message "Installation completed. Application version: $($finalVersionCheck.CurrentVersion)"
    }
    else
    {
        Write-ADTLogEntry -Message "Installation completed but application not found in registry" -Severity 2
    }
    
    ## Example 10: Generate detection report
    Write-ADTLogEntry -Message "=== DEMO: Generate detection report ==="
    
    $detectionReport = @{
        "Detection Date" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "System Information" = @{
            "OS Version" = [System.Environment]::OSVersion.Version.ToString()
            "PowerShell Version" = $PSVersionTable.PSVersion.ToString()
            "Architecture" = if ([System.Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
            "Total Memory" = "$totalMemoryGB GB"
            "Free Disk Space" = "$freeSpaceGB GB"
        }
        "Application Checks" = @()
    }
    
    foreach ($app in $applicationsToCheck)
    {
        $versionCheck = Test-ADTApplicationVersion -ApplicationName $app.Name -RequiredVersion $app.RequiredVersion -NameMatch $app.NameMatch
        $detectionReport."Application Checks" += @{
            "Name" = $app.Name
            "Current Version" = $versionCheck.CurrentVersion
            "Required Version" = $app.RequiredVersion
            "Status" = if ($versionCheck.Found -and !$versionCheck.NeedsUpdate) { "OK" } else { "Needs Update" }
        }
    }
    
    Write-ADTLogEntry -Message "Detection Report:"
    Write-ADTLogEntry -Message "  Detection Date: $($detectionReport.'Detection Date')"
    Write-ADTLogEntry -Message "  System Information:"
    Write-ADTLogEntry -Message "    OS Version: $($detectionReport.'System Information'.'OS Version')"
    Write-ADTLogEntry -Message "    PowerShell Version: $($detectionReport.'System Information'.'PowerShell Version')"
    Write-ADTLogEntry -Message "    Architecture: $($detectionReport.'System Information'.Architecture)"
    Write-ADTLogEntry -Message "    Total Memory: $($detectionReport.'System Information'.'Total Memory')"
    Write-ADTLogEntry -Message "    Free Disk Space: $($detectionReport.'System Information'.'Free Disk Space')"
    Write-ADTLogEntry -Message "  Application Checks:"
    foreach ($appCheck in $detectionReport."Application Checks")
    {
        Write-ADTLogEntry -Message "    - $($appCheck.Name): $($appCheck.'Current Version') ($($appCheck.Status))"
    }

    ## Display a message at the end of the install.
    Show-ADTInstallationPrompt -Message "Dynamic Detection Demo installation complete. All version checks have been performed." -ButtonRightText 'OK' -Icon Information -NoWait
}

function Uninstall-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## If there are processes to close, show Welcome Message with a 60 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 60
    }

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Uninstallation tasks here>


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Uninstallation tasks here>
    
    ## DEMO: Dynamic Detection for Uninstall
    
    ## Example 1: Check if application exists before uninstalling
    Write-ADTLogEntry -Message "=== DEMO: Check if application exists before uninstalling ==="
    
    $appVersionCheck = Test-ADTApplicationVersion -ApplicationName "DynamicDetectionDemo" -RequiredVersion "1.0.0" -NameMatch "Exact"
    
    if (!$appVersionCheck.Found)
    {
        Write-ADTLogEntry -Message "Application not found. Nothing to uninstall."
        Show-ADTInstallationPrompt -Message "DynamicDetectionDemo is not installed. No uninstall needed." -ButtonRightText 'OK' -Icon Information -NoWait
        return
    }
    
    Write-ADTLogEntry -Message "Found application version $($appVersionCheck.CurrentVersion). Proceeding with uninstall."
    
    ## Example 2: Check for dependencies before uninstalling
    Write-ADTLogEntry -Message "=== DEMO: Check for dependencies before uninstalling ==="
    
    $dependencies = @(
        "Microsoft Visual C++ 2015-2022 Redistributable (x64)",
        "Microsoft .NET Framework 4.8"
    )
    
    $dependentApps = @()
    foreach ($dependency in $dependencies)
    {
        $depCheck = Get-ADTApplication -Name $dependency -NameMatch "Exact"
        if ($depCheck.Count -gt 0)
        {
            $dependentApps += $dependency
            Write-ADTLogEntry -Message "Found dependency: $dependency"
        }
    }
    
    if ($dependentApps.Count -gt 0)
    {
        Write-ADTLogEntry -Message "Warning: The following dependencies are still installed: $($dependentApps -join ', ')"
        Write-ADTLogEntry -Message "These may be required by other applications."
    }
    
    ## Example 3: Simulate uninstall
    Write-ADTLogEntry -Message "=== DEMO: Simulate uninstall ==="
    Write-ADTLogEntry -Message "Uninstalling DynamicDetectionDemo..."
    Start-Sleep -Seconds 2
    Write-ADTLogEntry -Message "DynamicDetectionDemo uninstalled successfully"


    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>
    
    ## Example 4: Verify uninstallation
    Write-ADTLogEntry -Message "=== DEMO: Verify uninstallation ==="
    
    $postUninstallCheck = Test-ADTApplicationVersion -ApplicationName "DynamicDetectionDemo" -RequiredVersion "1.0.0" -NameMatch "Exact"
    
    if (!$postUninstallCheck.Found)
    {
        Write-ADTLogEntry -Message "✓ Uninstallation verified: Application no longer found"
    }
    else
    {
        Write-ADTLogEntry -Message "✗ Uninstallation verification failed: Application still found" -Severity 2
    }
    
    Write-ADTLogEntry -Message "Dynamic Detection Demo uninstallation complete."
}

function Repair-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## If there are processes to close, show Welcome Message with a 60 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 60
    }

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Repair tasks here>


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Repair tasks here>
    
    ## DEMO: Dynamic Detection for Repair
    
    ## Example 1: Check current state before repair
    Write-ADTLogEntry -Message "=== DEMO: Check current state before repair ==="
    
    $appVersionCheck = Test-ADTApplicationVersion -ApplicationName "DynamicDetectionDemo" -RequiredVersion "2.1.0" -NameMatch "Exact"
    
    if (!$appVersionCheck.Found)
    {
        Write-ADTLogEntry -Message "Application not found. Reinstalling..."
        ## Simulate reinstallation
        Start-Sleep -Seconds 2
        Write-ADTLogEntry -Message "Application reinstalled successfully"
    }
    elseif ($appVersionCheck.NeedsUpdate)
    {
        Write-ADTLogEntry -Message "Application found but needs update. Current: $($appVersionCheck.CurrentVersion), Required: $($appVersionCheck.RequiredVersion)"
        ## Simulate update
        Start-Sleep -Seconds 2
        Write-ADTLogEntry -Message "Application updated successfully"
    }
    else
    {
        Write-ADTLogEntry -Message "Application is at correct version. Performing repair..."
        ## Simulate repair
        Start-Sleep -Seconds 1
        Write-ADTLogEntry -Message "Application repaired successfully"
    }
    
    ## Example 2: Check and repair dependencies
    Write-ADTLogEntry -Message "=== DEMO: Check and repair dependencies ==="
    
    $dependencies = @(
        "Microsoft Visual C++ 2015-2022 Redistributable (x64)",
        "Microsoft .NET Framework 4.8"
    )
    
    foreach ($dependency in $dependencies)
    {
        $depCheck = Get-ADTApplication -Name $dependency -NameMatch "Exact"
        if ($depCheck.Count -gt 0)
        {
            Write-ADTLogEntry -Message "✓ $dependency is installed: $($depCheck[0].DisplayVersion)"
        }
        else
        {
            Write-ADTLogEntry -Message "✗ $dependency is missing. Installing..."
            ## Simulate dependency installation
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$dependency installed successfully"
        }
    }


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
    
    ## Example 3: Verify repair
    Write-ADTLogEntry -Message "=== DEMO: Verify repair ==="
    
    $postRepairCheck = Test-ADTApplicationVersion -ApplicationName "DynamicDetectionDemo" -RequiredVersion "2.1.0" -NameMatch "Exact"
    
    if ($postRepairCheck.Found -and !$postRepairCheck.NeedsUpdate)
    {
        Write-ADTLogEntry -Message "✓ Repair verified: Application is at correct version $($postRepairCheck.CurrentVersion)"
    }
    else
    {
        Write-ADTLogEntry -Message "✗ Repair verification failed" -Severity 2
    }
    
    Write-ADTLogEntry -Message "Dynamic Detection Demo repair complete."
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    # Import the module locally if available, otherwise try to find it from PSModulePath.
    if (Test-Path -LiteralPath "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -PathType Leaf)
    {
        Get-ChildItem -LiteralPath "$PSScriptRoot\PSAppDeployToolkit" -Recurse -File | Unblock-File -ErrorAction Ignore
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.5' } -Force
    }
    else
    {
        Import-Module -FullyQualifiedName @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.5' } -Force
    }

    # Open a new deployment session, replacing $adtSession with a DeploymentSession.
    $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
    $adtSession = Remove-ADTHashtableNullOrEmptyValues -Hashtable $adtSession
    $adtSession = Open-ADTSession @adtSession @iadtParams -PassThru
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

# Commence the actual deployment operation.
try
{
    # Import any found extensions before proceeding with the deployment.
    Get-ChildItem -LiteralPath $PSScriptRoot -Directory | & {
        process
        {
            if ($_.Name -match 'PSAppDeployToolkit\..+$')
            {
                Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
                Import-Module -Name $_.FullName -Force
            }
        }
    }

    # Invoke the deployment and close out the session.
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    # An unhandled error has been caught.
    $mainErrorMessage = "An unhandled error within [$($MyInvocation.MyCommand.Name)] has occurred.`n$(Resolve-ADTErrorRecord -ErrorRecord $_)"
    Write-ADTLogEntry -Message $mainErrorMessage -Severity 3

    ## Error details hidden from the user by default. Show a simple dialog with full stack trace:
    # Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop -NoWait

    ## Or, a themed dialog with basic error message:
    Show-ADTInstallationPrompt -Message "$($adtSession.DeploymentType) failed at line $($_.InvocationInfo.ScriptLineNumber), char $($_.InvocationInfo.OffsetInLine):`n$($_.InvocationInfo.Line.Trim())`n`nMessage:`n$($_.Exception.Message)" -MessageAlignment Left -ButtonRightText OK -Icon Error -NoWait
    Close-ADTSession -ExitCode 60001
}
