param([ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')][string]$Version = '0.1.0')
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($PSScriptRoot)
$release = Join-Path $root 'build\release'
$dist = Join-Path $root 'dist'
[void][IO.Directory]::CreateDirectory($release)
[void][IO.Directory]::CreateDirectory($dist)

Push-Location $root
try {
    # Always build production code, never the DUALCURSOR_TESTING engine.
    & .\build.cmd 'build\release\DualCursor.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed' }
} finally { Pop-Location }

# An explicit allowlist prevents local settings and build artifacts leaking in.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$name = "DualCursor-v$Version-windows-x64.zip"
$path = Join-Path $dist $name
$stream = [IO.File]::Open($path, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite)
$archive = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    $files = [ordered]@{
        'DualCursor/DualCursor.exe' = (Join-Path $release 'DualCursor.exe')
        'DualCursor/README.md' = (Join-Path $root 'README.md')
        'DualCursor/LICENSE' = (Join-Path $root 'LICENSE')
    }
    foreach ($entry in $files.GetEnumerator()) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $entry.Value, $entry.Key, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $archive.Dispose(); $stream.Dispose() }

$hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$path.sha256", "$hash  $name`r`n", [Text.Encoding]::ASCII)
Write-Output "Created $path"
Write-Output "SHA256: $hash"
