Describe Get-BuildTask {
    BeforeAll {
        $module = @{
            ModuleName = 'Indented.Build'
        }

        Mock Get-ChildItem {
            [PSCustomObject]@{
                FullName = {
                    [PSCustomObject]@{
                        Name = 'Compatible'
                        If   = { $true }
                    }
                }
            }
            [PSCustomObject]@{
                FullName = {
                    [PSCustomObject]@{
                        Name = 'NotCompatible'
                        If   = { $false }
                    }
                }
            }
        }
        Mock Pop-Location
        Mock Push-Location

        $buildInfo = [PSCustomObject]@{
            Path = [PSCustomObject]@{
                Source = @{
                    Module = Get-Item $env:TEMP
                }
            }
            PSTypeName = 'Indented.BuildInfo'
        }
    }

    BeforeEach {
        InModuleScope @module {
            $Script:buildTaskCache = $null
        }
    }

    It 'BuildTask: Lists compatible tasks: When BuildInfo is supplied and the task is compatible' {
        $buildTasks = Get-BuildTask -BuildInfo $buildInfo

        @($buildTasks).Count | Should -Be 1
        $buildTasks.Name | Should -Be 'Compatible'
    }

    It 'BuildTask: Lists all tasks: When ListAvailable is set' {
        $buildTasks = Get-BuildTask -ListAvailable

        @($buildTasks).Count | Should -Be 2
        $buildTasks.Name | Should -Contain 'Compatible'
        $buildTasks.Name | Should -Contain 'NotCompatible'
    }
}
