BuildTask UpdateRequiredModules -Stage Setup -Order 1 -Definition {
    # Installs the modules required to execute the tasks in this script into current user scope.

    $erroractionpreference = 'Stop'
    try {
        if (Get-Module PSDepend -ListAvailable) {
            Update-Module PSDepend -ErrorAction SilentlyContinue
        } else {
            Install-Module PSDepend -Scope CurrentUser
        }
        Invoke-PSDepend -Install -Import -Force -InputObject @{
            PSDependOptions = @{
                Target    = 'CurrentUser'
            }

            Configuration    = '1.3.1'
            Pester           = '5.1.0'
            PlatyPS          = '0.14.0'
            PSScriptAnalyzer = '1.19.1'
        }
    } catch {
        throw
    }
}
