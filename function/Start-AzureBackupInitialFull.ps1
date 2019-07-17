function Start-AzureBackupInitialFull
{
    <#
            .SYNOPSIS
            The "Start-AzureBackupInitialFull" cmdlet retrieves items from a backup container where the initial backup is pending.

            .DESCRIPTION
            The "Start-AzureBackupInitialFull" cmdlet retrieves items from a backup container where the initial backup is pending.

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER RecoveryServicesVault
            The name of the RecoveryServicesVault.

            .PARAMETER VM
            This parameter specifies a single VM in the RecoveryServicesVault.

            .EXAMPLE
            Start the initial backup of all databases where it is pending.
            Start-AzureBackupInitialFull -ResourceGroupName Value -RecoveryServicesVault Value -VM Value


            .OUTPUTS
            The function will return the results as object.
    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$RecoveryServicesVault,
        [parameter(Mandatory,ValueFromPipeline)][string]$VM
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
    }
    Process {

        try 
        {
            $bkpitems = Get-AzRecoveryServicesBackupItem -BackupManagementType 'AzureWorkload' -WorkloadType 'MSSQL' -VaultId $myVault.ID | Where-Object -FilterScript {
                $_.ProtectedItemHealthStatus -eq 'IRPending'
            }

            if($bkpitems.count -gt 0) 
            {
                $BackupItems = 
                foreach($item in $bkpitems) 
                {
                    Write-Verbose -Message "Starting inital backup for:  $($item.ParentName) - $($item.FriendlyName)"
                    Backup-AzRecoveryServicesBackupItem -Item $item -BackupType 'Full' -EnableCompression -VaultId $myVault.ID
                }
            }
            else 
            {
                Write-Verbose -Message 'No pending inital backups'
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
