function Initialize-AzureBackupProtection
{
    <#
            .SYNOPSIS
            The function "Initialize-AzureBackupProtection" will initialize backup protection for an instance on a VM.

            .DESCRIPTION
            The function "Initialize-AzureBackupProtection" will initialize backup protection for an instance on a VM.
            This command triggers the discovery of any unprotected items in a given container. The operation which creates protectable items.
            It can also enable backups for the newly discovered items with a specified backup protection policy.

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER RecoveryServicesVault
            The name of the RecoveryServicesVault.

            .PARAMETER VM
            This parameter specifies a single VM in the RecoveryServicesVault.

            .PARAMETER instance
            This parameter specifies a single instance on a VM.

            .PARAMETER profile
            This specifies the name of the backup policy which will be applied to an item.

            .PARAMETER enableprotection
            Enables backup for an item with a specified Backup protection policy.

            .EXAMPLE
            The cmdlet executes a discovery operation for new protectable items on a VM and will enable backup for these items with the specified policy.
            Initialize-AzureBackupProtection -ResourceGroupName RGName -RecoveryServicesVault VaultName -VM VMName -profile PolicyName -enableprotection

            .OUTPUTS
            The function will return the results as object.
    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$RecoveryServicesVault,
        [parameter(Mandatory,ValueFromPipeline)][string]$VM,
        [parameter(Mandatory,ValueFromPipeline)][string]$profile,
        [parameter(Mandatory,ValueFromPipeline)][switch]$enableprotection
    )
    begin {

        if ((Get-AzContext -ErrorAction Ignore) -eq $null) 
        {
            $cred = Get-Credential
            Connect-AzAccount -Credential $cred
            $context = Get-AzContext
        }
        else 
        {
            $context = Get-AzContext
        }
        Write-Verbose -Message "You are connected $($context.Account) to $($context.Subscription.Name)"
        $myVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VM
        Write-Verbose -Message "VM context: $($myVM.Name)"
        $myVault = Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroupName -Name $RecoveryServicesVault
        Write-Verbose -Message "Recover vault context: $($myVault.Name)"
        $defaultprofile = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $myVault.ID -WorkloadType 'MSSQL' | Where-Object -Property Name -EQ -Value $profile
        Write-Verbose -Message "defaultprofile context: $($defaultprofile.Name)"
        $SQLContainer = Get-AzRecoveryServicesBackupContainer -ContainerType 'AzureVMAppContainer' -FriendlyName $myVM.Name -VaultId $myVault.ID
        Write-Verbose -Message "BackupContainer context: $($SQLContainer.Name)"
    }
    Process {

        try 
        {
            if($SQLContainer.count -gt 0 -and $SQLContainer.Status -eq 'Registered') 
            {
                Initialize-AzRecoveryServicesBackupProtectableItem -Container $SQLContainer -WorkloadType 'MSSQL' -VaultId $myVault.ID
                $SQLDB = Get-AzRecoveryServicesBackupProtectableItem -workloadType 'MSSQL' -ItemType 'SQLDataBase' -VaultId $myVault.ID
            }

            if($enableprotection) 
            {
                if($SQLDB.Count -gt 0) 
                {
                    $BackupItems = 
                    foreach($item in $SQLDB) 
                    {
                        Write-Verbose -Message "Enabling backup for new database: $($item.Name)"
                        Enable-AzRecoveryServicesBackupProtection -ProtectableItem $item -Policy $defaultprofile -VaultId $myVault.ID
                    }
                }
                else 
                {
                    Write-Verbose -Message 'No new protectable items'
                }
            }
            else 
            {
                $SQLDB
            }
        }
        catch 
        {
            [Management.Automation.ErrorRecord]$e = $_
            $info = [PSCustomObject]@{
                Exception = $e.Exception.Message
                Reason    = $e.CategoryInfo.Reason
                Target    = $e.CategoryInfo.TargetName
                Script    = $e.InvocationInfo.ScriptName
                Line      = $e.InvocationInfo.ScriptLineNumber
                Column    = $e.InvocationInfo.OffsetInLine
            }
            $info
        }
    }

    End { $BackupItems }
}
