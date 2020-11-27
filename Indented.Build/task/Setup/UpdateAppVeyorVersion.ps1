BuildTask UpdateAppVeyorVersion -Stage Setup -Order 3 -If {
    Test-Path (Join-Path $buildInfo.Path.ProjectRoot 'appveyor.yml')
} -Definition {
    if (Join-Path $buildInfo.Path.ProjectRoot 'appveyor.yml' | Test-Path) {
        $versionString = '{0}.{1}.{2}.{{build}}' -f @(
            $buildInfo.Version.Major
            $buildInfo.Version.Minor
            $buildInfo.Version.Build
        )

        $path = Join-Path $buildInfo.Path.ProjectRoot 'appveyor.yml'
        $content = Get-Content $path -Raw
        $content = $content -replace 'version: .+', ('version: {0}' -f $versionString)
        Set-Content $path -Value $content -NoNewLine
    }
}
