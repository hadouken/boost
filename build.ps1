# This script will download and build Boost in both debug and release
# configurations.

$PACKAGES_DIRECTORY = Join-Path $PSScriptRoot "packages"
$OUTPUT_DIRECTORY   = Join-Path $PSScriptRoot "bin"
$VERSION            = "0.0.0"

if (Test-Path Env:\APPVEYOR_BUILD_VERSION) {
    $VERSION = $env:APPVEYOR_BUILD_VERSION
}

# Boost configuration section
$BOOST_VERSION      = "1.57.0"
$BOOST_DIRECTORY    = Join-Path $PACKAGES_DIRECTORY "boost_$($BOOST_VERSION.replace('.', '_'))"
$BOOST_PACKAGE_FILE = "boost_$($BOOST_VERSION.replace('.', '_')).zip"
$BOOST_DOWNLOAD_URL = "http://downloads.sourceforge.net/project/boost/boost/$BOOST_VERSION/$BOOST_PACKAGE_FILE"

# Nuget configuration section
$NUGET_FILE         = "nuget.exe"
$NUGET_TOOL         = Join-Path $PACKAGES_DIRECTORY $NUGET_FILE
$NUGET_DOWNLOAD_URL = "https://nuget.org/$NUGET_FILE"

function Download-File {
    param (
        [string]$url,
        [string]$target
    )

    $webClient = new-object System.Net.WebClient
    $webClient.DownloadFile($url, $target)
}

function Extract-File {
    param (
        [string]$file,
        [string]$target
    )

    [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($file, $target)
}

function Load-DevelopmentTools {
    # Set environment variables for Visual Studio Command Prompt
    
    pushd "c:\Program Files (x86)\Microsoft Visual Studio 12.0\VC"
    
    cmd /c "vcvarsall.bat&set" |
    foreach {
        if ($_ -match "=") {
            $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
        }
    }
    
    popd
}

# Get our dev tools
Load-DevelopmentTools

# Create packages directory if it does not exist
if (!(Test-Path $PACKAGES_DIRECTORY)) {
    New-Item -ItemType Directory -Path $PACKAGES_DIRECTORY | Out-Null
}

# Download Boost
if (!(Test-Path (Join-Path $PACKAGES_DIRECTORY $BOOST_PACKAGE_FILE))) {
    Write-Host "Downloading $BOOST_PACKAGE_FILE"
    Download-File $BOOST_DOWNLOAD_URL (Join-Path $PACKAGES_DIRECTORY $BOOST_PACKAGE_FILE)
}

# Download Nuget
if (!(Test-Path $NUGET_TOOL)) {
    Write-Host "Downloading $NUGET_FILE"
    Download-File $NUGET_DOWNLOAD_URL $NUGET_TOOL
}

# Unpack Boost (may take a while)
if (!(Test-Path $BOOST_DIRECTORY)) {
    Write-Host "Unpacking $BOOST_PACKAGE_FILE (this may take a while)"
    Extract-File (Join-Path $PACKAGES_DIRECTORY $BOOST_PACKAGE_FILE) $PACKAGES_DIRECTORY
}

function Compile-Boost {
    param (
        [string]$platform,
        [string]$configuration
    )

    pushd $BOOST_DIRECTORY

    # Bootstrap Boost only if we do not have b2 already
    if (!(Test-Path b2.exe)) {
        cmd /c bootstrap.bat
    }

    Start-Process ".\b2.exe" -ArgumentList "toolset=msvc-12.0 variant=$configuration link=shared runtime-link=shared --with-chrono --with-date_time --with-filesystem --with-regex --with-system --with-thread" -Wait -NoNewWindow
    
    # Required to build libtorrent with boost=system and boost-link=shared
    Start-Process ".\b2.exe" -ArgumentList "toolset=msvc-12.0 variant=$configuration link=static runtime-link=shared --with-date_time --with-thread" -Wait -NoNewWindow

    popd
}

function Output-Boost {
    param (
        [string]$platform,
        [string]$configuration
    )

    pushd $BOOST_DIRECTORY

    $t = Join-Path $OUTPUT_DIRECTORY "$platform/$configuration"

    # Copy binaries, libraries and include headers
    xcopy /y stage\lib\*.dll "$t\bin\*"
    xcopy /y stage\lib\*.lib "$t\lib\*"
    xcopy /y boost\* "$t\include\boost\*" /E

    # Remove leftovers
    del stage\lib\*.*

    popd
}

Compile-Boost "win32" "debug"
Output-Boost  "win32" "debug"

Compile-Boost "win32" "release"
Output-Boost  "win32" "release"

# Package with NuGet

copy hadouken.boost.nuspec $OUTPUT_DIRECTORY

pushd $OUTPUT_DIRECTORY
Start-Process "$NUGET_TOOL" -ArgumentList "pack hadouken.boost.nuspec -Properties version=$VERSION" -Wait -NoNewWindow
popd