<#
.SYNOPSIS
Safely audits a Windows 11 laptop before shrinking C: for a Fedora dual boot install.

.DESCRIPTION
This script checks whether a Windows SSD looks ready for a manual Fedora dual boot
resize. It does not shrink partitions, modify the bootloader, disable BitLocker,
or change Windows settings. If requested, it can export browser bookmarks to HTML
files for import on Fedora without copying cookies, passwords, sessions, history,
or browser profiles. If the requested Fedora allocation appears viable, it prints
a Resize-Partition command for manual review.
#>

[CmdletBinding()]
param(
    [ValidateRange(20, 2048)]
    [int]$FedoraSpaceGB = 120,

    [ValidateRange(40, 2048)]
    [int]$MinimumWindowsFreeAfterShrinkGB = 80,

    [switch]$ExportBrowserBookmarks,

    [string]$BookmarkExportDirectory = "$env:USERPROFILE\Desktop\Fedora-Bookmark-Export",

    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Bad {
    param([string]$Message)
    Write-Host "[BLOCKER] $Message" -ForegroundColor Red
}

function Convert-BytesToGB {
    param([UInt64]$Bytes)
    return [math]::Round(($Bytes / 1GB), 2)
}

$results = [ordered]@{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    ComputerName = $env:COMPUTERNAME
    RequestedFedoraSpaceGB = $FedoraSpaceGB
    MinimumWindowsFreeAfterShrinkGB = $MinimumWindowsFreeAfterShrinkGB
    Checks = @()
    Blockers = @()
    Warnings = @()
    BookmarkExports = @()
    SuggestedCommand = $null
}

function Add-Check {
    param(
        [string]$Name,
        [ValidateSet("OK", "WARN", "BLOCKER")]
        [string]$Status,
        [string]$Detail
    )

    $script:results.Checks += [ordered]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
    }

    if ($Status -eq "BLOCKER") {
        $script:results.Blockers += "$Name`: $Detail"
        Write-Bad "$Name`: $Detail"
    }
    elseif ($Status -eq "WARN") {
        $script:results.Warnings += "$Name`: $Detail"
        Write-Warn "$Name`: $Detail"
    }
    else {
        Write-Ok "$Name`: $Detail"
    }
}

