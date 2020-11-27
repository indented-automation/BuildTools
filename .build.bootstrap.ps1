# Provides a build of the module with minimal validation / discovery.

task Build GetBuildInfo,
           UpdateRequiredModules,
           Clean,
           CopyModuleFiles,
           Merge,
           UpdateMetadata,
           UpdateBuildScript

function Get-BuildItem {
    <#
    .SYNOPSIS
        Get source items.
    .DESCRIPTION
        Get items from the source tree which will be consumed by the build process.

        This function centralises the logic required to enumerate files and folders within a project.
    #>

    [CmdletBinding()]
    [OutputType([System.IO.FileInfo], [System.IO.DirectoryInfo])]
    param (
        # Gets items by type.
        #
        #   ShouldMerge - *.ps1 files from enum*, class*, priv*, pub* and InitializeModule if present.
        #   Static      - Files which are not within a well known top-level folder. Captures help content in en-US, format files, configuration files, etc.
        [Parameter(Mandatory)]
        [ValidateSet('ShouldMerge', 'Static')]
        [String]$Type,

        # BuildInfo is used to determine the source path.
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSTypeName('Indented.BuildInfo')]
        [PSObject]$BuildInfo,

        # Exclude script files containing PowerShell classes.
        [Switch]$ExcludeClass
    )

    try {
        Push-Location $buildInfo.Path.Source.Module

        $itemTypes = [Ordered]@{
            enumeration    = 'enum*'
            class          = 'class*'
            private        = 'priv*'
            public         = 'pub*'
            initialisation = 'InitializeModule.ps1'
        }

        if ($Type -eq 'ShouldMerge') {
            foreach ($itemType in $itemTypes.Keys) {
                if ($itemType -ne 'class' -or ($itemType -eq 'class' -and -not $ExcludeClass)) {
                    Get-ChildItem $itemTypes[$itemType] -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { -not $_.PSIsContainer -and $_.Extension -eq '.ps1' -and $_.Length -gt 0 }
                }
            }
        } elseif ($Type -eq 'Static') {
            [String[]]$exclude = $itemTypes.Values + '*.config', 'test*', 'doc*', 'help', '.build*.ps1', 'build.psd1'

            foreach ($item in Get-ChildItem) {
                $shouldExclude = $false

                foreach ($exclusion in $exclude) {
                    if ($item.Name -like $exclusion) {
                        $shouldExclude = $true
                    }
                }

                if (-not $shouldExclude) {
                    $item
                }
            }
        }
    } catch {
        $pscmdlet.ThrowTerminatingError($_)
    } finally {
        Pop-Location
    }
}

function Get-FunctionInfo {
    <#
    .SYNOPSIS
        Get an instance of FunctionInfo.
    .DESCRIPTION
        FunctionInfo does not present a public constructor. This function calls an internal / private constructor on FunctionInfo to create a description of a function from a script block or file containing one or more functions.
    .EXAMPLE
        Get-ChildItem -Filter *.psm1 | Get-FunctionInfo

        Get all functions declared within the *.psm1 file and construct FunctionInfo.
    .EXAMPLE
        Get-ChildItem C:\Scripts -Filter *.ps1 -Recurse | Get-FunctionInfo

        Get all functions declared in all ps1 files in C:\Scripts.
    #>

    [CmdletBinding(DefaultParameterSetName = 'FromPath')]
    [OutputType([System.Management.Automation.FunctionInfo])]
    param (
        # The path to a file containing one or more functions.
        [Parameter(Position = 1, ValueFromPipelineByPropertyName, ParameterSetName = 'FromPath')]
        [Alias('FullName')]
        [String]$Path,

        # A script block containing one or more functions.
        [Parameter(ParameterSetName = 'FromScriptBlock')]
        [ScriptBlock]$ScriptBlock,

        # By default functions nested inside other functions are ignored. Setting this parameter will allow nested functions to be discovered.
        [Switch]$IncludeNested
    )

    begin {
        $executionContextType = [PowerShell].Assembly.GetType('System.Management.Automation.ExecutionContext')
        $constructor = [System.Management.Automation.FunctionInfo].GetConstructor(
            [System.Reflection.BindingFlags]'NonPublic, Instance',
            $null,
            [System.Reflection.CallingConventions]'Standard, HasThis',
            ([String], [ScriptBlock], $executionContextType),
            $null
        )
    }

    process {
        if ($pscmdlet.ParameterSetName -eq 'FromPath') {
            try {
                $scriptBlock = [ScriptBlock]::Create((Get-Content $Path -Raw))
            } catch {
                $ErrorRecord = @{
                    Exception = $_.Exception.InnerException
                    ErrorId   = 'InvalidScriptBlock'
                    Category  = 'OperationStopped'
                }
                Write-Error @ErrorRecord
            }
        }

        if ($scriptBlock) {
            $scriptBlock.Ast.FindAll( {
                    param( $ast )

                    $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
                },
                $IncludeNested
            ) | ForEach-Object {
                try {
                    $internalScriptBlock = $_.Body.GetScriptBlock()
                } catch {
                    Write-Debug $_.Exception.Message
                }
                if ($internalScriptBlock) {
                    $constructor.Invoke(([String]$_.Name, $internalScriptBlock, $null))
                }
            }
        }
    }
}

