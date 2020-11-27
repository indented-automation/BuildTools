Describe New-ConfigDocument -Tag CI {
    It 'Creates a build configuration file' {
        Join-Path -Path $TestDrive -ChildPath 'Module\Module' |
            New-Item -Path { $_ } -ItemType Directory -Force

        $defaultParams = @{
            BuildInfo = [PSCustomObject]@{
                ModuleName = 'Module'
                Path       = [PSCustomObject]@{
                    ProjectRoot = Join-Path -Path $TestDrive -ChildPath 'Module' | Get-Item
                    Source = [PSCustomObject]@{
                        Module = Join-Path -Path $TestDrive -ChildPath 'Module\Module' | Get-Item
                    }
                }
                PSTypeName = 'Indented.BuildInfo'
            }
        }

        New-ConfigDocument @defaultParams

        Join-Path -Path $TestDrive -ChildPath 'Module\Module\buildConfig.psd1' | Should -Exist
    }
}
