# Clean Old Database Backup

Works with https://support.microsoft.com/en-us/help/2019698/how-to-schedule-and-automate-backups-of-sql-server-databases-in-sql-se

## Usage

* Run setup.ps1 as Administrator
* Run Clean-Backup.ps1 to clean old database backup file
  ```
  .\Clean-Backup.ps1 -BackupPath C:\backup\data -ReserveSpace 4.2GB
  ```
  * Add `-WhatIf` to see which files it will delete, without actually deleting them.
  * You can run this automatically using Task Scheduler

* Filter Event log with Source equals to "CleanBackup" to see the logs.