task GetBuildInfo {
    $Script:buildInfo = [PSCustomObject]@{
        ModuleName = 'Indented.Build'
        Version    = [Version]'1.0.0'
        Config      = [PSCustomObject]@{
            EndOfLineChar = ([Environment]::NewLine, $config.EndOfLineChar)[$null -ne $config.EndOfLineChar]
        }
        Path       = [PSCustomObject]@{
            ProjectRoot = $psscriptroot
            Source      = [PSCustomObject]@{
                Module   = [System.IO.DirectoryInfo](Join-Path $psscriptroot 'Indented.Build')
                Manifest = [System.IO.DirectoryInfo](Join-Path $psscriptroot 'Indented.Build\Indented.Build.psd1')
            }
            Build       = [PSCustomObject]@{
                Module     = [System.IO.DirectoryInfo](Join-Path $psscriptroot 'build\Indented.Build\1.0.0')
                Manifest   = [System.IO.FileInfo](Join-Path $psscriptroot 'build\Indented.Build\1.0.0\Indented.Build.psd1')
                RootModule = [System.IO.FileInfo](Join-Path $psscriptroot 'build\Indented.Build\1.0.0\Indented.Build.psm1')
                Output     = [System.IO.DirectoryInfo](Join-Path $psscriptroot 'build\output')
                Package    = [System.IO.DirectoryInfo](Join-Path $psscriptroot 'build\packages')
            }
        }
        PSTypeName = 'Indented.BuildInfo'
    }
}


task UpdateRequiredModules {
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

task Clean {
    $erroractionprefence = 'Stop'

    try {
        if (Get-Module -Name $buildInfo.ModuleName) {
            Remove-Module -Name $buildInfo.ModuleName
        }

        if (Test-Path $buildInfo.Path.Build.Module.Parent.FullName) {
            Remove-Item $buildInfo.Path.Build.Module.Parent.FullName -Recurse -Force
        }

        $nupkg = Join-Path $buildInfo.Path.Build.Package ('{0}.*.nupkg' -f $buildInfo.ModuleName)
        if (Test-Path $nupkg) {
            Remove-Item $nupkg
        }

        if (Test-Path $buildInfo.Path.Build.Output) {
            Remove-Item $buildInfo.Path.Build.Output -Recurse
        }

        $null = New-Item $buildInfo.Path.Build.Module -ItemType Directory -Force
        $null = New-Item $buildInfo.Path.Build.Package -ItemType Directory -Force

        if (-not (Test-Path $buildInfo.Path.Build.Output)) {
            $null = New-Item $buildInfo.Path.Build.Output -ItemType Directory -Force
        }
    } catch {
        throw
    }
}

task CopyModuleFiles {
    try {
        $buildInfo |
            Get-BuildItem -Type Static |
            Copy-Item -Destination $buildInfo.Path.Build.Module -Recurse -Force
    } catch {
        throw
    }
}

task Merge {
    $writer = [System.IO.StreamWriter][System.IO.File]::Create($buildInfo.Path.Build.RootModule)

    $usingStatements = [System.Collections.Generic.HashSet[String]]::new()

    $buildInfo | Get-BuildItem -Type ShouldMerge | ForEach-Object {
        $functionDefinition = Get-Content $_.FullName | ForEach-Object {
            if ($_ -match '^using (namespace|assembly)') {
                $null = $usingStatements.Add($_)
            } else {
                $_.TrimEnd()
            }
        }
        $writer.Write(($functionDefinition -join $buildInfo.Config.EndOfLineChar).Trim())
        $writer.Write($buildInfo.Config.EndOfLineChar * 2)
    }

    if (Test-Path (Join-Path $buildInfo.Path.Source.Module 'InitializeModule.ps1')) {
        $writer.WriteLine('InitializeModule')
    }

    $writer.Close()

    $rootModule = (Get-Content $buildInfo.Path.Build.RootModule -Raw).Trim()
    if ($usingStatements.Count -gt 0) {
        # Add "using" statements to be start of the psm1
        $rootModule = $rootModule.Insert(
            0,
            ($buildInfo.Config.EndOfLineChar * 2)
        ).Insert(
            0,
            (($usingStatements | Sort-Object) -join $buildInfo.Config.EndOfLineChar)
        )
    }
    Set-Content -Path $buildInfo.Path.Build.RootModule -Value $rootModule -NoNewline
}

task UpdateMetadata {
    try {
        $path = $buildInfo.Path.Build.Manifest

        # Version
        Update-Metadata $path -PropertyName ModuleVersion -Value $buildInfo.Version

        # RootModule
        Update-Metadata $path -PropertyName RootModule -Value $buildInfo.Path.Build.RootModule.Name

        # FunctionsToExport
        $functionsToExport = Get-ChildItem (Join-Path $buildInfo.Path.Source.Module 'pub*') -Filter '*.ps1' -Recurse |
            Get-FunctionInfo |
            Select-Object -ExpandProperty Name
        if ($functionsToExport) {
            Update-Metadata $path -PropertyName FunctionsToExport -Value $functionsToExport
        }

        # FormatsToProcess
        if (Test-Path (Join-Path $buildInfo.Path.Build.Module '*.Format.ps1xml')) {
            Update-Metadata $path -PropertyName FormatsToProcess -Value (Get-Item (Join-Path $buildInfo.Path.Build.Module '*.Format.ps1xml')).Name
        }
    } catch {
        throw
    }
}

task UpdateBuildScript {
    Import-Module $buildInfo.Path.Build.Manifest -Global -Force
    Export-BuildScript -BuildSystem AppVeyor -Path (Join-Path $buildInfo.Path.ProjectRoot '.build.ps1')
}
