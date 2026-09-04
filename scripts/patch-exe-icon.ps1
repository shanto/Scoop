param (
    [Parameter(Mandatory = $true)]
    [string]$TargetExe,

    [Parameter(Mandatory = $true)]
    [string]$IconSpec
)

$Signature = @"
using System;
using System.Runtime.InteropServices;

public class Win32IconTools {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern int ExtractIconEx(string lpszFile, int nIconIndex, out IntPtr phiconLarge, out IntPtr phiconSmall, int nIcons);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyIcon(IntPtr hIcon);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr BeginUpdateResource(string pFileName, bool bDeleteExistingResources);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool UpdateResource(IntPtr hUpdate, IntPtr lpType, IntPtr lpName, ushort wLanguage, byte[] lpData, uint cbData);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool EndUpdateResource(IntPtr hUpdate, bool fDiscard);
}
"@

# Initialize dependencies
Add-Type -TypeDefinition $Signature
Add-Type -AssemblyName System.Drawing

try {
    $resolvedExe = Convert-Path $TargetExe -ErrorAction Stop
    $icoBytes = $null

    if ($IconSpec -match "(.+),(\d+)$") {
        $sourceFile = Convert-Path $Matches[1] -ErrorAction SilentlyContinue
        if (-not $sourceFile) { $sourceFile = [System.Environment]::ExpandEnvironmentVariables($Matches[1]) }
        $iconIndex  = [int]$Matches[2]

        $largeIconHandle = [IntPtr]::Zero
        $smallIconHandle = [IntPtr]::Zero
        $extractedCount  = [Win32IconTools]::ExtractIconEx($sourceFile, $iconIndex, [ref]$largeIconHandle, [ref]$smallIconHandle, 1)

        if ($extractedCount -le 0 -or $largeIconHandle -eq [IntPtr]::Zero) {
            throw "Failed to extract index $iconIndex from source module: $sourceFile"
        }

        $iconObject   = [System.Drawing.Icon]::FromHandle($largeIconHandle)
        $memoryStream = New-Object System.IO.MemoryStream
        $iconObject.Save($memoryStream)
        $icoBytes     = $memoryStream.ToArray()

        $memoryStream.Dispose()
        [Win32IconTools]::DestroyIcon($largeIconHandle) | Out-Null
        [Win32IconTools]::DestroyIcon($smallIconHandle) | Out-Null
    }
    else {
        $sourceFile = Convert-Path $IconSpec -ErrorAction Stop
        $icoBytes   = [System.IO.File]::ReadAllBytes($sourceFile)
    }

    $hUpdate = [Win32IconTools]::BeginUpdateResource($resolvedExe, $false)
    if ($hUpdate -eq [IntPtr]::Zero) { throw "Unable to open target binary for modification." }

    $updateSuccess   = [Win32IconTools]::UpdateResource($hUpdate, [IntPtr]3, [IntPtr]1, 1033, $icoBytes, $icoBytes.Length)
    $finalizeSuccess = [Win32IconTools]::EndUpdateResource($hUpdate, (-not $updateSuccess))

    if ($updateSuccess -and $finalizeSuccess) {
        Write-Host "Success: Binary resources cleanly modified!" -ForegroundColor Green
    } else {
        throw "Resource injection commit pipeline failed. App running?"
    }
}
catch {
    Write-Error $_.Exception.Message
}
