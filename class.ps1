    class test {
        [String] $prop = 'value'
        Test() {
            '# bob' | Out-File class.ps1 -Append
        }
    }
    new-object test
# bob
# bob
# bob
# bob
# bob
