Describe Update-DevRootModule -Tag CI {
    BeforeAll {
        $guid = New-Guid
        $tempDrive = Join-Path -Path $env:TEMP -ChildPath $guid
        New-Item -Path $tempDrive -ItemType Directory

        Join-Path -Path $tempDrive -ChildPath 'Module\Module\public' |
            New-Item -Path { $_ } -ItemType Directory

        $filePath = Join-Path -Path $tempDrive -ChildPath 'Module\Module\public\functions.ps1'
        Set-Content $filePath -Value @(
            'function Get-Something { }'
            'function Set-Something { }'
        )

        $defaultParams = @{
            BuildInfo = [PSCustomObject]@{
                ModuleName = 'Module'
                Path       = [PSCustomObject]@{
                    Source = [PSCustomObject]@{
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

    It 'Generates a psm1 file' {
        Update-DevRootModule @defaultParams

        Join-Path -Path $tempDrive -ChildPath 'Module\Module\Module.psm1' | Should -Exist
    }

    It 'Dot-sources any files containing code' {
        Update-DevRootModule @defaultParams

        Join-Path -Path $tempDrive -ChildPath 'Module\Module\Module.psm1' |
            Should -FileContentMatchMultiline '\$public = @\([\s\S]+?functions'
    }

    It 'Exports functions from a folder named public' {
        Update-DevRootModule @defaultParams

        Join-Path -Path $tempDrive -ChildPath 'Module\Module\Module.psm1' |
            Should -FileContentMatchMultiline '\$functionsToExport = @\([\s\S]+?Get-Something[\s\S]+?Set-Something'
    }
}
