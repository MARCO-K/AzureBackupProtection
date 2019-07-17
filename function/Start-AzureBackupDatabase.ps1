function Start-AzureBackupDatabase
{
    <#
            .SYNOPSIS
            Start backup for a database on SQL instance. You can select the requiered backup type. 

            .DESCRIPTION
            Start backup for a database on SQL instance. You can select the requiered backup type.

            .PARAMETER ResourceGroupName
            Describe parameter -ResourceGroupName.

            .PARAMETER RecoveryServicesVault
            Describe parameter -RecoveryServicesVault.

            .PARAMETER VM
            Describe parameter VM.

            .PARAMETER instance
            Describe parameter -instance.

            .PARAMETER database
            Describe parameter -database.

            .PARAMETER backuptype
            Describe parameter -backuptype.

            .EXAMPLE
            Start-AzureBackupDatabase -ResourceGroupName 'kae-rg-we-prod' -RecoveryServicesVault 'kae-bkpvlt-we-prod-lrs' -VM 'kae-we-wpsql001' -instance 'S001' -database 'dbspi_test' -backuptype 'Full'

            .NOTES
            Place additional notes here.

            .LINK
            URLs to related sites
            The first link is opened by Get-Help -Online Start-AzureBackupDatabase

            .INPUTS
            List of input types that are accepted by this function.

            .OUTPUTS
            List of output types produced by this function.
    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$RecoveryServicesVault,
        [parameter(Mandatory,ValueFromPipeline)][string]$VM,
        [parameter(Mandatory,ValueFromPipeline)][string]$instance,
        [parameter(Mandatory,ValueFromPipeline)][string]$database,
        [parameter(Mandatory,ValueFromPipeline)][string]$backuptype
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
            $bkpitems = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL -VaultId $myVault.ID | Where-Object -FilterScript {
                ($_.ParentName -eq $instance ) -and ($_.FriendlyName -eq $database)
            }
      
            if($bkpitems.count -gt 0) 
            {
                $BackupItems = 
                foreach($item in $bkpitems) 
                {
                    Write-Verbose -Message "Trying to backup database: $($item.FriendlyName)"
                    if($item.ProtectionState -ne 'ProtectionStopped') 
                    {
                        Write-Verbose -Message "Starting inital backup for: $($item.FriendlyName)"
                        Backup-AzRecoveryServicesBackupItem -Item $item -BackupType $backuptype -EnableCompression -VaultId $myVault.ID
                    }
                    else 
                    {
                        Write-Verbose -Message "Database $($item.FriendlyName) is not protected"
                    }
                }
            }
            else 
            {
                Write-Verbose -Message 'No database with this name to backup'
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
