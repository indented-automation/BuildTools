function Export-BuildScript {
    <#
    .SYNOPSIS
        Export a build script for use with Invoke-Build.
    .DESCRIPTION
        Export a build script for use with Invoke-Build.
    .INPUTS
        BuildInfo (from Get-BuildInfo)
    #>

    [CmdletBinding()]
    [OutputType([String])]
    param (
        # The build information object is used to determine which tasks are applicable.
        [Parameter(ValueFromPipeline)]
        [PSTypeName('Indented.BuildInfo')]
        [PSObject]$BuildInfo = (Get-BuildInfo),

        # By default the build system is automatically discovered. The BuildSystem parameter overrides any automatically discovered value. Tasks associated with the build system are added to the generated script.
        [String]$BuildSystem,

        # The build script will be written to the the specified path.
        [String]$Path = '.build.ps1'
    )

    process {
        if ($BuildSystem) {
            $BuildInfo.BuildSystem = $BuildSystem
        }

        $script = [System.Text.StringBuilder]::new()
        $null = $script.AppendLine('param (').
                        AppendLine('    [String]$ModuleName,').
                        AppendLine().
                        AppendLine('    [PSTypeName("Indented.BuildInfo")]').
                        AppendLine('    [ValidateCount(1, 1)]').
                        AppendLine('    [PSObject[]]$BuildInfo').
                        AppendLine(')').
                        AppendLine().
                        AppendLine('Set-Alias MSBuild (Resolve-MSBuild) -ErrorAction SilentlyContinue').
                        AppendLine()

        $tasks = $BuildInfo | Get-BuildTask | Sort-Object {
            switch ($_.Stage) {
                'Setup'   { 1; break }
                'Build'   { 2; break }
                'Test'    { 3; break }
                'Pack'    { 4; break }
                'Publish' { 5; break }
            }
        }, Order, Name

        # Build the wrapper tasks and insert the block at the top of the script
        $taskSets = [System.Text.StringBuilder]::new()
        $taskStages = ($tasks | Group-Object Stage -NoElement).Name

        # Add a default task set
        $null = $taskSets.AppendFormat('task default {0},', $taskStages[0]).AppendLine()
        for ($i = 1; $i -lt $taskStages.Count; $i++) {
            $null = $taskSets.AppendFormat(
                '             {0}{1}',
                $taskStages[$i],
                @(',', '')[$i -eq $taskStages.Count - 1]
            ).AppendLine()
        }
        $null = $taskSets.AppendLine()

        $tasks | Group-Object Stage | ForEach-Object {
            $indentLength = 'task '.Length + $_.Name.Length
            $null = $taskSets.AppendFormat('task {0} {1}', $_.Name, $_.Group[0].Name)
            foreach ($task in $_.Group | Select-Object -Skip 1) {
                $null = $taskSets.Append(',').
                                AppendLine().
                                AppendFormat('{0} {1}', (' ' * $indentLength), $task.Name)
            }
            $null = $taskSets.AppendLine().
                            AppendLine()
        }
        $null = $script.Append($taskSets.ToString())

        # Add supporting functions to create the BuildInfo object.
        (Get-Command Get-BuildInfo).ScriptBlock.Ast.FindAll(
            {
                param ( $ast )

                $ast -is [System.Management.Automation.Language.CommandAst]
            },
            $true
        ) | ForEach-Object GetCommandName |
            Select-Object -Unique |
            Sort-Object |
            ForEach-Object {
                $commandInfo = Get-Command $_

                if ($commandInfo.Source -eq $myinvocation.MyCommand.ModuleName) {
                    $null = $script.AppendFormat('function {0} {{', $commandInfo.Name).
                                    Append($commandInfo.Definition).
                                    AppendLine('}').
                                    AppendLine()
                }
            }

        @(
            'Convert-CodeCoverage'
            'ConvertTo-ChocoPackage'
            'Enable-Metadata'
            'Get-Ast'
            'Get-BuildInfo'
            'Get-BuildItem'
            'Get-FunctionInfo'
            'Get-LevenshteinDistance'
            'Get-MethodInfo'
        ) | ForEach-Object {
            $null = $script.AppendFormat('function {0} {{', $_).
                            Append((Get-Command $_).Definition).
                            AppendLine('}').
                            AppendLine()
        }

        # Add a generic task which allows BuildInfo to be retrieved
        $null = $script.AppendLine('task GetBuildInfo {').
                        AppendLine('    Get-BuildInfo').
                        AppendLine('}').
                        AppendLine()

        # Add a task that allows all all build jobs within the current project to run
        $null = $script.AppendLine('task BuildAll {').
                        AppendLine('    [String[]]$task = ${*}.Task.Name').
                        AppendLine().
                        AppendLine('    # Re-submit the build request without the BuildAll task').
                        AppendLine('    if ($task.Count -eq 1 -and $task[0] -eq "BuildAll") {').
                        AppendLine('        $task = "default"').
                        AppendLine('    } else {').
                        AppendLine('        $task = $task -ne "BuildAll"').
                        AppendLine('    }').
                        AppendLine().
                        AppendLine('    Get-BuildInfo | ForEach-Object {').
                        AppendLine('        Write-Host').
                        AppendLine('        "Building {0} ({1})" -f $_.ModuleName, $_.Version | Write-Host -ForegroundColor Green').
                        AppendLine('        Write-Host').
                        AppendLine('        Invoke-Build -BuildInfo $_ -Task $task').
                        AppendLine('    }').
                        AppendLine('}').
                        AppendLine()

        $tasks | ForEach-Object {
            $null = $script.AppendFormat('task {0}', $_.Name)
            if ($_.If -and $_.If.ToString().Trim() -ne '$true') {
                $null = $script.AppendLine(' -If (').
                                AppendLine($_.If.ToString().Trim()).
                                Append(')')
            }
            $null = $script.AppendLine(' {').
                            AppendLine($_.Definition.ToString().Trim("`r`n")).
                            AppendLine('}').
                            AppendLine()
        }

        $script.ToString() | Set-Content $Path
    }
}
