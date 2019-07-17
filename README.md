# AzureBackupProtection

This module will help to initialize and configure SQL Server Backup for Azure VMs.

## Backup process

SQL Server Backup for Azure VMs uses the SQL native APIs to take backups of your SQL databases. Just specify the VM that you want to protect and query all SQL Server instances for the databases in it, Azure Backup service will install a workload backup extension on the VM by the name AzureBackupWindowsWorkload extension.

To be able to discover databases on this VM, Azure Backup creates the account **NT SERVICE\AzureWLBackupPluginSvc**. This account is used for backup and restore and requires SQL sysadmin permissions. Azure Backup leverages the NT AUTHORITY\SYSTEM account for database discovery, so this account need to be a public login on SQL.

### Recovery Services object hierarchy

The object hierarchy is summarized in the following diagram:
![image](/recovery-services-object-hierarchy.png "object hierarchy diagram")

### Disable-BackupProtection

The cmdlet Disable-BackupProtection disables the backup protection for databases in a instance.
This cmdlet stops regular scheduled backups of all items in an instance. This cmdlet can also delete existing recovery points for the backup item.
It can be filtered on a single database or a list of databases.

Disables backups for all items for an instance in a VM and also deletes all existing recovery points from the vault.

`Disable-BackupProtection -ResourceGroupName 'RG' -RecoveryServicesVault 'VAULT' -VM 'VM1' -instance '123' -RemoveRecoveryPoints $true`

Disables backups for all items for an instance in a VM but keeps existing recovery points.

`Disable-BackupProtection -ResourceGroupName 'RG' -RecoveryServicesVault 'VAULT' -VM 'VM1' -instance '123' -databases 'db1','db2' -RemoveRecoveryPoints $false`

### Enable-AzureBackupAutoProtection

The "Enable-AzureBackupAutoProtection" cmdlet sets Azure backup AutoProtection policy on an instance.
This commands allows users to automatically protect all existing unprotected DBs and any DB which will be added later with the given policy. Azure backup service will then regularly scan auto-protected containers for any new DBs and automatically protect them.

The cmdlet enables the backup AutoProtection policy for an instance.

`Enable-AzureBackupAutoProtection -ResourceGroupName RGName -RecoveryServicesVault Name -VM VMName -Instance Name -targetprofile Name`

### Get-AzureBackupBlobItem

The "Get-AzureBackupBlobItem" cmdlet retrieves the specified blob from a storage account in Azure.
You can specify RetentionDays, backuptype and database name as filter.

This will retrieve all blob items of the last 30 days for all backuptypes.
`Get-AzureBackupBlobItem -ResourceGroupName Value -StorageAccountName Value -retentionDays 30 -backuptype 'all'`

This will retrieve all blob items of the last 30 days for all databases with Test at the begining of the nam.
`Get-AzureBackupBlobItem -ResourceGroupName Value -StorageAccountName Value -retentionDays 30 -database 'Test'`

### Get-BackupItems

The cmdlet Get-BackupItems collects a list of items which protected by Azure backup. It also returns the protection status of the items.
All items in a RecoveryServicesVault will be collected and returned as object. The collection can be filtered by VMs.

Return all registered backup items for a VM in a specific RecoveryServicesVault.

`Get-BackupItems -ResourceGroupName Value -RecoveryServicesVault Value -VM Value`

### Get-BackupItemUninitialized

The function "Get-BackupItemUninitialized" will retrieve all items on a VM which are currently not protected in a backup container.
This command will retrieve all protectable items within a certain container. It returns DBs and their upper tier entities like Instance, AvailabilityGroup etc.

Returns all unprotected items in a VM.

`Get-BackupItemUninitialized -ResourceGroupName Value -RecoveryServicesVault Value -VM Value`

### Get-BackupRecoveryPoint

The cmdlet Get-BackupRecoveryPoint collects a list of BackupRecoveryPoint for a backedup item.
By default all BackupRecoveryPoints of the last week will be returned but the start of the date range can be specified.

Return all BackupRecoveryPoint for a backup items.

`Get-BackupRecoveryPoint -ResourceGroupName Value -RecoveryServicesVault Value -VM Value -instance InstanceName -database DBName`

### Initialize-AzureBackupProtection

The cmdlet "Initialize-AzureBackupProtection" will initialize backup protection for an instance on a VM.
This command triggers the discovery of any unprotected items in a given container. The operation which creates protectable items.
It can also enable backups for the newly discovered items with a specified backup protection policy.

The cmdlet executes a discovery operation for new protectable items on a VM and will enable backup for these items with the specified policy.

`Initialize-AzureBackupProtection -ResourceGroupName RGName -RecoveryServicesVault VaultName -VM VMName -profile PolicyName -enableprotection`

### Remove-AzureBackupBlobItem

The "Remove-AzureBackupBlobItem" cmdlet removes the specified blob from a storage account in Azure.
You can specify how long, in days, the deletion will happen.

This will delete all blob items older than 30 days.

`Remove-AzureBackupBlobItem -ResourceGroupName Value -StorageAccountName Value -retentionDays 30`

### Set-AzureBackupProtectionPolicy

The "Set-AzureBackupProtectionPolicy" cmdlet sets backup protection policy on all items in an instance.
Its main purpose is the apply a different backup policy to items which are already in protection.

The cmdlet sets the backup protection policy for an instance.

`Set-AzureBackupProtectionPolicy -ResourceGroupName 'RG' -RecoveryServicesVault 'VAULT' -VM 'VM1' -sourceprofile Name -targetprofile Name -instance InstanceName`

### Start-AzureBackupDatabase

Start backup for a database on SQL instance. You can select the requiered backup type.
It can be used to do an initial backup after you enabled backup protection or start a backup after a scheduled backup fails.

Start a full backup for a database 'test'.

`Start-AzureBackupDatabase -ResourceGroupName 'RG' -RecoveryServicesVault 'Vault' -VM 'Server' -instance 'instance' -database 'test' -backuptype 'Full'`

### Start-AzureBackupInitialFull

The "Start-AzureBackupInitialFull" cmdlet retrieves items from a backup container where the initial backup is pending.
It can be used to do an initial backup after you enabled backup protection.

Start the initial backup of all databases where it is pending.

`Start-AzureBackupInitialFull -ResourceGroupName Value -RecoveryServicesVault Value -VM Server`
