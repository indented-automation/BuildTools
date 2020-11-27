Describe Enable-Metadata {
    BeforeAll {
        Mock Get-Content {
            '@{
                Enabled = 1
                # Disabled = 2
                # Duplicate = 3
                ChildNode = @{
                    # Duplicate = 3
                }
            }'
        }
        Mock Set-Content
        Mock Test-Path { $true }

        $defaultParams = @{
            PropertyName    = 'Default'
            Path            = 'TestDrive:\manifest.psd1'
            WarningVariable = 'warning'
            WarningAction   = 'SilentlyContinue'
        }
    }

    Context 'Value exists and is enabled' {
        BeforeAll {
            Mock Get-Metadata

            $defaultParams.PropertyName = 'Enabled'
        }

        It 'When the value is present and enabled, returns true' {
            Enable-Metadata @defaultParams | Should -BeTrue
        }

        It 'When the value is present and enabled, does not call Get-Content or Set-Content' {
            Enable-Metadata @defaultParams

            Assert-MockCalled Get-Content -Times 0 -Scope It
            Assert-MockCalled Set-Content -Times 0 -Scope It
        }
    }

    Context 'Value exists and is commented / disabled' {
        BeforeAll {
            Mock Get-Metadata {
                throw [System.Management.Automation.ItemNotFoundException]::new('Not found')
            }

            $defaultParams.PropertyName = 'Disabled'
        }

        It 'When the value has been uncommented, returns true' {
            Enable-Metadata @defaultParams | Should -BeTrue
        }

        It 'When the value has been enabled, calls Get-Content and Set-Content' {
            Enable-Metadata @defaultParams

            Assert-MockCalled Get-Content -Times 1 -Exactly -Scope It
            Assert-MockCalled Set-Content -Times 1 -Exactly -Scope It
        }
    }

    Context 'Value exists in more than one location' {
        BeforeAll {
            Mock Get-Metadata {
                throw [System.Management.Automation.ItemNotFoundException]::new('Not found')
            }

            $defaultParams.PropertyName = 'Duplicate'
        }

        It 'When the value is ambiguous, returns false' {
            Enable-Metadata @defaultParams | Should -BeFalse
        }

        It 'When the value is duplicated, calls Get-Content' {
            Enable-Metadata @defaultParams

            Assert-MockCalled Get-Content -Times 1 -Exactly -Scope It
        }

        It 'When the value is duplicated, does not change content' {
            Enable-Metadata @defaultParams

            Assert-MockCalled Set-Content -Times 0 -Scope It
        }

        It 'When the value is duplicated, writes a warning' {
            Enable-Metadata @defaultParams

            $warning | Should -BeLike 'Found more than one*'
        }
    }

    Context 'Value does not exist' {
        BeforeAll {
            Mock Get-Metadata {
                throw [System.Management.Automation.ItemNotFoundException]::new('Not found')
            }

            $defaultParams.PropertyName = 'DoesNotExist'
        }

        It 'When the value does not exist, returns false' {
            Enable-Metadata @defaultParams | Should -BeFalse
        }

        It 'When the value does not exist, calls Get-Content' {
            Enable-Metadata @defaultParams

            Assert-MockCalled Get-Content -Times 1 -Exactly -Scope It
        }

        It 'When the value does not exist, does not call Set-Content' {
            Enable-Metadata @defaultParams

            Assert-MockCalled Set-Content -Times 0 -Scope It
        }

        It 'When the value does not exist, writes a warning' {
            Enable-Metadata @defaultParams

            $warning | Should -BeLike 'Cannot find disabled property*'
        }
    }
}
