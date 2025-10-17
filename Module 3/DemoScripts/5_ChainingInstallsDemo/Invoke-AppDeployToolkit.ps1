<#

.SYNOPSIS
PSAppDeployToolkit - Chaining Installs Demo Script

.DESCRIPTION
This script demonstrates real-world examples of chaining installs with VC++ runtimes as dependencies:
- Install VC++ runtimes as prerequisites
- Chain multiple installations in sequence
- Handle dependency failures gracefully
- Install main application after dependencies

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
    AppName = 'ChainingInstallsDemo'
    AppVersion = '1.0.0'
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
    
    ## DEMO: Chaining Installs Examples
    
    ## Example 1: Check for VC++ runtimes and install if missing
    Write-ADTLogEntry -Message "=== DEMO: Check for VC++ runtimes and install if missing ==="
    
    ## Check for VC++ 2015-2022 x64 runtime
    $vcRuntime2015_2022_x64 = Get-ADTApplication -Name "Microsoft Visual C++ 2015-2022 Redistributable (x64)" -NameMatch "Exact"
    if ($vcRuntime2015_2022_x64.Count -eq 0)
    {
        Write-ADTLogEntry -Message "VC++ 2015-2022 x64 runtime not found. Installing..."
        try
        {
            ## Simulate VC++ runtime installation
            Write-ADTLogEntry -Message "Installing VC++ 2015-2022 x64 runtime..."
            Start-Sleep -Seconds 2
            Write-ADTLogEntry -Message "VC++ 2015-2022 x64 runtime installed successfully"
        }
        catch
        {
            Write-ADTLogEntry -Message "Failed to install VC++ 2015-2022 x64 runtime: $($_.Exception.Message)" -Severity 3
            throw "VC++ runtime installation failed"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "VC++ 2015-2022 x64 runtime already installed: $($vcRuntime2015_2022_x64[0].DisplayVersion)"
    }
    
    ## Check for VC++ 2015-2022 x86 runtime
    $vcRuntime2015_2022_x86 = Get-ADTApplication -Name "Microsoft Visual C++ 2015-2022 Redistributable (x86)" -NameMatch "Exact"
    if ($vcRuntime2015_2022_x86.Count -eq 0)
    {
        Write-ADTLogEntry -Message "VC++ 2015-2022 x86 runtime not found. Installing..."
        try
        {
            ## Simulate VC++ runtime installation
            Write-ADTLogEntry -Message "Installing VC++ 2015-2022 x86 runtime..."
            Start-Sleep -Seconds 2
            Write-ADTLogEntry -Message "VC++ 2015-2022 x86 runtime installed successfully"
        }
        catch
        {
            Write-ADTLogEntry -Message "Failed to install VC++ 2015-2022 x86 runtime: $($_.Exception.Message)" -Severity 3
            throw "VC++ runtime installation failed"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "VC++ 2015-2022 x86 runtime already installed: $($vcRuntime2015_2022_x86[0].DisplayVersion)"
    }
    
    ## Example 2: Install .NET Framework if missing
    Write-ADTLogEntry -Message "=== DEMO: Install .NET Framework if missing ==="
    
    ## Check for .NET Framework 4.8
    $dotNet48 = Get-ADTApplication -Name "Microsoft .NET Framework 4.8" -NameMatch "Exact"
    if ($dotNet48.Count -eq 0)
    {
        Write-ADTLogEntry -Message ".NET Framework 4.8 not found. Installing..."
        try
        {
            ## Simulate .NET Framework installation
            Write-ADTLogEntry -Message "Installing .NET Framework 4.8..."
            Start-Sleep -Seconds 3
            Write-ADTLogEntry -Message ".NET Framework 4.8 installed successfully"
        }
        catch
        {
            Write-ADTLogEntry -Message "Failed to install .NET Framework 4.8: $($_.Exception.Message)" -Severity 3
            throw ".NET Framework installation failed"
        }
    }
    else
    {
        Write-ADTLogEntry -Message ".NET Framework 4.8 already installed: $($dotNet48[0].DisplayVersion)"
    }
    
    ## Example 3: Install Windows Updates if required
    Write-ADTLogEntry -Message "=== DEMO: Install Windows Updates if required ==="
    
    ## Check for specific Windows updates
    $requiredUpdates = @(
        "KB5005565",  # Windows 10/11 update
        "KB5006670"   # Security update
    )
    
    foreach ($update in $requiredUpdates)
    {
        $installedUpdate = Get-ADTApplication -Name $update -NameMatch "Contains"
        if ($installedUpdate.Count -eq 0)
        {
            Write-ADTLogEntry -Message "Windows Update $update not found. Installing..."
            try
            {
                ## Simulate Windows Update installation
                Write-ADTLogEntry -Message "Installing Windows Update $update..."
                Start-Sleep -Seconds 1
                Write-ADTLogEntry -Message "Windows Update $update installed successfully"
            }
            catch
            {
                Write-ADTLogEntry -Message "Failed to install Windows Update $update: $($_.Exception.Message)" -Severity 2
                ## Continue with other updates
            }
        }
        else
        {
            Write-ADTLogEntry -Message "Windows Update $update already installed"
        }
    }
    
    ## Example 4: Install main application after dependencies
    Write-ADTLogEntry -Message "=== DEMO: Install main application after dependencies ==="
    
    ## Check if main application is already installed
    $mainApp = Get-ADTApplication -Name "ChainingInstallsDemo" -NameMatch "Exact"
    if ($mainApp.Count -eq 0)
    {
        Write-ADTLogEntry -Message "Main application not found. Installing..."
        try
        {
            ## Simulate main application installation
            Write-ADTLogEntry -Message "Installing main application..."
            Start-Sleep -Seconds 2
            Write-ADTLogEntry -Message "Main application installed successfully"
        }
        catch
        {
            Write-ADTLogEntry -Message "Failed to install main application: $($_.Exception.Message)" -Severity 3
            throw "Main application installation failed"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Main application already installed: $($mainApp[0].DisplayVersion)"
    }
    
    ## Example 5: Install additional components based on system requirements
    Write-ADTLogEntry -Message "=== DEMO: Install additional components based on system requirements ==="
    
    ## Check system architecture and install appropriate components
    if ([System.Environment]::Is64BitOperatingSystem)
    {
        Write-ADTLogEntry -Message "64-bit operating system detected. Installing 64-bit components..."
        
        ## Check for 64-bit specific components
        $x64Component = Get-ADTApplication -Name "64-bit Component" -NameMatch "Contains"
        if ($x64Component.Count -eq 0)
        {
            Write-ADTLogEntry -Message "Installing 64-bit component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "64-bit component installed successfully"
        }
        else
        {
            Write-ADTLogEntry -Message "64-bit component already installed"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "32-bit operating system detected. Installing 32-bit components..."
        
        ## Check for 32-bit specific components
        $x86Component = Get-ADTApplication -Name "32-bit Component" -NameMatch "Contains"
        if ($x86Component.Count -eq 0)
        {
            Write-ADTLogEntry -Message "Installing 32-bit component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "32-bit component installed successfully"
        }
        else
        {
            Write-ADTLogEntry -Message "32-bit component already installed"
        }
    }
    
    ## Example 6: Install language packs based on system locale
    Write-ADTLogEntry -Message "=== DEMO: Install language packs based on system locale ==="
    
    ## Get system locale
    $systemLocale = [System.Globalization.CultureInfo]::CurrentCulture.Name
    Write-ADTLogEntry -Message "System locale: $systemLocale"
    
    ## Install language pack if not English
    if ($systemLocale -ne "en-US")
    {
        $languagePack = Get-ADTApplication -Name "Language Pack $systemLocale" -NameMatch "Contains"
        if ($languagePack.Count -eq 0)
        {
            Write-ADTLogEntry -Message "Installing language pack for $systemLocale..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "Language pack for $systemLocale installed successfully"
        }
        else
        {
            Write-ADTLogEntry -Message "Language pack for $systemLocale already installed"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "English locale detected. No additional language pack needed"
    }

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>
    
    ## Example 7: Verify all dependencies are installed
    Write-ADTLogEntry -Message "=== DEMO: Verify all dependencies are installed ==="
    
    $dependencies = @(
        "Microsoft Visual C++ 2015-2022 Redistributable (x64)",
        "Microsoft Visual C++ 2015-2022 Redistributable (x86)",
        "Microsoft .NET Framework 4.8"
    )
    
    $allDependenciesInstalled = $true
    foreach ($dependency in $dependencies)
    {
        $installedDependency = Get-ADTApplication -Name $dependency -NameMatch "Exact"
        if ($installedDependency.Count -gt 0)
        {
            Write-ADTLogEntry -Message "✓ $dependency is installed: $($installedDependency[0].DisplayVersion)"
        }
        else
        {
            Write-ADTLogEntry -Message "✗ $dependency is NOT installed" -Severity 2
            $allDependenciesInstalled = $false
        }
    }
    
    if ($allDependenciesInstalled)
    {
        Write-ADTLogEntry -Message "All dependencies are installed successfully"
    }
    else
    {
        Write-ADTLogEntry -Message "Some dependencies are missing" -Severity 2
    }
    
    ## Example 8: Create dependency report
    Write-ADTLogEntry -Message "=== DEMO: Create dependency report ==="
    
    $dependencyReport = @{
        "Installation Date" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "System Architecture" = if ([System.Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
        "System Locale" = [System.Globalization.CultureInfo]::CurrentCulture.Name
        "Dependencies" = @()
    }
    
    foreach ($dependency in $dependencies)
    {
        $installedDependency = Get-ADTApplication -Name $dependency -NameMatch "Exact"
        if ($installedDependency.Count -gt 0)
        {
            $dependencyReport.Dependencies += @{
                "Name" = $dependency
                "Version" = $installedDependency[0].DisplayVersion
                "Status" = "Installed"
            }
        }
        else
        {
            $dependencyReport.Dependencies += @{
                "Name" = $dependency
                "Version" = "N/A"
                "Status" = "Missing"
            }
        }
    }
    
    Write-ADTLogEntry -Message "Dependency Report:"
    Write-ADTLogEntry -Message "  Installation Date: $($dependencyReport.'Installation Date')"
    Write-ADTLogEntry -Message "  System Architecture: $($dependencyReport.'System Architecture')"
    Write-ADTLogEntry -Message "  System Locale: $($dependencyReport.'System Locale')"
    Write-ADTLogEntry -Message "  Dependencies:"
    foreach ($dep in $dependencyReport.Dependencies)
    {
        Write-ADTLogEntry -Message "    - $($dep.Name): $($dep.Version) ($($dep.Status))"
    }

    ## Display a message at the end of the install.
    Show-ADTInstallationPrompt -Message "Chaining Installs Demo installation complete. All dependencies have been installed and verified." -ButtonRightText 'OK' -Icon Information -NoWait
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
    
    ## DEMO: Chaining Uninstall Examples
    
    ## Example 1: Uninstall main application first
    Write-ADTLogEntry -Message "=== DEMO: Uninstall main application first ==="
    
    $mainApp = Get-ADTApplication -Name "ChainingInstallsDemo" -NameMatch "Exact"
    if ($mainApp.Count -gt 0)
    {
        Write-ADTLogEntry -Message "Uninstalling main application..."
        try
        {
            ## Simulate main application uninstallation
            Write-ADTLogEntry -Message "Main application uninstalled successfully"
        }
        catch
        {
            Write-ADTLogEntry -Message "Failed to uninstall main application: $($_.Exception.Message)" -Severity 2
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Main application not found"
    }
    
    ## Example 2: Uninstall additional components
    Write-ADTLogEntry -Message "=== DEMO: Uninstall additional components ==="
    
    ## Uninstall 64-bit component if installed
    $x64Component = Get-ADTApplication -Name "64-bit Component" -NameMatch "Contains"
    if ($x64Component.Count -gt 0)
    {
        Write-ADTLogEntry -Message "Uninstalling 64-bit component..."
        try
        {
            ## Simulate component uninstallation
            Write-ADTLogEntry -Message "64-bit component uninstalled successfully"
        }
        catch
        {
            Write-ADTLogEntry -Message "Failed to uninstall 64-bit component: $($_.Exception.Message)" -Severity 2
        }
    }
    
    ## Uninstall 32-bit component if installed
    $x86Component = Get-ADTApplication -Name "32-bit Component" -NameMatch "Contains"
    if ($x86Component.Count -gt 0)
    {
        Write-ADTLogEntry -Message "Uninstalling 32-bit component..."
        try
        {
            ## Simulate component uninstallation
            Write-ADTLogEntry -Message "32-bit component uninstalled successfully"
        }
        catch
        {
            Write-ADTLogEntry -Message "Failed to uninstall 32-bit component: $($_.Exception.Message)" -Severity 2
        }
    }
    
    ## Example 3: Uninstall language packs
    Write-ADTLogEntry -Message "=== DEMO: Uninstall language packs ==="
    
    $systemLocale = [System.Globalization.CultureInfo]::CurrentCulture.Name
    if ($systemLocale -ne "en-US")
    {
        $languagePack = Get-ADTApplication -Name "Language Pack $systemLocale" -NameMatch "Contains"
        if ($languagePack.Count -gt 0)
        {
            Write-ADTLogEntry -Message "Uninstalling language pack for $systemLocale..."
            try
            {
                ## Simulate language pack uninstallation
                Write-ADTLogEntry -Message "Language pack for $systemLocale uninstalled successfully"
            }
            catch
            {
                Write-ADTLogEntry -Message "Failed to uninstall language pack for $systemLocale: $($_.Exception.Message)" -Severity 2
            }
        }
    }
    
    ## Example 4: Note about keeping dependencies
    Write-ADTLogEntry -Message "=== DEMO: Note about keeping dependencies ==="
    Write-ADTLogEntry -Message "Note: VC++ runtimes and .NET Framework are kept installed as they may be required by other applications"
    Write-ADTLogEntry -Message "To remove them, use separate uninstall scripts or manual removal"


    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>
    
    ## Example 5: Verify uninstallation
    Write-ADTLogEntry -Message "=== DEMO: Verify uninstallation ==="
    
    $mainApp = Get-ADTApplication -Name "ChainingInstallsDemo" -NameMatch "Exact"
    if ($mainApp.Count -eq 0)
    {
        Write-ADTLogEntry -Message "Main application successfully uninstalled"
    }
    else
    {
        Write-ADTLogEntry -Message "Main application still present after uninstall attempt" -Severity 2
    }
    
    Write-ADTLogEntry -Message "Chaining Installs Demo uninstallation complete."
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
    
    ## DEMO: Chaining Repair Examples
    
    ## Example 1: Check and repair dependencies
    Write-ADTLogEntry -Message "=== DEMO: Check and repair dependencies ==="
    
    $dependencies = @(
        "Microsoft Visual C++ 2015-2022 Redistributable (x64)",
        "Microsoft Visual C++ 2015-2022 Redistributable (x86)",
        "Microsoft .NET Framework 4.8"
    )
    
    foreach ($dependency in $dependencies)
    {
        $installedDependency = Get-ADTApplication -Name $dependency -NameMatch "Exact"
        if ($installedDependency.Count -gt 0)
        {
            Write-ADTLogEntry -Message "✓ $dependency is installed: $($installedDependency[0].DisplayVersion)"
        }
        else
        {
            Write-ADTLogEntry -Message "✗ $dependency is missing. Reinstalling..."
            try
            {
                ## Simulate dependency repair
                Write-ADTLogEntry -Message "Repairing $dependency..."
                Start-Sleep -Seconds 1
                Write-ADTLogEntry -Message "$dependency repaired successfully"
            }
            catch
            {
                Write-ADTLogEntry -Message "Failed to repair $dependency: $($_.Exception.Message)" -Severity 2
            }
        }
    }
    
    ## Example 2: Repair main application
    Write-ADTLogEntry -Message "=== DEMO: Repair main application ==="
    
    $mainApp = Get-ADTApplication -Name "ChainingInstallsDemo" -NameMatch "Exact"
    if ($mainApp.Count -gt 0)
    {
        Write-ADTLogEntry -Message "Repairing main application..."
        try
        {
            ## Simulate main application repair
            Write-ADTLogEntry -Message "Main application repaired successfully"
        }
        catch
        {
            Write-ADTLogEntry -Message "Failed to repair main application: $($_.Exception.Message)" -Severity 2
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Main application not found. Reinstalling..."
        try
        {
            ## Simulate main application reinstallation
            Write-ADTLogEntry -Message "Main application reinstalled successfully"
        }
        catch
        {
            Write-ADTLogEntry -Message "Failed to reinstall main application: $($_.Exception.Message)" -Severity 2
        }
    }


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
    
    ## Example 3: Verify repair
    Write-ADTLogEntry -Message "=== DEMO: Verify repair ==="
    
    $allComponentsInstalled = $true
    $components = @(
        "ChainingInstallsDemo",
        "Microsoft Visual C++ 2015-2022 Redistributable (x64)",
        "Microsoft Visual C++ 2015-2022 Redistributable (x86)",
        "Microsoft .NET Framework 4.8"
    )
    
    foreach ($component in $components)
    {
        $installedComponent = Get-ADTApplication -Name $component -NameMatch "Exact"
        if ($installedComponent.Count -gt 0)
        {
            Write-ADTLogEntry -Message "✓ $component is installed: $($installedComponent[0].DisplayVersion)"
        }
        else
        {
            Write-ADTLogEntry -Message "✗ $component is NOT installed" -Severity 2
            $allComponentsInstalled = $false
        }
    }
    
    if ($allComponentsInstalled)
    {
        Write-ADTLogEntry -Message "All components are installed and working correctly"
    }
    else
    {
        Write-ADTLogEntry -Message "Some components are missing or need attention" -Severity 2
    }
    
    Write-ADTLogEntry -Message "Chaining Installs Demo repair complete."
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
