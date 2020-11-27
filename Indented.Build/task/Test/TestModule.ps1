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

        Import-Module $buildInfo.Path.Build.Manifest -Global -ErrorAction Stop -Force
        $configuration = @{
            Run          = @{
                Path     = $path
                PassThru = $true
            }
            CodeCoverage = @{
                Enabled    = $true
                OutputPath = [string](Join-Path -Path $buildInfo.Path.Build.Output -ChildPath pester-codecoverage.xml)
            }
            TestResult   = @{
                Enabled    = $true
                OutputPath = [string](Join-Path -Path $buildInfo.Path.Build.Output -ChildPath (
                    '{0}-nunit.xml' -f $buildInfo.ModuleName
                ))
            }
            Output       = @{
                Verbosity = 'Diagnostic'
            }
        }
        $pester = Invoke-Pester -Configuration $configuration
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
