# Module 4 Demos: Upgrading from v3 to v4

This folder contains demonstration scripts for Module 4 of the PSADT v4 Essentials training course, focusing on migrating from PSADT v3 to v4.

## Demos Included

### 1. v3 Sample Package (BEFORE Migration)
**File:** `1_v3_Sample_BEFORE_Migration.ps1`

**Purpose:** Shows a typical v3-style deployment script that needs to be migrated to v4.

**Key Features:**
- v3 function naming conventions
- v3 variable patterns ($dirFiles, $dirSupportFiles)
- v3 parameter handling
- v3 error handling patterns
- v3 configuration approach

**Learning Objectives:**
- Understand v3 script structure
- Identify v3-specific patterns
- Recognize elements that need migration
- Establish a baseline for comparison

**Notes:**
- This script uses v3 syntax and function names
- Many functions are commented out as they are v3-only
- Used as a reference for "before" state

---

### 2. v4 Migrated Package (AFTER Migration)
**File:** `2_v4_Migrated_AFTER_Migration.ps1`

**Purpose:** Shows the same deployment migrated to v4 with all modern patterns.

**Key Features:**
- v4 function naming (ADT prefix)
- v4 variable patterns ($env:ADT_*)
- v4 parameter improvements (switch parameters)
- v4 error handling (native PowerShell try/catch)
- v4 session-based configuration
- Comprehensive inline documentation of changes

**Learning Objectives:**
- Understand v4 script structure
- See direct before/after comparison
- Learn the migration patterns
- Implement v4 best practices

**To Run:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\2_v4_Migrated_AFTER_Migration.ps1 -DeploymentType Install -DeployMode Interactive
```

---

## Side-by-Side Comparison

### Function Name Changes

| v3 Function | v4 Function |
|------------|------------|
| `Show-InstallationWelcome` | `Show-ADTInstallationWelcome` |
| `Show-InstallationProgress` | `Show-ADTInstallationProgress` |
| `Show-InstallationPrompt` | `Show-ADTInstallationPrompt` |
| `Execute-Process` | `Start-ADTProcess` |
| `Execute-MSI` | `Start-ADTMsiProcess` |
| `Write-Log` | `Write-ADTLogEntry` |
| `Copy-File` | `Copy-ADTFile` |
| `Remove-File` | `Remove-ADTFile` |
| `Set-RegistryKey` | `Set-ADTRegistryKey` |
| `Remove-RegistryKey` | `Remove-ADTRegistryKey` |
| `Get-InstalledApplication` | `Get-ADTApplication` |
| `Remove-MSIApplications` | `Uninstall-ADTApplication` |
| `Invoke-HKCURegistrySettingsForAllUsers` | `Invoke-ADTAllUsersRegistryAction` |
| `Exit-Script` | `Close-ADTSession` |
| `Resolve-Error` | `Resolve-ADTErrorRecord` |

### Variable Changes

| v3 Variable | v4 Variable |
|------------|------------|
| `$dirFiles` | `$env:ADT_DirFiles` |
| `$dirSupportFiles` | `$env:ADT_DirSupportFiles` |
| `$envProgramFiles` | `$env:ProgramFiles` |
| `$configToolkitLogDir` | `$env:ADT_LogDir` |
| Global variables | Session-based (`$adtSession`) |

### Parameter Changes

| v3 Parameter | v4 Parameter | Change Type |
|-------------|-------------|-------------|
| `-ContinueOnError $true` | `-ErrorAction SilentlyContinue` | Native PowerShell |
| `-AllowRebootPassThru $true` | `-SuppressRebootPassThru` | Inverted switch |
| Various boolean `-Parameter $true` | `-Parameter` (switch) | Switch parameter |

### Configuration Changes

| v3 | v4 |
|----|-----|
| `AppDeployToolkitConfig.xml` | `Config\config.psd1` |
| Embedded strings in XML | `Strings\strings.psd1` |
| Banner image in root | `Assets\AppIcon.png` |
| `Deploy-Application.ps1` | `Invoke-AppDeployToolkit.ps1` |

---

## Migration Checklist

Use this checklist when migrating your own v3 packages:

### Step 1: Preparation
- [ ] Backup your v3 package
- [ ] Document current functionality
- [ ] Test v3 package to establish baseline
- [ ] Review v3 script for custom code
- [ ] Note all v3 functions used

### Step 2: Template Setup
- [ ] Create new v4 template folder
- [ ] Copy Files folder contents
- [ ] Copy SupportFiles folder contents
- [ ] Copy/convert banner to AppIcon.png

### Step 3: Script Migration
- [ ] Rename Deploy-Application.ps1 to Invoke-AppDeployToolkit.ps1
- [ ] Update parameter block (see v4 example)
- [ ] Convert variables to session hashtable
- [ ] Replace all function names (use mapping table)
- [ ] Update variable references ($dirFiles → $env:ADT_DirFiles)
- [ ] Convert error handling to try/catch/finally
- [ ] Update parameter usage (booleans → switches)

### Step 4: Configuration Migration
- [ ] Extract config.xml values to config.psd1
- [ ] Extract UI strings to strings.psd1
- [ ] Update banner/logo references
- [ ] Remove ServiceUI references

### Step 5: Testing
- [ ] Test Install in Interactive mode
- [ ] Test Install in Silent mode
- [ ] Test Uninstall in Interactive mode
- [ ] Test Uninstall in Silent mode
- [ ] Verify log files are created
- [ ] Check exit codes (0, 3010, etc.)
- [ ] Validate UI appearance and branding

### Step 6: Validation
- [ ] Compare behavior with v3 baseline
- [ ] Verify all features work
- [ ] Check for any error messages
- [ ] Review log files for completeness
- [ ] Test with SCCM/Intune if applicable

---

## Prerequisites

- Windows 10/11 with PowerShell 5.1 or later
- PSAppDeployToolkit v4.1 module
- Administrative rights
- Visual Studio Code (recommended)
- Access to both v3 and v4 documentation

## Migration Tools

### Automated Conversion (Optional)

PSADT v4 includes tools to assist with migration:

```powershell
# Install PSAppDeployToolkit.Tools module
Install-Module -Name PSAppDeployToolkit.Tools

