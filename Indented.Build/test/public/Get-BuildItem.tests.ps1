Describe Get-BuildItem {
    BeforeAll {
        $guid = New-Guid
        $tempDrive = Join-Path -Path $env:TEMP -ChildPath $guid

        $toMerge = @(
            New-Item (Join-Path -Path $tempDrive -ChildPath 'enumeration\enum1.ps1') -Force -Value 'enum enum1 { }'
            New-Item (Join-Path -Path $tempDrive -ChildPath 'private\priv1.ps1') -Force -Value 'function priv1 { }'
            New-Item (Join-Path -Path $tempDrive -ChildPath 'public\pub1.ps1') -Force -Value 'function pub1 { }'
            New-Item (Join-Path -Path $tempDrive -ChildPath 'public\nested\pub2.ps1') -Force -Value 'function pub2 { }'
            New-Item (Join-Path -Path $tempDrive -ChildPath 'public\public\empty1.ps1') -Force
            New-Item (Join-Path -Path $tempDrive -ChildPath 'InitializeModule.ps1') -Force -Value 'function InitializeModule { }'
        )
        $toCopy = @(
            New-Item (Join-Path -Path $tempDrive -ChildPath 'ModuleName.format.ps1xml') -Force
            New-Item (Join-Path -Path $tempDrive -ChildPath 'other\name.txt') -Force
        )
        $toIgnore = @(
            New-Item (Join-Path -Path $tempDrive -ChildPath 'class\class1.cs') -Force
            New-Item (Join-Path -Path $tempDrive -ChildPath 'test\test1.tests.ps1') -Force
            New-Item (Join-Path -Path $tempDrive -ChildPath 'help\pub1.md') -Force
        )

        $params = @{
            BuildInfo = [PSCustomObject]@{
                Path = [PSCustomObject]@{
                    Source = [PSCustomobject]@{
                        Module = $tempDrive
                    }
                }
                PSTypeName = 'Indented.BuildInfo'
            }
        }
    }

    AfterAll {
        Remove-Item -Path $tempDrive -Recurse
    }

    Context 'ShouldMerge' {
        It 'Merge: Gets all files which can merge: If file length is greater than 0' {
            $items = Get-BuildItem @params -Type ShouldMerge
            $items.Count | Should -Be ($toMerge.Count - 1)
        }
    }

    Context 'Static' {
        It 'Static: Gets all static files and folders' {
            $items = Get-BuildItem @params -Type Static
            $items.Count | Should -Be $toCopy.Count
            $items[0].Name | Should -Be 'other'
            $items[1].Name | Should -Be 'ModuleName.format.ps1xml'
        }
    }
}
