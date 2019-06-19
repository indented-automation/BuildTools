BuildTask UpdateMarkdownHelp -Stage Build -Definition {
    # Update markdown help documents.

    $script =  {
        param (
            $buildInfo
        )

        $path = Join-Path $buildInfo.Path.Source.Module 'test*'

        if (Test-Path (Join-Path $path 'stub')) {
            Get-ChildItem (Join-Path $path 'stub') -Filter *.psm1 -Recurse -Depth 1 | ForEach-Object {
                Import-Module $_.FullName -Global -WarningAction SilentlyContinue
            }
        }

        try {
            $moduleInfo = Import-Module $buildInfo.Path.Build.Manifest.FullName -Global -ErrorAction Stop -PassThru
            if ($moduleInfo.ExportedCommands.Count -gt 0) {
                $null = New-MarkdownHelp -Module $buildInfo.ModuleName -OutputFolder (Join-Path $buildInfo.Path.Source.Module 'help') -Force
            }
        } catch {
            throw
        }
    }

    if ($buildInfo.BuildSystem -eq 'Desktop') {
        Start-Job -ArgumentList $buildInfo -ScriptBlock $script | Receive-Job -Wait -ErrorAction Stop
    } else {
        & $script -BuildInfo $buildInfo
    }
}