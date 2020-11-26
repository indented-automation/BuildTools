Describe Get-BuildInfo {
    BeforeAll {
        $module = @{
            ModuleName = 'Indented.Build'
        }

        Mock GetBuildSystem @module { 'Desktop' }

        New-Item 'TestDrive:\ProjectName\ModuleName' -ItemType Directory
        New-ModuleManifest 'TestDrive:\ProjectName\ModuleName\ModuleName.psd1' -RootModule ModuleName.psm1 -ModuleVersion 1.0.0

        $defaultParams = @{
            ProjectRoot = 'TestDrive:\ProjectName'
        }
    }

    Context 'Normal operation' {
        It 'Returns an object of type Indented.BuildInfo' {
            $buildInfo = Get-BuildInfo @defaultParams

            $buildInfo | Should -Not -BeNullOrEmpty
            $buildInfo.PSTypeNames | Should -Contain 'Indented.BuildInfo'
        }

        It 'Uses GetBuildSystem to discover the CI platform' {
            $buildInfo = Get-BuildInfo @defaultParams

            $buildInfo.BuildSystem | Should -Be 'Desktop'

            Should -Invoke GetBuildSystem @module -Scope It
        }
    }

    Context 'Paths generation' {
        It 'Path.Build.Module usese the convention "ProjectRoot\build\ModuleName\Version"' {
            (Get-BuildInfo @defaultParams).Path.Build.Module | Should -BeLike '*\ProjectName\build\ModuleName\1.0.0'
        }

        It 'Path.Build.Output usese the convention "ProjectRoot\build\output": ' {
            (Get-BuildInfo @defaultParams).Path.Build.Output | Should -BeLike '*\ProjectName\build\output\ModuleName'
        }
    }
}
