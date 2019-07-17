function Get-AzureBackupItemUninitialized
{
    <#
            .SYNOPSIS
            The function "Get-AzureBackupItemUninitialized" will retrieve all items on a VM which are currently not protected in a backup container.

            .DESCRIPTION
            The function "Get-AzureBackupItemUninitialized" will retrieve all items on a VM which are currently not protected in a backup container.
            This command will retrieve all protectable items within a certain container. It returns DBs and their upper tier entities like Instance, AvailabilityGroup etc.

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER RecoveryServicesVault
            The name of the RecoveryServicesVault.

            .PARAMETER VM
            This parameter specifies a single VM in the RecoveryServicesVault.

            .EXAMPLE
            Returns all unprotected items in a VM.
            Get-AzureBackupItemUninitialized -ResourceGroupName Value -RecoveryServicesVault Value -VM Value

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
        $SQLContainer = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVMAppContainer -FriendlyName $myVM.Name -VaultId $myVault.ID
        Write-Verbose -Message "BackupContainer context: $($SQLContainer.Name)"
    }
    Process {
        try 
        {
            if($SQLContainer.count -gt 0 -and $SQLContainer.Status -eq 'Registered') 
            {
                $items = Get-AzRecoveryServicesBackupProtectableItem -Container $SQLContainer -WorkloadType MSSQL -VaultId $myVault.ID
            }
        }
        catch 
        {
            # get error record
            [Management.Automation.ErrorRecord]$e = $_

            # retrieve information about runtime error
            $info = [PSCustomObject]@{
                Exception = $e.Exception.Message
                Reason    = $e.CategoryInfo.Reason
                Target    = $e.CategoryInfo.TargetName
                Script    = $e.InvocationInfo.ScriptName
                Line      = $e.InvocationInfo.ScriptLineNumber
                Column    = $e.InvocationInfo.OffsetInLine
            }
          
            # output information. Post-process collected info, and log info (optional)
            $info
        }
    }
    end {$items}
}
