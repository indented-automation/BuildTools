Describe Export-BuildScript {
    BeforeAll {
        $guid = New-Guid
        $tempDrive = Join-Path -Path $env:TEMP -ChildPath $guid
        New-Item $tempDrive -ItemType Directory

        Mock Get-BuildTask {
            [PSCustomObject]@{
                Name       = 'CreatePackage'
                Order      = 1
                Stage      = 'Pack'
                Definition = ''
            }
            [PSCustomObject]@{
                Name       = 'NUnitTest'
                Order      = 1
                Stage      = 'Test'
                Definition = ''
            }
            [PSCustomObject]@{
                Name       = 'Compile'
                Order      = 2
                Stage      = 'Build'
                If         = { $someVar -eq $true }
                Definition = ''
            }
            [PSCustomObject]@{
                Name       = 'Merge'
                Order      = 1
                Stage      = 'Build'
                Definition = ''
            }
        }

        $buildInfo = [PSCustomObject]@{
            PSTypeName = 'Indented.BuildInfo'
        }

        $path = Join-Path -Path $tempDrive -ChildPath '.build.ps1'
        Export-BuildScript -BuildInfo $buildInfo -Path $path
        $script = Get-Content -Path $path -Raw
    }

    AfterAll {
        Remove-Item -Path $tempDrive -Recurse
    }

    Context 'Command insertion' {
        It 'Inserts commands required by Get-BuildInfo' {
            $script | Should -Match 'function GetBuildSystem'
        }

        It 'Inserts Enabled-Metadata' {
            $script | Should -Match 'function Enable-Metadata'
        }

        It 'Inserts Get-BuildInfo' {
            $script | Should -Match 'function Get-BuildInfo'

        }

        It 'Inserts Get-BuildItem' {
            $script | Should -Match 'function Get-BuildItem'
        }
    }

    Context 'Task insertion' {
        It 'Inserts the task <Name> returned by Get-BuildTask' -TestCases @(
            @{ Name = 'CreatePackage' }
            @{ Name = 'NUnitTest' }
            @{ Name = 'Merge' }
            @{ Name = 'Compile' }
        ) {
            param (
                $Name
            )

            $script | Should -Match "task $Name"
        }

        It 'Orders tasks based on Stage and Order' {
            $packIndex = $script.IndexOf('task CreatePackage')
            $mergeIndex = $script.IndexOf('task Merge')

            $mergeIndex | Should -BeLessThan $packIndex

            $compileIndex = $script.IndexOf('task Compile')

            $mergeIndex | Should -BeLessThan $compileIndex
        }
    }

    Context 'Summary tasks insertion' {
        It 'Inserts summary tasks' {
            $script | Should -Match 'task Build'
            $script | Should -Match 'task Test'
            $script | Should -Match 'task Pack'
        }

        It 'Inserts a default task' {
            $script | Should -Match 'task default'
        }
    }
}
