using namespace System.IO

class BuildInfo {
    # The name of the module being built.
    [String]$ModuleName

    # The build steps.
    [BuildType]$BuildType

    # The release type.
    [ReleaseType]$ReleaseType

    # The version which will be created.
    [Version]$Version

    # The tasks which will be executed during this build.
    [BuildTask[]]$BuildTask

    # The root of this repository.
    [DirectoryInfo]$ProjectRoot

    # The path to the module source
    [DirectoryInfo]$Source

    # The package generated by the build process.
    [DirectoryInfo]$Package

    # An output directory which stores files created by tools like Pester.
    [DirectoryInfo]$Output

    # The manifest associated with the package.
    [FileInfo]$ReleaseManifest

    # The root module associated with the package.
    [FileInfo]$ReleaseRootModule

    # Acceptable code coverage threshold.
    [Double]$CodeCoverageThreshold = 0.9

    # Constructors

    # Supports testing
    hidden BuildInfo() { }

    BuildInfo($BuildType, $ReleaseType) {
        $this.BuildType = $BuildType
        $this.ReleaseType = $ReleaseType

        if ($this.ProjectRoot = (git rev-parse --show-toplevel 2> $null)) {
            # Converts / into \
            $this.ProjectRoot = $this.ProjectRoot.FullName
        } else {
            throw (New-Object InvalidOperationException('Unable to discover repository root'))
        }

        $this.Source = $this.GetSourcePath()
        $this.ModuleName = $this.GetModuleName()
        $this.Version = $this.GetVersion()
        $this.BuildTask = $this.GetBuildTask()

        # Paths

        $this.Package = Join-Path $this.ProjectRoot $this.Version
        $this.Output = Join-Path $this.ProjectRoot 'output'

        if ($this.ProjectRoot.Name -ne $this.ModuleName) {
            $this.Package = [Path]::Combine($this.ProjectRoot, 'build', $this.ModuleName, $this.Version)
            $this.Output = [Path]::Combine($this.ProjectRoot, 'build', 'output', $this.ModuleName)
        }
       
        $this.ReleaseManifest = Join-Path $this.Package ('{0}.psd1' -f $this.ModuleName)
        $this.ReleaseRootModule = Join-Path $this.Package ('{0}.psm1' -f $this.ModuleName)
    }

    # Private methods

    hidden [BuildTask[]] GetBuildTask() {
        return Get-BuildTask | 
            Where-Object { $BuildType -band $_.Stage -and $_.ValidWhen.Invoke() } |
            Sort-Object Stage, Order
    }

    hidden [String] GetModuleName() {
        if ($this.Source.Name -eq 'source') {
            return $this.Source.Parent.Parent.GetDirectories($this.Source.Parent.Name).Name
        } else {
            return $this.Source.Parent.GetDirectories($this.Source.Name).Name
        }
    }

    hidden [String] GetSourcePath() {
        # Valid source paths:
        #   ProjectRoot\source
        #   ProjectRoot\ModuleName
        #   ProjectRoot\ModuleName\source

        if (Test-Path (Join-Path $this.ProjectRoot 'source')) {
            return Join-Path $this.ProjectRoot 'source'
        } elseif (Test-Path 'source') {
            return Join-Path $pwd 'source'
        } elseif ((Split-Path $pwd -Leaf) -eq 'source') {
            return $pwd
        } elseif ((Test-Path '*.psd1') -and ((Get-Item '*.psd1').BaseName -eq (Get-Item $pwd).Name)) {
            return $pwd
        } elseif (Test-Path (Join-Path $this.ProjectRoot $this.ProjectRoot.Name)) {
            return Join-Path $this.ProjectRoot $this.ProjectRoot.Name
        }

        throw 'Unable to determine the source path'
    }

    hidden [Version] GetVersion() {
        # Prefer to use version numbers from git.
        $packageVersion = [Version]'1.0.0.0'
        [String]$gitVersion = (git describe --tags 2> $null) -replace '^v'
        if ([Version]::TryParse($gitVersion, [Ref]$packageVersion)) {
            return $this.IncrementVersion($packageVersion)
        }

        # Fall back on version numbers in the manifest.
        $sourceManifest = Join-Path $this.Source ('{0}.psd1' -f $this.ModuleName)
        if (Test-Path $sourceManifest) {
            $manifestVersionString = Get-Metadata -Path $sourceManifest -PropertyName ModuleVersion

            $manifestVersion = [Version]'0.0.0.0'
            if ([Version]::TryParse($manifestVersionString, [Ref]$manifestVersion)) {
                return $this.IncrementVersion($manifestVersion)
            }
        }

        return $packageVersion
    }

    hidden [Version] IncrementVersion($version) {
        $ctorArgs = switch ($this.ReleaseType) {
            'Major' { ($version.Major + 1), 0, 0, 0 }
            'Minor' { $version.Major, ($version.Minor + 1), 0, 0 }
            'Build' { $version.Major, $version.Minor, ($version.Build + 1), 0 }
        }
        return New-Object Version($ctorArgs)
    }
}