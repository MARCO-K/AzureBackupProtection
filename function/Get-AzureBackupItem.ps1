function Get-AzureBackupItem
{
    <#
        .SYNOPSIS
        The cmdlet Get-AzureBackupItem collects a list of items which protected by Azure backup.

        .DESCRIPTION
        The cmdlet Get-AzureBackupItem collects a list of items which protected by Azure backup. It also returns the protection status of the items.
        All items in a RecoveryServicesVault will be collected and returned as object.
        The collection can be filtered by VMs.

        .PARAMETER ResourceGroupName
        This parameter specifies the name of the resource group.

        .PARAMETER RecoveryServicesVault
        The name of the RecoveryServicesVault.

        .PARAMETER VM
        This optional parameter can specifiy a single VM in the RecoveryServicesVault.

        .EXAMPLE
        Return all registered backup items for a VM in a specific RecoveryServicesVault.
        Get-AzureBackupItem -ResourceGroupName Value -RecoveryServicesVault Value -VM Value

        .OUTPUTS
        The function will return the results as object.
    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][String]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$RecoveryServicesVault,
        [Parameter(ValueFromPipeline)][AllowEmptyString()][string]$VM
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

        $myVault = Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroupName -Name $RecoveryServicesVault
        Write-Verbose -Message "Recover vault context: $($myVault.Name)"
    }

    process {

        $container = Get-AzRecoveryServicesBackupContainer -ResourceGroupName $ResourceGroupName -VaultId $myVault.ID -ContainerType AzureVMAppContainer

        if($VM) 
        {
            $myVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VM
            Write-Verbose -Message "VM context: $($myVM.Name)"
            $container = $container | Where-Object -FilterScript {
                $_.FriendlyName -eq $VM
            }
        }

        try 
        {
            $bckitems = 
            foreach($item in $container) 
            {
                Write-Verbose -Message "Getting backup items for container: $($item.FriendlyName)"
                Get-AzRecoveryServicesBackupItem -VaultId $myVault.ID -Container $item -WorkloadType MSSQL
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

    end {$bckitems}
}
