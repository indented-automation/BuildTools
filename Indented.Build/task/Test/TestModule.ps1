BuildTask TestModule -Stage Test -Order 3 -Definition {
    # Run Pester tests.

    if (-not (Get-ChildItem (Resolve-Path (Join-Path $buildInfo.Path.Source.Module 'test*')).Path -Filter *.tests.ps1 -Recurse -File)) {
        throw 'The PS project must have tests!'
    }

    $script = {
        param (
            $buildInfo
        )

        $path = Join-Path $buildInfo.Path.Source.Module 'test*'

        if (Test-Path (Join-Path $path 'stub')) {
            Get-ChildItem (Join-Path $path 'stub') -Filter *.psm1 -Recurse -Depth 1 | ForEach-Object {
                Import-Module $_.FullName -Global -WarningAction SilentlyContinue
            }
        }

        # Prevent the default code coverage report appearing.
        Import-Module Pester
        & (Get-Module pester) {
            $definition = Get-Content function:Write-CoverageReport
            $definition = $definition -replace '(\$report.+Format-Table)', '# $1'
            Set-Item function:Write-CoverageReport -Value $definition
        }

        Import-Module $buildInfo.Path.Build.Manifest -Global -ErrorAction Stop
        $params = @{
            Script     = @{
                Path       = $path
                Parameters = @{
                    UseExisting = $true
                }
            }
            OutputFile = Join-Path $buildInfo.Path.Build.Output ('{0}-nunit.xml' -f $buildInfo.ModuleName)
            PassThru   = $true
        }
        if (Test-Path $buildInfo.Path.Build.RootModule) {
            $params.Add('CodeCoverage', $buildInfo.Path.Build.RootModule)
            $params.Add('CodeCoverageOutputFile', (Join-Path $buildInfo.Path.Build.Output 'pester-codecoverage.xml'))
        }
        Invoke-Pester @params
    }

    if ($buildInfo.BuildSystem -eq 'Desktop') {
        $pester = Start-Job -ArgumentList $buildInfo -ScriptBlock $script | Receive-Job -Wait
    } else {
        $pester = & $script -BuildInfo $buildInfo
    }
    if ($pester.CodeCoverage) {
        $pester | Convert-CodeCoverage -BuildInfo $buildInfo -Tee
    }

    $path = Join-Path $buildInfo.Path.Build.Output 'pester-output.xml'
    $pester | Export-CliXml $path
}