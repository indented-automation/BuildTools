Describe BuildTask {
    It 'Returns tasks with the PSTypeName set to Indented.BuildTask' {
        $buildTask = BuildTask -Name 'name' -Stage 'Build' -Definition { }
        $buildTask.PSTypeNames | Should -Contain 'Indented.BuildTask'
    }

    It 'When using mandatory parameters only, sets default values' {
        $buildTask = BuildTask -Name 'name' -Stage 'Build' -Definition { }
        $buildTask.Order | Should -Be 1024
        & $buildTask.If | Should -Be $true
    }

    It 'When order is defined, passes the value to the Order property' {
        $buildTask = BuildTask -Name 'name' -Stage 'Build' -Order 0 -If { $false } -Definition { }
        $buildTask.Order | Should -Be 0
        & $buildTask.If | Should -Be $false
    }
}
