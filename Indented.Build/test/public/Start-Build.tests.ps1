Describe Start-Build -Tag CI {
    BeforeAll {
        Write-Host 'Creating tempDrive'

        $guid = New-Guid
        $tempDrive = Join-Path -Path $env:TEMP -ChildPath $guid

        Write-Host $tempDrive

        New-Item -Path $tempDrive -ItemType Directory
        Join-Path -Path $tempDrive -ChildPath 'Module\Module' |
            New-Item -Path { $_ } -ItemType Directory

        Write-Host "Test-Path: $(Test-Path $tempDrive)"

        Mock Export-BuildScript {
            $filePath = Join-Path -Path $tempDrive -ChildPath 'Module\.build.ps1'

            Set-Content $filePath -Value @(
                'param ( $BuildInfo )'
                'Task default { }'
            )
        }

        $defaultParams = @{
            BuildType = 'default'
            BuildInfo = [PSCustomObject]@{
                ModuleName = 'Module'
                Path       = [PSCustomObject]@{
                    ProjectRoot = Join-Path -Path $tempDrive -ChildPath 'Module' | Get-Item
                    Source      = [PSCustomObject]@{
                        Module = Join-Path -Path $tempDrive -ChildPath 'Module\Module' | Get-Item
                    }
                }
                PSTypeName = 'Indented.BuildInfo'
            }
        }
    }

    AfterAll {
        Remove-Item -Path $tempDrive -Recurse
    }

    It 'Generates a build script to use' {
        Start-Build @defaultParams

        Should -Invoke Export-BuildScript
    }

    It 'Removes the generated build script' {
        Start-Build @defaultParams

        Join-Path -Path $tempDrive -ChildPath 'Module\.build.ps1' | Should -Not -Exist
    }
}
