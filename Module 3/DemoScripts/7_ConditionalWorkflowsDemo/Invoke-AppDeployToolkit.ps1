<#

.SYNOPSIS
PSAppDeployToolkit - Conditional Workflows Demo Script

.DESCRIPTION
This script demonstrates real-world examples of conditional workflows:
- Detect if running on laptop vs desktop
- Install VPN client only on laptops
- Conditional installation based on system properties
- Different workflows for different environments

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
    AppName = 'ConditionalWorkflowsDemo'
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

##================================================
## MARK: Conditional Detection Functions
##================================================

function Test-ADTIsLaptop
{
    [CmdletBinding()]
    param()
    
    try
    {
        Write-ADTLogEntry -Message "Detecting if system is a laptop..."
        
        ## Method 1: Check ChassisTypes
        $chassisTypes = Get-WmiObject -Class Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes
        $laptopChassisTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
        
        foreach ($chassisType in $chassisTypes)
        {
            if ($laptopChassisTypes -contains $chassisType)
            {
                Write-ADTLogEntry -Message "Laptop detected via chassis type: $chassisType"
                return $true
            }
        }
        
        ## Method 2: Check for battery
        $battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
        if ($battery)
        {
            Write-ADTLogEntry -Message "Laptop detected via battery presence"
            return $true
        }
        
        ## Method 3: Check for power management
        $powerSchemes = Get-WmiObject -Class Win32_PowerPlan -ErrorAction SilentlyContinue
        if ($powerSchemes)
        {
            Write-ADTLogEntry -Message "Laptop detected via power management"
            return $true
        }
        
        ## Method 4: Check for mobile device indicators
        $mobileDevice = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.Name -like "*mobile*" -or $_.Name -like "*laptop*" }
        if ($mobileDevice)
        {
            Write-ADTLogEntry -Message "Laptop detected via mobile device indicators"
            return $true
        }
        
        Write-ADTLogEntry -Message "Desktop detected"
        return $false
    }
    catch
    {
        Write-ADTLogEntry -Message "Error detecting laptop: $($_.Exception.Message)" -Severity 2
        return $false
    }
}

function Test-ADTIsDomainJoined
{
    [CmdletBinding()]
    param()
    
    try
    {
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $isDomainJoined = $computerSystem.PartOfDomain
        
        Write-ADTLogEntry -Message "Domain joined: $isDomainJoined"
        return $isDomainJoined
    }
    catch
    {
        Write-ADTLogEntry -Message "Error checking domain membership: $($_.Exception.Message)" -Severity 2
        return $false
    }
}

function Test-ADTIsServer
{
    [CmdletBinding()]
    param()
    
    try
    {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $isServer = $os.ProductType -eq 3  # Server
        
        Write-ADTLogEntry -Message "Server OS: $isServer"
        return $isServer
    }
    catch
    {
        Write-ADTLogEntry -Message "Error checking server OS: $($_.Exception.Message)" -Severity 2
        return $false
    }
}

function Test-ADTIsVirtualMachine
{
    [CmdletBinding()]
    param()
    
    try
    {
        ## Check for virtual machine indicators
        $vmIndicators = @(
            "VMware",
            "VirtualBox",
            "Hyper-V",
            "Xen",
            "QEMU",
            "Parallels"
        )
        
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $manufacturer = $computerSystem.Manufacturer
        $model = $computerSystem.Model
        
        foreach ($indicator in $vmIndicators)
        {
            if ($manufacturer -like "*$indicator*" -or $model -like "*$indicator*")
            {
                Write-ADTLogEntry -Message "Virtual machine detected: $manufacturer $model"
                return $true
            }
        }
        
        ## Check for virtual machine services
        $vmServices = Get-WmiObject -Class Win32_Service | Where-Object { $_.Name -like "*vm*" -or $_.Name -like "*virtual*" }
        if ($vmServices)
        {
            Write-ADTLogEntry -Message "Virtual machine detected via services"
            return $true
        }
        
        Write-ADTLogEntry -Message "Physical machine detected"
        return $false
    }
    catch
    {
        Write-ADTLogEntry -Message "Error detecting virtual machine: $($_.Exception.Message)" -Severity 2
        return $false
    }
}

