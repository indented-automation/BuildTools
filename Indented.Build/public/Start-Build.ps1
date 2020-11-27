function Start-Build {
    <#
    .SYNOPSIS
        Start a build.
    .DESCRIPTION
        Start a build using Invoke-Build. If a build script is not present one will be created.

        If a build script exists it will be used. If the build script exists this command is superfluous.
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
    [CmdletBinding()]
    param (
        # The task categories to execute.
        [String[]]$BuildType = ('Setup', 'Build', 'Test'),

        [Parameter(ValueFromPipeline)]
        [PSTypeName('Indented.BuildInfo')]
        [PSObject[]]$BuildInfo = (Get-BuildInfo),

        [String]$ScriptName = '.build.ps1'
    )

    process {
        foreach ($instance in $BuildInfo) {
            try {
                # If a build script exists in the project root, use it.
                $buildScript = Join-Path -Path $instance.Path.ProjectRoot -ChildPath $ScriptName

                Write-Host $buildScript

                # Remove the script if it is created by this process. Export-BuildScript can be used to create a persistent script.
                $shouldClean = $false
                if (-not (Test-Path $buildScript)) {
                    Write-Host 'Exporting build script'

                    $instance | Export-BuildScript -Path $buildScript
                    $shouldClean = $true
                }

                Write-Host 'Executing build'
                Invoke-Build -Task $BuildType -File $buildScript -BuildInfo $instance
            } catch {
                throw
            } finally {
                if ($shouldClean) {
                    Remove-Item $buildScript
                }
            }
        }
    }
}