# Test compatibility of v3 script
Test-ADTCompatibility -Path ".\Deploy-Application.ps1"

# Auto-convert v3 to v4
Convert-ADTDeployment -Path ".\Deploy-Application.ps1" -OutputPath ".\v4_converted"
```

**Note:** Always review auto-converted scripts and test thoroughly.

## Common Migration Issues

### Issue 1: Function Not Found
**Symptom:** Error about command not being recognized
**Solution:** Check function name mapping table, ensure ADT prefix is used

### Issue 2: Variable Not Set
**Symptom:** Empty or null variable references
**Solution:** Update to $env:ADT_* format or use $adtSession values

### Issue 3: Parameter Error
**Symptom:** Cannot bind parameter error
**Solution:** Check for boolean → switch parameter changes

### Issue 4: ServiceUI References
**Symptom:** Script tries to use ServiceUI.exe
**Solution:** Remove all ServiceUI references, v4 handles user context natively

### Issue 5: Config Not Applied
**Symptom:** Settings from old config.xml not working
**Solution:** Migrate settings to config.psd1 format

## Best Practices

1. **Start Small:** Migrate simple packages first to build confidence
2. **Document Changes:** Keep notes on what you change and why
3. **Test Thoroughly:** Test all deployment scenarios
4. **Use Version Control:** Track changes with Git or similar
5. **Phased Rollout:** Deploy to test groups before production
6. **Keep v3 Backup:** Retain working v3 package until v4 is proven

## Lab Exercise

### Part 1: Analysis
1. Open `1_v3_Sample_BEFORE_Migration.ps1`
2. Identify all v3 function calls
3. List all variables that need changing
4. Note any custom code or logic

### Part 2: Comparison
1. Open both scripts side-by-side
2. Find each v3 function in the BEFORE script
3. Locate its v4 equivalent in the AFTER script
4. Note the differences

### Part 3: Migration Practice
1. Take a copy of the BEFORE script
2. Manually migrate it to v4 using the checklist
3. Compare your result with the AFTER script
4. Test your migrated version

## Additional Resources

- **v3 to v4 Upgrade Guide:** https://psappdeploytoolkit.com/docs/getting-started/upgrade-guidance-v3x-to-v41
- **Function Reference:** https://psappdeploytoolkit.com/docs/reference/functions
- **Migration Tools Documentation:** https://github.com/PSAppDeployToolkit/PSAppDeployToolkit.Tools
- **Community Examples:** PSADT Discourse and GitHub Discussions

## Support

If you encounter issues during migration:
- Check the v4 documentation for function details
- Review the migration guide
- Post questions on the PSADT Discourse forum
- Check GitHub issues for similar problems

---

**Module 4 Training Goals:**
By completing this module, you will be able to confidently migrate any v3 PSADT package to v4, understanding all the key changes and improvements in the new version.