function Test-ADTIsTerminalServer
{
    [CmdletBinding()]
    param()
    
    try
    {
        ## Check for Terminal Server services
        $tsServices = @("TermService", "UmRdpService", "SessionEnv")
        $tsServiceCount = 0
        
        foreach ($serviceName in $tsServices)
        {
            $service = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
            if ($service -and $service.State -eq "Running")
            {
                $tsServiceCount++
            }
        }
        
        if ($tsServiceCount -gt 0)
        {
            Write-ADTLogEntry -Message "Terminal Server detected: $tsServiceCount services running"
            return $true
        }
        
        ## Check for RDP configuration
        $rdpEnabled = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
        if ($rdpEnabled -and $rdpEnabled.fDenyTSConnections -eq 0)
        {
            Write-ADTLogEntry -Message "Terminal Server detected via RDP configuration"
            return $true
        }
        
        Write-ADTLogEntry -Message "Terminal Server not detected"
        return $false
    }
    catch
    {
        Write-ADTLogEntry -Message "Error detecting Terminal Server: $($_.Exception.Message)" -Severity 2
        return $false
    }
}

function Get-ADTSystemEnvironment
{
    [CmdletBinding()]
    param()
    
    try
    {
        $environment = @{
            IsLaptop = Test-ADTIsLaptop
            IsDomainJoined = Test-ADTIsDomainJoined
            IsServer = Test-ADTIsServer
            IsVirtualMachine = Test-ADTIsVirtualMachine
            IsTerminalServer = Test-ADTIsTerminalServer
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            Domain = $env:USERDOMAIN
            OSVersion = [System.Environment]::OSVersion.Version.ToString()
            Architecture = if ([System.Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
        }
        
        return $environment
    }
    catch
    {
        Write-ADTLogEntry -Message "Error getting system environment: $($_.Exception.Message)" -Severity 2
        return @{}
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
    
    ## DEMO: Conditional Workflows Examples
    
    ## Example 1: Detect system environment
    Write-ADTLogEntry -Message "=== DEMO: Detect system environment ==="
    
    $systemEnv = Get-ADTSystemEnvironment
    
    Write-ADTLogEntry -Message "System Environment:"
    Write-ADTLogEntry -Message "  Computer Name: $($systemEnv.ComputerName)"
    Write-ADTLogEntry -Message "  User Name: $($systemEnv.UserName)"
    Write-ADTLogEntry -Message "  Domain: $($systemEnv.Domain)"
    Write-ADTLogEntry -Message "  OS Version: $($systemEnv.OSVersion)"
    Write-ADTLogEntry -Message "  Architecture: $($systemEnv.Architecture)"
    Write-ADTLogEntry -Message "  Is Laptop: $($systemEnv.IsLaptop)"
    Write-ADTLogEntry -Message "  Is Domain Joined: $($systemEnv.IsDomainJoined)"
    Write-ADTLogEntry -Message "  Is Server: $($systemEnv.IsServer)"
    Write-ADTLogEntry -Message "  Is Virtual Machine: $($systemEnv.IsVirtualMachine)"
    Write-ADTLogEntry -Message "  Is Terminal Server: $($systemEnv.IsTerminalServer)"
    
    ## Example 2: Install VPN client only on laptops
    Write-ADTLogEntry -Message "=== DEMO: Install VPN client only on laptops ==="
    
    if ($systemEnv.IsLaptop)
    {
        Write-ADTLogEntry -Message "Laptop detected. Installing VPN client..."
        
        ## Check if VPN client is already installed
        $vpnClient = Get-ADTApplication -Name "VPN Client" -NameMatch "Contains"
        if ($vpnClient.Count -eq 0)
        {
            try
            {
                ## Simulate VPN client installation
                Write-ADTLogEntry -Message "Installing VPN client for laptop..."
                Start-Sleep -Seconds 2
                Write-ADTLogEntry -Message "VPN client installed successfully"
            }
            catch
            {
                Write-ADTLogEntry -Message "Failed to install VPN client: $($_.Exception.Message)" -Severity 2
            }
        }
        else
        {
            Write-ADTLogEntry -Message "VPN client already installed: $($vpnClient[0].DisplayVersion)"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Desktop detected. Skipping VPN client installation."
    }
    
    ## Example 3: Install different components based on domain membership
    Write-ADTLogEntry -Message "=== DEMO: Install different components based on domain membership ==="
    
    if ($systemEnv.IsDomainJoined)
    {
        Write-ADTLogEntry -Message "Domain-joined machine detected. Installing domain-specific components..."
        
        ## Install domain-specific components
        $domainComponents = @(
            "Domain Security Policy",
            "Group Policy Client",
            "Domain Certificate Store"
        )
        
        foreach ($component in $domainComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Workgroup machine detected. Installing workgroup-specific components..."
        
        ## Install workgroup-specific components
        $workgroupComponents = @(
            "Local Security Policy",
            "Standalone Certificate Store",
            "Local User Management"
        )
        
        foreach ($component in $workgroupComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    
    ## Example 4: Install server-specific components
    Write-ADTLogEntry -Message "=== DEMO: Install server-specific components ==="
    
    if ($systemEnv.IsServer)
    {
        Write-ADTLogEntry -Message "Server OS detected. Installing server-specific components..."
        
        ## Install server components
        $serverComponents = @(
            "Server Management Tools",
            "PowerShell ISE",
            "Server Backup Tools"
        )
        
        foreach ($component in $serverComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Client OS detected. Installing client-specific components..."
        
        ## Install client components
        $clientComponents = @(
            "User Interface Components",
            "Desktop Shortcuts",
            "Client Configuration"
        )
        
        foreach ($component in $clientComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    
    ## Example 5: Install virtual machine-specific components
    Write-ADTLogEntry -Message "=== DEMO: Install virtual machine-specific components ==="
    
    if ($systemEnv.IsVirtualMachine)
    {
        Write-ADTLogEntry -Message "Virtual machine detected. Installing VM-specific components..."
        
        ## Install VM components
        $vmComponents = @(
            "VM Tools",
            "VM Configuration",
            "VM Monitoring"
        )
        
        foreach ($component in $vmComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Physical machine detected. Installing physical machine components..."
        
        ## Install physical machine components
        $physicalComponents = @(
            "Hardware Drivers",
            "Physical Security",
            "Hardware Monitoring"
        )
        
        foreach ($component in $physicalComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    
    ## Example 6: Install Terminal Server-specific components
    Write-ADTLogEntry -Message "=== DEMO: Install Terminal Server-specific components ==="
    
    if ($systemEnv.IsTerminalServer)
    {
        Write-ADTLogEntry -Message "Terminal Server detected. Installing TS-specific components..."
        
        ## Install Terminal Server components
        $tsComponents = @(
            "Terminal Server Licensing",
            "Remote Desktop Services",
            "Session Management"
        )
        
        foreach ($component in $tsComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Terminal Server not detected. Skipping TS-specific components."
    }
    
    ## Example 7: Install based on user role
    Write-ADTLogEntry -Message "=== DEMO: Install based on user role ==="
    
    ## Check if current user is administrator
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin)
    {
        Write-ADTLogEntry -Message "Administrator user detected. Installing admin components..."
        
        ## Install admin components
        $adminComponents = @(
            "Administrative Tools",
            "System Configuration",
            "Advanced Settings"
        )
        
        foreach ($component in $adminComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Standard user detected. Installing user components..."
        
        ## Install user components
        $userComponents = @(
            "User Interface",
            "Basic Settings",
            "User Preferences"
        )
        
        foreach ($component in $userComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    
    ## Example 8: Install based on time of day
    Write-ADTLogEntry -Message "=== DEMO: Install based on time of day ==="
    
    $currentHour = (Get-Date).Hour
    
    if ($currentHour -ge 9 -and $currentHour -le 17)
    {
        Write-ADTLogEntry -Message "Business hours detected (9 AM - 5 PM). Installing business components..."
        
        ## Install business components
        $businessComponents = @(
            "Business Applications",
            "Office Integration",
            "Business Security"
        )
        
        foreach ($component in $businessComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "After hours detected. Installing after-hours components..."
        
        ## Install after-hours components
        $afterHoursComponents = @(
            "Maintenance Tools",
            "System Updates",
            "Background Services"
        )
        
        foreach ($component in $afterHoursComponents)
        {
            Write-ADTLogEntry -Message "Installing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component installed successfully"
        }
    }

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>
    
    ## Example 9: Generate conditional installation report
    Write-ADTLogEntry -Message "=== DEMO: Generate conditional installation report ==="
    
    $installationReport = @{
        "Installation Date" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "System Environment" = $systemEnv
        "Components Installed" = @()
    }
    
    ## Add components based on conditions
    if ($systemEnv.IsLaptop)
    {
        $installationReport."Components Installed" += "VPN Client"
    }
    
    if ($systemEnv.IsDomainJoined)
    {
        $installationReport."Components Installed" += "Domain Security Policy", "Group Policy Client", "Domain Certificate Store"
    }
    else
    {
        $installationReport."Components Installed" += "Local Security Policy", "Standalone Certificate Store", "Local User Management"
    }
    
    if ($systemEnv.IsServer)
    {
        $installationReport."Components Installed" += "Server Management Tools", "PowerShell ISE", "Server Backup Tools"
    }
    else
    {
        $installationReport."Components Installed" += "User Interface Components", "Desktop Shortcuts", "Client Configuration"
    }
    
    if ($systemEnv.IsVirtualMachine)
    {
        $installationReport."Components Installed" += "VM Tools", "VM Configuration", "VM Monitoring"
    }
    else
    {
        $installationReport."Components Installed" += "Hardware Drivers", "Physical Security", "Hardware Monitoring"
    }
    
    if ($systemEnv.IsTerminalServer)
    {
        $installationReport."Components Installed" += "Terminal Server Licensing", "Remote Desktop Services", "Session Management"
    }
    
    if ($isAdmin)
    {
        $installationReport."Components Installed" += "Administrative Tools", "System Configuration", "Advanced Settings"
    }
    else
    {
        $installationReport."Components Installed" += "User Interface", "Basic Settings", "User Preferences"
    }
    
    if ($currentHour -ge 9 -and $currentHour -le 17)
    {
        $installationReport."Components Installed" += "Business Applications", "Office Integration", "Business Security"
    }
    else
    {
        $installationReport."Components Installed" += "Maintenance Tools", "System Updates", "Background Services"
    }
    
    Write-ADTLogEntry -Message "Conditional Installation Report:"
    Write-ADTLogEntry -Message "  Installation Date: $($installationReport.'Installation Date')"
    Write-ADTLogEntry -Message "  System Environment:"
    Write-ADTLogEntry -Message "    Is Laptop: $($installationReport.'System Environment'.IsLaptop)"
    Write-ADTLogEntry -Message "    Is Domain Joined: $($installationReport.'System Environment'.IsDomainJoined)"
    Write-ADTLogEntry -Message "    Is Server: $($installationReport.'System Environment'.IsServer)"
    Write-ADTLogEntry -Message "    Is Virtual Machine: $($installationReport.'System Environment'.IsVirtualMachine)"
    Write-ADTLogEntry -Message "    Is Terminal Server: $($installationReport.'System Environment'.IsTerminalServer)"
    Write-ADTLogEntry -Message "  Components Installed:"
    foreach ($component in $installationReport."Components Installed")
    {
        Write-ADTLogEntry -Message "    - $component"
    }

    ## Display a message at the end of the install.
    Show-ADTInstallationPrompt -Message "Conditional Workflows Demo installation complete. Components have been installed based on system conditions." -ButtonRightText 'OK' -Icon Information -NoWait
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
    
    ## DEMO: Conditional Uninstall Examples
    
    ## Example 1: Detect system environment for uninstall
    Write-ADTLogEntry -Message "=== DEMO: Detect system environment for uninstall ==="
    
    $systemEnv = Get-ADTSystemEnvironment
    
    ## Example 2: Uninstall VPN client only on laptops
    Write-ADTLogEntry -Message "=== DEMO: Uninstall VPN client only on laptops ==="
    
    if ($systemEnv.IsLaptop)
    {
        Write-ADTLogEntry -Message "Laptop detected. Uninstalling VPN client..."
        
        $vpnClient = Get-ADTApplication -Name "VPN Client" -NameMatch "Contains"
        if ($vpnClient.Count -gt 0)
        {
            Write-ADTLogEntry -Message "Uninstalling VPN client..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "VPN client uninstalled successfully"
        }
        else
        {
            Write-ADTLogEntry -Message "VPN client not found"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Desktop detected. VPN client was not installed."
    }
    
    ## Example 3: Uninstall domain-specific components
    Write-ADTLogEntry -Message "=== DEMO: Uninstall domain-specific components ==="
    
    if ($systemEnv.IsDomainJoined)
    {
        Write-ADTLogEntry -Message "Domain-joined machine detected. Uninstalling domain-specific components..."
        
        $domainComponents = @(
            "Domain Security Policy",
            "Group Policy Client",
            "Domain Certificate Store"
        )
        
        foreach ($component in $domainComponents)
        {
            Write-ADTLogEntry -Message "Uninstalling $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component uninstalled successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Workgroup machine detected. Uninstalling workgroup-specific components..."
        
        $workgroupComponents = @(
            "Local Security Policy",
            "Standalone Certificate Store",
            "Local User Management"
        )
        
        foreach ($component in $workgroupComponents)
        {
            Write-ADTLogEntry -Message "Uninstalling $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component uninstalled successfully"
        }
    }
    
    ## Example 4: Uninstall server-specific components
    Write-ADTLogEntry -Message "=== DEMO: Uninstall server-specific components ==="
    
    if ($systemEnv.IsServer)
    {
        Write-ADTLogEntry -Message "Server OS detected. Uninstalling server-specific components..."
        
        $serverComponents = @(
            "Server Management Tools",
            "PowerShell ISE",
            "Server Backup Tools"
        )
        
        foreach ($component in $serverComponents)
        {
            Write-ADTLogEntry -Message "Uninstalling $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component uninstalled successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Client OS detected. Uninstalling client-specific components..."
        
        $clientComponents = @(
            "User Interface Components",
            "Desktop Shortcuts",
            "Client Configuration"
        )
        
        foreach ($component in $clientComponents)
        {
            Write-ADTLogEntry -Message "Uninstalling $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component uninstalled successfully"
        }
    }
    
    ## Example 5: Uninstall virtual machine-specific components
    Write-ADTLogEntry -Message "=== DEMO: Uninstall virtual machine-specific components ==="
    
    if ($systemEnv.IsVirtualMachine)
    {
        Write-ADTLogEntry -Message "Virtual machine detected. Uninstalling VM-specific components..."
        
        $vmComponents = @(
            "VM Tools",
            "VM Configuration",
            "VM Monitoring"
        )
        
        foreach ($component in $vmComponents)
        {
            Write-ADTLogEntry -Message "Uninstalling $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component uninstalled successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Physical machine detected. Uninstalling physical machine components..."
        
        $physicalComponents = @(
            "Hardware Drivers",
            "Physical Security",
            "Hardware Monitoring"
        )
        
        foreach ($component in $physicalComponents)
        {
            Write-ADTLogEntry -Message "Uninstalling $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component uninstalled successfully"
        }
    }
    
    ## Example 6: Uninstall Terminal Server-specific components
    Write-ADTLogEntry -Message "=== DEMO: Uninstall Terminal Server-specific components ==="
    
    if ($systemEnv.IsTerminalServer)
    {
        Write-ADTLogEntry -Message "Terminal Server detected. Uninstalling TS-specific components..."
        
        $tsComponents = @(
            "Terminal Server Licensing",
            "Remote Desktop Services",
            "Session Management"
        )
        
        foreach ($component in $tsComponents)
        {
            Write-ADTLogEntry -Message "Uninstalling $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component uninstalled successfully"
        }
    }
    else
    {
        Write-ADTLogEntry -Message "Terminal Server not detected. TS-specific components were not installed."
    }


    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>
    
    ## Example 7: Verify conditional uninstallation
    Write-ADTLogEntry -Message "=== DEMO: Verify conditional uninstallation ==="
    
    $mainApp = Get-ADTApplication -Name "ConditionalWorkflowsDemo" -NameMatch "Exact"
    if ($mainApp.Count -eq 0)
    {
        Write-ADTLogEntry -Message "✓ Main application uninstalled successfully"
    }
    else
    {
        Write-ADTLogEntry -Message "✗ Main application still present" -Severity 2
    }
    
    Write-ADTLogEntry -Message "Conditional Workflows Demo uninstallation complete."
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
    
    ## DEMO: Conditional Repair Examples
    
    ## Example 1: Detect system environment for repair
    Write-ADTLogEntry -Message "=== DEMO: Detect system environment for repair ==="
    
    $systemEnv = Get-ADTSystemEnvironment
    
    ## Example 2: Repair based on system type
    Write-ADTLogEntry -Message "=== DEMO: Repair based on system type ==="
    
    if ($systemEnv.IsLaptop)
    {
        Write-ADTLogEntry -Message "Laptop detected. Repairing laptop-specific components..."
        
        $vpnClient = Get-ADTApplication -Name "VPN Client" -NameMatch "Contains"
        if ($vpnClient.Count -gt 0)
        {
            Write-ADTLogEntry -Message "Repairing VPN client..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "VPN client repaired successfully"
        }
        else
        {
            Write-ADTLogEntry -Message "VPN client not found. Reinstalling..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "VPN client reinstalled successfully"
        }
    }
    
    ## Example 3: Repair domain-specific components
    Write-ADTLogEntry -Message "=== DEMO: Repair domain-specific components ==="
    
    if ($systemEnv.IsDomainJoined)
    {
        Write-ADTLogEntry -Message "Domain-joined machine detected. Repairing domain-specific components..."
        
        $domainComponents = @(
            "Domain Security Policy",
            "Group Policy Client",
            "Domain Certificate Store"
        )
        
        foreach ($component in $domainComponents)
        {
            Write-ADTLogEntry -Message "Repairing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component repaired successfully"
        }
    }
    
    ## Example 4: Repair server-specific components
    Write-ADTLogEntry -Message "=== DEMO: Repair server-specific components ==="
    
    if ($systemEnv.IsServer)
    {
        Write-ADTLogEntry -Message "Server OS detected. Repairing server-specific components..."
        
        $serverComponents = @(
            "Server Management Tools",
            "PowerShell ISE",
            "Server Backup Tools"
        )
        
        foreach ($component in $serverComponents)
        {
            Write-ADTLogEntry -Message "Repairing $component..."
            Start-Sleep -Seconds 1
            Write-ADTLogEntry -Message "$component repaired successfully"
        }
    }


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
    
    ## Example 5: Verify repair
    Write-ADTLogEntry -Message "=== DEMO: Verify repair ==="
    
    $mainApp = Get-ADTApplication -Name "ConditionalWorkflowsDemo" -NameMatch "Exact"
    if ($mainApp.Count -gt 0)
    {
        Write-ADTLogEntry -Message "✓ Main application is installed and working"
    }
    else
    {
        Write-ADTLogEntry -Message "✗ Main application not found. Reinstalling..."
        Start-Sleep -Seconds 1
        Write-ADTLogEntry -Message "Main application reinstalled successfully"
    }
    
    Write-ADTLogEntry -Message "Conditional Workflows Demo repair complete."
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
