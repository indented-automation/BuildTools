Describe ConvertTo-ChocoPackage -Tag CI {
    It 'When an imported module is passed from Get-Module, creates a nupkg' {
        Get-Module Pester | ConvertTo-ChocoPackage -Path $TestDrive

        Join-Path -Path $TestDrive -ChildPath 'Pester.*.nupkg' | Should -Exist
    }

    It 'When a module is passed from Get-Module -ListAvailable, creates a nupkg' {
        Get-Module Configuration -ListAvailable | ConvertTo-ChocoPackage -Path $TestDrive

        Join-Path -Path $TestDrive -ChildPath 'Configuration.*.nupkg' | Should -Exist
    }

    It 'When a module is passed from Find-Module, downloads content and creates a nupkg' {
        Find-Module Indented.Net.IP | ConvertTo-ChocoPackage -Path $TestDrive

        Join-Path -Path $TestDrive -ChildPath 'Indented.Net.IP.*.nupkg' | Should -Exist
    }

    It 'When a module is passed from Find-Module, and the module has dependencies, downloads module and dependencies' {
        Find-Module PSModuleDevelopment | ConvertTo-ChocoPackage -Path $TestDrive

        Join-Path -Path $TestDrive -ChildPath 'PSModuleDevelopment.*.nupkg' | Should -Exist
        Join-Path -Path $TestDrive -ChildPath 'PSFramework.*.nupkg' | Should -Exist
    }
}
