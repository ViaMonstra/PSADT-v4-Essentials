# Exercise 5 – Working With Shortcuts

# Show help console 
Show-ADTHelpConsole

# For variables help
https://psappdeploytoolkit.com/docs/reference/variables

# Get the session variables
Open-ADTSession

# New Shortcut for Notepad++
$Params = @{
    'LiteralPath'      = "$envCommonDesktop\Notepad++.lnk"
    'TargetPath'       = "$envProgramFiles\Notepad++\notepad++.exe"
    'IconLocation'     = "$envProgramFiles\Notepad++\notepad++.exe"
    'Description'      = "Notepad++"
    'WorkingDirectory' = "$envProgramFiles\Notepad++\"
}
New-ADTShortcut @Params

# Get the Notepad++ shortcut
Get-ADTShortcut -LiteralPath "$envCommonDesktop\Notepad++.lnk"

# Create an URL shortcut to PSADT documentation
$Params = @{
    'LiteralPath'   = "$envCommonDesktop\PSADT Docs.lnk"
    'TargetPath'    = "https://psappdeploytoolkit.com/docs/introduction"
    'IconLocation'  = "$envProgramFilesX86\Microsoft\Edge\Application\msedge.exe"
    'Description'   = "The DOCS are pretty cool" # Will be comment on the shortcut
}
New-ADTShortcut @Params

