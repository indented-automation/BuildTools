Invoke-Build .\.build.bootstrap.ps1 -Task Build
Invoke-Build -Task Setup, Build, Test -BuildInfo (Get-BuildInfo)
