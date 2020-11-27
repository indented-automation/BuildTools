Describe GetBuildSystem {
    BeforeAll {
        $module = @{
            ModuleName = 'Indented.Build'
        }

        $names = 'APPVEYOR', 'JENKINS_URL'

        # Capture current values
        $valueSet = @{}
        foreach ($name in $names) {
            if (Test-Path env:$name) {
                $valueSet.$name = (Get-Item env:$name).Value
            }
        }
    }

    AfterAll {
        # Reset all values to the original
        foreach ($name in $names) {
            if ($valueSet.Contains($name)) {
                Set-Item env:$name -Value $valueSet.$name
            }
        }
    }

    BeforeEach {
        # Clear all values
        foreach ($name in $names) {
            if (Test-Path env:$name) {
                Remove-Item env:$name
            }
        }
    }

    AfterEach {
        # Clear all values
        foreach ($name in $names) {
            if (Test-Path env:$name) {
                Remove-Item env:$name
            }
        }
    }

    It 'Returns "Desktop" by default' {
        InModuleScope @module { GetBuildSystem } | Should -Be 'Desktop'
    }

    It 'When %APPVEYOR% is set, returns AppVeyor' {
        $env:APPVEYOR = $true

        InModuleScope @module { GetBuildSystem } | Should -Be 'AppVeyor'
    }

    It 'When %JENKINS_URL% is set, returns Jenkins' {
        $env:JENKINS_URL = 'http://jenkins'

        InModuleScope @module { GetBuildSystem } | Should -Be 'Jenkins'
    }
}
