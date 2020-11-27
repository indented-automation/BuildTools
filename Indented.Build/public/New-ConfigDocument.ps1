function New-ConfigDocument {
    <#
    .SYNOPSIS
        Create a new build configuration document
    .DESCRIPTION
        The build configuration document may be used to adjust the configurable build values for a single module.

        This file is optional, without it the following default values will be used:

          - CodeCoverageThreshold: 0.8 (80%)
          - EndOfLineChar: [Environment]::NewLine
          - License: MIT
          - CreateChocoPackage: $false
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        # BuildInfo is used to determine the source path.
        [Parameter(ValueFromPipeline)]
        [PSTypeName('Indented.BuildInfo')]
        $BuildInfo = (Get-BuildInfo)
    )

    process {
        $documentPath = Join-Path -Path $BuildInfo.Path.Source.Module -ChildPath 'buildConfig.psd1'

        $eolChar = switch -Regex ([Environment]::NewLine) {
            '\r\n' { '`r`n'; break }
            '\n'   { '`n'; break }
            '\r'   { '`r'; break }
        }

        # Build configuration for Indented.Build
        @(
            '@{'
            '    CodeCoverageThreshold = 0.8'
            ('    EndOfLineChar         = "{0}"' -f $eolChar)
            "    License               = 'MIT'"
            '    CreateChocoPackage    = $false'
            '}'
        ) | Set-Content -Path $documentPath
    }
}
