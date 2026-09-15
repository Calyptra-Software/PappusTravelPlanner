# Package a built Windows release as a .zip.
#
#   flutter build windows --release
#   pwsh tool/package_windows.ps1 <version> <output-dir>
#
# With PAPPUS_SIDE_BY_SIDE=true in the environment -- set for the *build* too,
# since that is what renames the product (windows/CMakeLists.txt) -- the file
# name is the CI build's, matching the executable it packages.
#
# The Windows counterpart of tool/package_linux.sh, used by both workflows and
# by hand, so a zip that works on a test machine is the zip a release publishes.
#
# Writes <output-dir>/pappus[-ci]-<version>-windows-x64.zip, or with -Folder
# the same content as a plain folder of that name. The folder is for a CI
# artifact: upload-artifact zips whatever it is given, so handing it a zip
# makes a reviewer unpack twice.
param(
  [Parameter(Mandatory)] [string] $Version,
  [Parameter(Mandatory)] [string] $OutputDir,
  [switch] $Folder
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'pappus.exe'))) {
  throw "no release build at $release -- run 'flutter build windows --release' first"
}

$stem = if ($env:PAPPUS_SIDE_BY_SIDE -eq 'true') {
  "pappus-ci-$Version-windows-x64"
} else {
  "pappus-$Version-windows-x64"
}

$work = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid())
$stage = Join-Path $work $stem
New-Item -ItemType Directory -Force -Path $stage | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$out = (Resolve-Path $OutputDir).Path

try {
  Copy-Item -Recurse -Path (Join-Path $release '*') -Destination $stage

  # --- The Visual C++ runtime, beside the executable ------------------------
  #
  # pappus.exe and the plugin DLLs link against msvcp140.dll, vcruntime140.dll
  # and vcruntime140_1.dll. Most machines have them from some other program,
  # and a clean one does not -- then the app fails to start with a message
  # about a missing DLL, which reads as a broken download. Flutter's own
  # deployment guide says to ship them next to the executable, and Microsoft's
  # redistribution terms allow exactly that ("app-local" deployment). They are
  # taken from the Visual Studio that compiled the build, whose redist folder
  # is never older than the toolset it links with.
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (-not $vs) { throw 'Visual Studio with the C++ tools not found' }
  $crt = Get-ChildItem -Directory -Path (Join-Path $vs 'VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT') |
    Sort-Object { [version]($_.Parent.Parent.Name) } |
    Select-Object -Last 1
  if (-not $crt) { throw "no x64 C++ runtime under $vs\VC\Redist\MSVC" }
  Write-Host "C++ runtime: $($crt.FullName)"
  foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    Copy-Item -Path (Join-Path $crt.FullName $dll) -Destination $stage
  }

  if ($Folder) {
    $dir = Join-Path $out $stem
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $dir
    Move-Item -Path $stage -Destination $dir
    Write-Host "Wrote $dir"
    return
  }

  # --- .zip -----------------------------------------------------------------
  #
  # Windows' own bsdtar rather than Compress-Archive, whose entries have been
  # written with backslashes by some versions -- a zip that unpacks into flat
  # files named "data\flutter_assets\..." anywhere but Windows. Named by full
  # path, since a Git for Windows tar earlier on PATH cannot write a zip.
  $zip = Join-Path $out "$stem.zip"
  Remove-Item -Force -ErrorAction SilentlyContinue $zip
  & (Join-Path $env:SystemRoot 'System32\tar.exe') -a -c -f $zip -C $work $stem
  if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }
  Write-Host "Wrote $zip"
} finally {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $work
}
