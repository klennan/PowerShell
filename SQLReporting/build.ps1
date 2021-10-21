[CmdletBinding()]
param(
    [string]$Modulename = "SQLReporting",

    [string[]]$Submodules = @(),

    [string]$Comment,

    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$Bump,

    [switch]$Publish
)

$manifestPath = [IO.Path]::Combine($PSScriptRoot, $Modulename, "$ModuleName.psd1")
Write-Verbose "Manifest Path: $ManifestPath"
$moduleVersion = (Test-ModuleManifest -Path $manifestPath).Version
Write-Verbose "Existing Version: $moduleVersion"
$major = $moduleVersion.Major
$minor = $moduleVersion.Minor
$patch = $moduleVersion.Build

if ($Bump) {
    switch ($Bump) {
        'Major' {
            $major++
            $minor = 0
            $patch = 0
            break
        }
        'Minor' {
            $minor++
            $patch = 0
            break
        }
        'Patch' {
            $patch++
            break
        }
        default {}
    }
    $newVersion = [version]"$major.$minor.$patch"
    Write-Verbose "Bumping module version to [$newVersion]"
    Update-ModuleManifest -Path $manifestPath -ModuleVersion $newVersion
    $moduleVersion = (Test-ModuleManifest -Path $manifestPath).Version
}

# Create output directory
$outputDir = [IO.Path]::Combine($PSScriptRoot, 'Output')
Write-Verbose "Writing module to $outputDir"
New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

# Create version directory in output directory
# Make sure the directory is empty if it already exists
$versionOutputDir = [IO.Path]::Combine($outputDir , $moduleVersion)
if (Test-Path -Path $versionOutputDir) {
    Get-ChildItem -Path $versionOutputDir -Recurse | Remove-Item -Force
} else {
    New-Item -Path $versionOutputDir -ItemType Directory | Out-Null
}

# Concatenate all source files into root PSM1
$rootModule = [IO.Path]::Combine($versionOutputDir, "$ModuleName.psm1")
$sourceFiles = Get-ChildItem -Path ./$ModuleName -Filter '*.ps1' -Recurse
Write-Verbose "Compiling all source files into monolith file..."
$sourceFiles | ForEach-Object {
    "# source: $($_.Name)"
    Get-Content $_.Fullname
    ''
} | Add-Content -Path $rootModule -Encoding utf8

# Copy module manifest
$outputManifest = Copy-Item -Path $manifestPath -Destination $versionOutputDir -PassThru

# Update FunctionsToExport
Write-Verbose "Compiling Functions to Export..."
$publicFunctions = Get-ChildItem -Path ./$ModuleName/Public -Filter '*.ps1' -Recurse
foreach ($Submodule in $Submodules) {
    $publicFunctions += Get-ChildItem -Path ./$ModuleName/$SubModule/Public -Filter '*.ps1' -Recurse
}
Update-ModuleManifest -Path $outputManifest -FunctionsToExport $publicFunctions.BaseName

if ($Publish) {
    # Update the Markdown file to have the version update
    Add-Content -Path .\README.md -Value "`n`n  **Version: $moduleVersion**`n`n  by: $($env:USEREMAILADDRESS) on $(Get-Date)"
    if ($Comment) {
        Add-Content -Path .\README.md -Value "`n`n  $Comment"
    }
    Write-Verbose "Publishing module to local PSGallery..."
    Publish-Module -Repository local -NuGetApiKey $env:NuGetApiKey -Name "$versionOutputDir\$ModuleName.psd1"
}