function ConvertTo-BookmarkHtml {
    param(
        [object]$Bookmarks,
        [string]$BrowserName
    )

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine("<!DOCTYPE NETSCAPE-Bookmark-file-1>")
    [void]$builder.AppendLine("<META HTTP-EQUIV=`"Content-Type`" CONTENT=`"text/html; charset=UTF-8`">")
    [void]$builder.AppendLine("<TITLE>$([System.Net.WebUtility]::HtmlEncode($BrowserName)) Bookmarks</TITLE>")
    [void]$builder.AppendLine("<H1>$([System.Net.WebUtility]::HtmlEncode($BrowserName)) Bookmarks</H1>")
    [void]$builder.AppendLine("<DL><p>")

    function Add-BookmarkNode {
        param(
            [object]$Node,
            [int]$Depth
        )

        $indent = "  " * $Depth
        if ($Node.type -eq "url" -and $Node.url) {
            $name = [System.Net.WebUtility]::HtmlEncode($Node.name)
            $url = [System.Net.WebUtility]::HtmlEncode($Node.url)
            [void]$builder.AppendLine("$indent<DT><A HREF=`"$url`">$name</A>")
            return
        }

        if ($Node.children) {
            $name = [System.Net.WebUtility]::HtmlEncode($Node.name)
            if (-not $name) { $name = "Bookmarks" }
            [void]$builder.AppendLine("$indent<DT><H3>$name</H3>")
            [void]$builder.AppendLine("$indent<DL><p>")
            foreach ($child in $Node.children) {
                Add-BookmarkNode -Node $child -Depth ($Depth + 1)
            }
            [void]$builder.AppendLine("$indent</DL><p>")
        }
    }

    $rootLabels = @{
        bookmark_bar = "Bookmarks Bar"
        other = "Other Bookmarks"
        synced = "Mobile Bookmarks"
    }

    foreach ($rootProperty in $Bookmarks.roots.PSObject.Properties) {
        $root = $rootProperty.Value
        if (-not $root.children) { continue }
        if ($rootLabels.ContainsKey($rootProperty.Name)) {
            $root.name = $rootLabels[$rootProperty.Name]
        }
        Add-BookmarkNode -Node $root -Depth 1
    }

    [void]$builder.AppendLine("</DL><p>")
    return $builder.ToString()
}

function Export-ChromiumBookmarks {
    param(
        [string]$BrowserName,
        [string]$BookmarkPath,
        [string]$OutputDirectory
    )

    if (-not (Test-Path $BookmarkPath)) { return $false }

    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        $bookmarks = Get-Content -Path $BookmarkPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $html = ConvertTo-BookmarkHtml -Bookmarks $bookmarks -BrowserName $BrowserName
        $safeName = ($BrowserName -replace '[^A-Za-z0-9._-]', '-').ToLowerInvariant()
        $outputPath = Join-Path $OutputDirectory "$safeName-bookmarks.html"
        Set-Content -Path $outputPath -Value $html -Encoding UTF8
        $script:results.BookmarkExports += $outputPath
        Add-Check "Bookmark Export - $BrowserName" "OK" "Exported bookmarks to $outputPath."
        return $true
    }
    catch {
        Add-Check "Bookmark Export - $BrowserName" "WARN" "Failed to export bookmarks. $_"
        return $false
    }
}

function Invoke-BookmarkExport {
    $shouldExport = $ExportBrowserBookmarks

    if (-not $Json -and -not $ExportBrowserBookmarks) {
        Write-Section "Optional Browser Bookmark Export"
        Write-Host "This can export Chrome, Edge, Brave, and Vivaldi bookmarks to HTML files for import on Fedora." -ForegroundColor White
        Write-Host "It does NOT copy cookies, passwords, sessions, history, Sync state, or browser profiles." -ForegroundColor Yellow
        $reply = Read-Host "Export supported browser bookmarks now? [n]"
        $shouldExport = ($reply -match '^[Yy]$|^[Yy][Ee][Ss]$')
    }

    if (-not $shouldExport) {
        Add-Check "Browser Bookmark Export" "OK" "Skipped."
        return
    }

    $candidates = @(
        @{
            Name = "Chrome"
            Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks"
        },
        @{
            Name = "Microsoft Edge"
            Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"
        },
        @{
            Name = "Brave"
            Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Bookmarks"
        },
        @{
            Name = "Vivaldi"
            Path = "$env:LOCALAPPDATA\Vivaldi\User Data\Default\Bookmarks"
        }
    )

    $exported = 0
    foreach ($candidate in $candidates) {
        if (Export-ChromiumBookmarks -BrowserName $candidate.Name -BookmarkPath $candidate.Path -OutputDirectory $BookmarkExportDirectory) {
            $exported++
        }
    }

    if ($exported -eq 0) {
        Add-Check "Browser Bookmark Export" "WARN" "No supported Chromium bookmark files were found. Firefox users should export bookmarks from Firefox Library > Import and Backup > Export Bookmarks to HTML."
    }
    else {
        Add-Check "Browser Bookmark Import Tip" "OK" "On Fedora Firefox, import with Bookmarks > Manage bookmarks > Import and Backup > Import Bookmarks from HTML."
    }
}

Write-Section "Fedora Dual Boot Preflight Audit"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Add-Check "Administrator" "BLOCKER" "Run PowerShell as Administrator."
    if ($Json) { $results | ConvertTo-Json -Depth 6 }
    exit 1
}

Add-Check "Administrator" "OK" "Running elevated."

$os = Get-CimInstance Win32_OperatingSystem
$caption = $os.Caption
$build = [int]$os.BuildNumber

if ($caption -notmatch "Windows 11") {
    Add-Check "Windows Version" "WARN" "Detected '$caption'. Script is intended for Windows 11."
}
else {
    Add-Check "Windows Version" "OK" "$caption build $build."
}

try {
    $cPartition = Get-Partition -DriveLetter C
    $cVolume = Get-Volume -DriveLetter C
    $disk = Get-Disk -Number $cPartition.DiskNumber
}
catch {
    Add-Check "C Drive Detection" "BLOCKER" "Could not find C: partition, volume, or disk. $_"
    if ($Json) { $results | ConvertTo-Json -Depth 6 }
    exit 1
}

Add-Check "C Drive Detection" "OK" "C: is on Disk $($disk.Number), Partition $($cPartition.PartitionNumber)."

if ($disk.PartitionStyle -ne "GPT") {
    Add-Check "Partition Style" "BLOCKER" "Disk is $($disk.PartitionStyle), not GPT. Fedora dual boot is safest on UEFI/GPT."
}
else {
    Add-Check "Partition Style" "OK" "Disk uses GPT."
}

try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
    $secureBootText = if ($secureBoot) { "enabled" } else { "disabled" }
    Add-Check "UEFI Boot" "OK" "Secure Boot query succeeded; Secure Boot is $secureBootText."
}
catch {
    Add-Check "UEFI Boot" "WARN" "Could not confirm Secure Boot/UEFI from PowerShell. Check BIOS/UEFI manually."
}

if ($cVolume.FileSystem -ne "NTFS") {
    Add-Check "C File System" "BLOCKER" "C: is $($cVolume.FileSystem), expected NTFS."
}
else {
    Add-Check "C File System" "OK" "C: is NTFS."
}

if ($cVolume.HealthStatus -and $cVolume.HealthStatus -ne "Healthy") {
    Add-Check "C Volume Health" "WARN" "Volume health is $($cVolume.HealthStatus). Run repair scan before shrinking."
}
else {
    Add-Check "C Volume Health" "OK" "Volume reports healthy."
}

if ($disk.OperationalStatus -notcontains "Online") {
    Add-Check "Disk Online" "BLOCKER" "Disk operational status: $($disk.OperationalStatus -join ', ')."
}
else {
    Add-Check "Disk Online" "OK" "Disk is online."
}

$bitlockerAvailable = $true
try {
    $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
}
catch {
    $bitlockerAvailable = $false
    Add-Check "BitLocker" "WARN" "Could not query BitLocker. On Windows Home this may be unavailable. Manually check Device Encryption."
}

if ($bitlockerAvailable) {
    $blStatus = $bl.ProtectionStatus
    $blLock = $bl.LockStatus
    $blPct = $bl.EncryptionPercentage

    if ($blStatus -eq "On") {
        Add-Check "BitLocker" "WARN" "BitLocker is ON for C:. Save the recovery key before resizing. Consider suspending BitLocker before Fedora install."
    }
    else {
        Add-Check "BitLocker" "OK" "BitLocker protection is $blStatus. LockStatus=$blLock Encryption=$blPct%."
    }
}

try {
    $hiberbootPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    $hiberboot = Get-ItemProperty -Path $hiberbootPath -Name HiberbootEnabled -ErrorAction Stop

    if ($hiberboot.HiberbootEnabled -eq 1) {
        Add-Check "Fast Startup" "WARN" "Fast Startup is enabled. Disable it before dual booting."
    }
    else {
        Add-Check "Fast Startup" "OK" "Fast Startup is disabled."
    }
}
catch {
    Add-Check "Fast Startup" "WARN" "Could not read Fast Startup setting."
}

try {
    $hiberFile = "$env:SystemDrive\hiberfil.sys"
    if (Test-Path $hiberFile) {
        Add-Check "Hibernation File" "WARN" "hiberfil.sys exists. Hibernation/Fast Startup may interfere with shared Windows partitions."
    }
    else {
        Add-Check "Hibernation File" "OK" "No hiberfil.sys detected."
    }
}
catch {
    Add-Check "Hibernation File" "WARN" "Could not check hiberfil.sys."
}

$allPartitions = Get-Partition -DiskNumber $disk.Number | Sort-Object PartitionNumber

$efiPartitions = $allPartitions | Where-Object {
    $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" -or
    $_.Type -eq "System"
}

if (-not $efiPartitions) {
    Add-Check "EFI Partition" "BLOCKER" "No EFI System Partition detected on Disk $($disk.Number)."
}
else {
    $efiInfo = $efiPartitions | ForEach-Object {
        "Partition $($_.PartitionNumber), Size $(Convert-BytesToGB $_.Size) GB"
    }
    Add-Check "EFI Partition" "OK" ($efiInfo -join "; ")
}

$recoveryPartitions = $allPartitions | Where-Object {
    $_.Type -eq "Recovery" -or
    $_.GptType -eq "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}"
}

if (-not $recoveryPartitions) {
    Add-Check "Windows Recovery Partition" "WARN" "No obvious Windows Recovery partition detected."
}
else {
    $recInfo = $recoveryPartitions | ForEach-Object {
        "Partition $($_.PartitionNumber), Size $(Convert-BytesToGB $_.Size) GB"
    }
    Add-Check "Windows Recovery Partition" "OK" ($recInfo -join "; ")
}

try {
    $winre = reagentc /info 2>&1 | Out-String
    if ($winre -match "Windows RE status:\s+Enabled") {
        Add-Check "Windows Recovery Environment" "OK" "WinRE is enabled."
    }
    elseif ($winre -match "Windows RE status:\s+Disabled") {
        Add-Check "Windows Recovery Environment" "WARN" "WinRE is disabled."
    }
    else {
        Add-Check "Windows Recovery Environment" "WARN" "Could not clearly determine WinRE status."
    }
}
catch {
    Add-Check "Windows Recovery Environment" "WARN" "Failed to run reagentc /info."
}

$cSizeGB = Convert-BytesToGB $cVolume.Size
$cFreeGB = Convert-BytesToGB $cVolume.SizeRemaining
$cUsedGB = [math]::Round($cSizeGB - $cFreeGB, 2)

Add-Check "C Drive Size" "OK" "Size=$cSizeGB GB, Used=$cUsedGB GB, Free=$cFreeGB GB."

if ($cFreeGB -lt ($FedoraSpaceGB + $MinimumWindowsFreeAfterShrinkGB)) {
    Add-Check "Free Space" "BLOCKER" "Need at least $($FedoraSpaceGB + $MinimumWindowsFreeAfterShrinkGB) GB free to give Fedora $FedoraSpaceGB GB and leave Windows $MinimumWindowsFreeAfterShrinkGB GB free. Current free: $cFreeGB GB."
}
else {
    Add-Check "Free Space" "OK" "Enough free space for requested Fedora allocation and Windows reserve."
}

try {
    $supported = Get-PartitionSupportedSize -DriveLetter C
    $minSizeGB = Convert-BytesToGB $supported.SizeMin
    $maxSizeGB = Convert-BytesToGB $supported.SizeMax

    Add-Check "Windows Supported C: Size Range" "OK" "Minimum=$minSizeGB GB, Maximum=$maxSizeGB GB."

    $requestedShrinkBytes = [UInt64]($FedoraSpaceGB * 1GB)
    $newCSizeBytes = [UInt64]($cPartition.Size - $requestedShrinkBytes)
    $newCSizeGB = Convert-BytesToGB $newCSizeBytes
    $windowsFreeAfterShrinkGB = [math]::Round($cFreeGB - $FedoraSpaceGB, 2)

    if ($newCSizeBytes -lt $supported.SizeMin) {
        Add-Check "Requested Shrink" "BLOCKER" "Windows says C: cannot safely shrink that far. Requested new C: size would be $newCSizeGB GB, but supported minimum is $minSizeGB GB."
    }
    elseif ($windowsFreeAfterShrinkGB -lt $MinimumWindowsFreeAfterShrinkGB) {
        Add-Check "Requested Shrink" "BLOCKER" "After shrink, Windows would only have about $windowsFreeAfterShrinkGB GB free. Minimum requested reserve is $MinimumWindowsFreeAfterShrinkGB GB."
    }
    else {
        Add-Check "Requested Shrink" "OK" "Can shrink C: by about $FedoraSpaceGB GB. New C: size would be about $newCSizeGB GB."
        $results.SuggestedCommand = "Resize-Partition -DriveLetter C -Size $($newCSizeGB)GB"
    }
}
catch {
    Add-Check "Shrink Range" "BLOCKER" "Could not query supported shrink range. $_"
}

try {
    $partsAfterC = $allPartitions | Where-Object { $_.Offset -gt $cPartition.Offset }

    if ($partsAfterC.Count -gt 0) {
        $afterInfo = $partsAfterC | ForEach-Object {
            "Partition $($_.PartitionNumber) Type=$($_.Type) Size=$(Convert-BytesToGB $_.Size)GB"
        }
        Add-Check "Partitions After C:" "WARN" "Partitions exist physically after C:. Fedora installer partition choices must be reviewed carefully. After C:: $($afterInfo -join '; ')"
    }
    else {
        Add-Check "Partitions After C:" "OK" "No partitions after C: on disk."
    }
}
catch {
    Add-Check "Partition Order" "WARN" "Could not analyze partition order."
}

Invoke-BookmarkExport

Write-Section "Current Disk Layout"

$allPartitions |
    Select-Object DiskNumber, PartitionNumber, DriveLetter, Type,
        @{Name="SizeGB"; Expression={ Convert-BytesToGB $_.Size }},
        GptType |
    Format-Table -AutoSize

Write-Section "Recommended Manual Prep Before Shrinking"

Write-Host "1. Back up important files first." -ForegroundColor White
Write-Host "2. Save BitLocker recovery key if BitLocker or Device Encryption is enabled." -ForegroundColor White
Write-Host "3. Disable Fast Startup before dual booting." -ForegroundColor White
Write-Host "4. In Windows, run this scan before resizing:" -ForegroundColor White
Write-Host "   Repair-Volume -DriveLetter C -Scan" -ForegroundColor Gray
Write-Host "5. Do not delete EFI, MSR, Windows, or Recovery partitions in Fedora installer." -ForegroundColor White
Write-Host "6. In Fedora installer, use only the unallocated space." -ForegroundColor White

Write-Section "Result"

if ($results.Blockers.Count -gt 0) {
    Write-Bad "Do NOT shrink yet. Fix the blockers first."
    Write-Host ""
    Write-Host "Blockers:" -ForegroundColor Red
    $results.Blockers | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
}
else {
    Write-Ok "No hard blockers found."

    if ($results.Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Warnings to review first:" -ForegroundColor Yellow
        $results.Warnings | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
    }

    Write-Host ""
    Write-Host "Safe shrink command to run ONLY after backup/recovery-key/prep:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host $results.SuggestedCommand -ForegroundColor Green
    Write-Host ""
    Write-Host "This command changes C: to the new final size. It does not mean shrink by this amount." -ForegroundColor Yellow
}

Write-Section "Fedora Installer Guidance"

Write-Host "When installing Fedora:" -ForegroundColor White
Write-Host "- Choose the existing internal NVMe/SATA disk carefully." -ForegroundColor White
Write-Host "- Do NOT choose erase disk." -ForegroundColor Red
Write-Host "- Use the unallocated space created by the shrink." -ForegroundColor White
Write-Host "- Let Fedora create its own Btrfs layout in that free space." -ForegroundColor White
Write-Host "- Keep the existing Windows EFI partition." -ForegroundColor White
Write-Host "- After install, the boot menu should show Fedora and Windows Boot Manager." -ForegroundColor White

if ($Json) {
    Write-Section "JSON"
    $results | ConvertTo-Json -Depth 6
}
