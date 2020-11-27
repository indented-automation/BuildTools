Describe Get-LevenshteinDistance -Tag CI {
    It 'When the difference string length is 0, returns the length of the reference string' {
        (Get-LevenshteinDistance -ReferenceString 'Hello' -DifferenceString '').Distance | Should -Be 'Hello'.Length
    }

    It 'When one character substitutions are required, returns a distance of 1' {
        (Get-LevenshteinDistance -ReferenceString 'Hello' -DifferenceString 'Helo').Distance | Should -Be 1
    }

    It 'When two character substitutions are required, returns a distance of 2' {
        (Get-LevenshteinDistance -ReferenceString 'Hello' -DifferenceString 'Helol').Distance | Should -Be 2
    }
}
