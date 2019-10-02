[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$BackupPath = 'C:\backup\data',
    [long]$ReserveSpace = 4GB
)

$ErrorActionPreference = "Stop"

$sizeToBeFreed = $ReserveSpace - (Resolve-Path $BackupPath).Drive.Free

$files = @(Get-ChildItem $BackupPath) -match '_(FULL|DIFF|LOG)_\d+_\d+\.' |
Select-Object -Property Name,FullName,Length,
    @{label='BackupCreateTime'; expression={
        $dateStr = [regex]::Match($_.Name, '_(\d+_\d+)\.').Groups[1].Value
        [datetime]::ParseExact($dateStr, 'MMddyyyy_hhmmss', [System.Globalization.CultureInfo]::InvariantCulture)
    }},
    @{label='BackupType'; expression={ [regex]::Match($_.Name, '_(FULL|DIFF|LOG)_').Groups[1].Value }} |
Sort-Object -Property BackupCreateTime

$files | ForEach-Object {
    if ($_.BackupType -eq 'FULL') { $dep=$null }
    $t = $_.BackupCreateTime
    if ($_.BackupType -eq 'DIFF') {
        $dep = $files | Where-Object { $_.BackupCreateTime -lt $t -and $_.BackupType -eq 'full' } | Select-Object -Last 1
    }
    if ($_.BackupType -eq 'LOG') {
        $dep = $files | Where-Object { $_.BackupCreateTime -lt $t } | Select-Object -Last 1
    }

    $_ | Add-Member -NotePropertyName "DependsOn" -NotePropertyValue $dep
}

Write-Debug "files: $($files | Format-Table -Property Name,BackupCreateTime,Length,BackupType,@{Label='DependsOn'; Expression={$_.DependsOn.Name}} | Out-String)"

while ($true) {
    Write-Debug "sizeToBeFreed: $sizeToBeFreed"
    if ($sizeToBeFreed -lt 0) {
        break
    }

    if (-not $files) {
        throw 'No backup to remove'
    }

    $toBeRemoved = $null
    $dependent = $files
    while ($dependent) {
        $toBeRemoved = $dependent | Select-Object -First 1
        Write-Debug "candidate: $($toBeRemoved.Name)"
        $dependent = $files | Where-Object { $_.DependsOn -eq $toBeRemoved }
        Write-Debug "dependent: $($dependent.Name)"
    }

    Write-Debug "removing $($toBeRemoved.Name)"
    $sizeToBeFreed -= $toBeRemoved.Length
    $files = $files | Where-Object { $_ -ne $toBeRemoved }
    $toBeRemoved.FullName | Remove-Item
}
