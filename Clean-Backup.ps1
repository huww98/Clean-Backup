[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$BackupPath = 'C:\backup\data',
    [long]$ReserveSpace = 4GB
)

$ErrorActionPreference = "Stop"

$disk = Get-Volume -FilePath (Resolve-Path $BackupPath).Path
$global:sizeToBeFreed = $ReserveSpace - $disk.SizeRemaining

$global:files = @(Get-ChildItem $BackupPath) -match '_(FULL|DIFF|LOG)_\d+_\d+\.' |
Select-Object -Property Name,FullName,Length,@{label='BackupCreateTime'; expression={ 
    $dateStr = [regex]::Match($_.Name, '_(\d+_\d+)\.').Groups[1]
    [datetime]::ParseExact($dateStr, 'MMddyyyy_hhmmss', [System.Globalization.CultureInfo]::InvariantCulture)
}} |
Sort-Object -Property BackupCreateTime

function Remove-Backup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(ValueFromPipeline=$true)]$backup)

    Write-Debug "removing $($backup | Format-Table | Out-String)"
    $global:sizeToBeFreed -= $backup.Length
    $backup.FullName | Remove-Item
    $global:files = $global:files | Where-Object { $_.FullName -ne $backup.FullName }
}

while ($true) {
    Write-Debug "sizeToBeFreed: $sizeToBeFreed"
    if ($sizeToBeFreed -lt 0) {
        break
    }

    Write-Debug "files: $($files | Format-Table -Property Name,Length | Out-String)"
    if (-not $files) {
        throw 'No backup to remove'
    }

    if ($files.Length -eq 1) {
        Write-Debug "Removing last"
        $files[0] | Remove-Backup
        continue
    }

    $log = @($files | Where-Object { $_.Name -match '_LOG_' })
    $diff = @($files | Where-Object { $_.Name -match '_DIFF_' })
    $full = @($files | Where-Object { $_.Name -match '_FULL_' })

    if (($files[0] -ne $full[0])) {
        Write-Debug "Ensure oldest is full backup"
        $files[0] | Remove-Backup
        continue
    }

    $oldDiff = $diff | Where-Object { $_.BackupCreateTime -lt $full[1].BackupCreateTime } # diffs depend on oldest full
    $oldLog = $log | Where-Object { $_.BackupCreateTime -lt $full[1].BackupCreateTime } # logs depend on oldest full
    if (-not $oldDiff -and -not $oldLog) {
        Write-Debug "Remove oldest full"
        $full[0] | Remove-Backup
        continue
    }

    $oldLog = $log | Where-Object { -not ( $_.BackupCreateTime -gt $diff[0].BackupCreateTime ) }
    if ($oldLog) {
        Write-Debug "Remove logs which only depend on oldest full"
        $oldLog | Select-Object -Last 1 | Remove-Backup
        continue
    }

    $oldLog = $log | Where-Object { $_.BackupCreateTime -lt $diff[1].BackupCreateTime -and $_.BackupCreateTime -lt $full[1].BackupCreateTime }
    if ($oldLog) {
        Write-Debug "Remove logs which depend on oldest diff"
        $oldLog | Select-Object -Last 1 | Remove-Backup
    } else {
        Write-Debug "Remove oldest diff"
        $diff[0] | Remove-Backup
    }
}
