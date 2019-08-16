function Get-AzureBackupRecoveryPoint
{
    <#
            .SYNOPSIS
            The cmdlet Get-AzureBackupRecoveryPoint retrieve the recovery points for a backedup item.

            .DESCRIPTION
            The cmdlet Get-AzureBackupRecoveryPoint collects a list of BackupRecoveryPoint for a backedup item.
            By default all BackupRecoveryPoints of the last week will be returned but the start of the date range can be specified.

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER RecoveryServicesVault
            The name of the RecoveryServicesVault.

            .PARAMETER VM
            This optional parameter can specifiy a single VM in the RecoveryServicesVault.

            .PARAMETER instance
            The name of the instance.

            .PARAMETER database
            The name of the database.

            .PARAMETER daysback
            The number of days to define the end of the time range.

            .EXAMPLE
            Return all BackupRecoveryPoint for a backup items.
            Get-AzureBackupRecoveryPoint -ResourceGroupName Value -RecoveryServicesVault Value -VM Value -instance InstanceName -database DBName

            .OUTPUTS
            The function will return the results as object.
    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][String]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$RecoveryServicesVault,
        [parameter(Mandatory,ValueFromPipeline)][string]$VM,
        [parameter(Mandatory,ValueFromPipeline)][string]$instance,
        [parameter(Mandatory,ValueFromPipeline)][string]$database,
        [parameter(Mandatory=$true)][ValidateRange(1,30)][Int]$daysback
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
        $container = Get-AzRecoveryServicesBackupContainer -ResourceGroupName $ResourceGroupName -VaultId $myVault.ID -ContainerType AzureVMAppContainer
        Write-Verbose -Message "Backup container context: $($container.Name)"
    }

    process {
         

        $container = $container | Where-Object -FilterScript {
            $_.FriendlyName -eq $myVM.Name 
        }
           
        
        try 
        {
            $items = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL  -VaultId $myVault.ID | Where-Object -FilterScript {
                ($_.ParentName -eq $instance ) -and ($_.FriendlyName -eq $database) 
            }

            $startDate = (Get-Date).AddDays(-$daysback).ToUniversalTime()
            Write-Verbose -Message "End of the time range: $startDate"

            $endDate = (Get-Date).ToUniversalTime()
            $bckitems = Get-AzRecoveryServicesBackupRecoveryPoint -Item $items -VaultId $myVault.ID -StartDate $startDate -EndDate $endDate
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

    end {$bckitems | Select-Object @{Name='RecoveryServicesVault'; Expression={$RecoveryServicesVault}},@{Name='VM'; Expression={$VM}},ItemName,RecoveryPointType,RecoveryPointTime,RecoveryPointId,WorkloadType}
}