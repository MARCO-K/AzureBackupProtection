function Set-AzureBackupProtectionPolicy
{
    <#
            .SYNOPSIS
            The "Set-AzureBackupProtectionPolicy" cmdlet sets backup protection policy on all items in an instance. 

            .DESCRIPTION
            The "Set-AzureBackupProtectionPolicy" cmdlet sets backup protection policy on all items in an instance. 
            Its main purpose is the apply a different backup policy to items which are already in protection.

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER RecoveryServicesVault
            The name of the RecoveryServicesVault.

            .PARAMETER VM
            This parameter specifies a single VM in the RecoveryServicesVault.

            .PARAMETER instance
            This parameter specifies a single instance on a VM.

            .PARAMETER sourceprofile
            Specifies the current protection policy of an item.

            .PARAMETER targetprofile
            Specifies the new protection policy that will be applied to an item.

            .EXAMPLE
            The cmdlet sets the backup protection policy for an instance.
            Set-AzureBackupProtectionPolicy -ResourceGroupName 'RG' -RecoveryServicesVault 'VAULT' -VM 'VM1' -sourceprofile Name -targetprofile Name -instance InstanceName

            .OUTPUTS
            The function will return the results as object.

    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$RecoveryServicesVault,
        [parameter(Mandatory,ValueFromPipeline)][string]$VM,
        [parameter(Mandatory,ValueFromPipeline)][string]$sourceprofile,
        [parameter(Mandatory,ValueFromPipeline)][string]$targetprofile,
        [parameter(Mandatory,ValueFromPipeline)][string]$instance
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
        $sourceprofile = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $myVault.ID -WorkloadType 'MSSQL' | Where-Object -Property 'Name' -EQ -Value $sourceprofile
        Write-Verbose -Message "sourceprofile context: $($sourceprofile.Name)"
        $targetprofile = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $myVault.ID -WorkloadType 'MSSQL' | Where-Object -Property 'Name' -EQ -Value $targetprofile
        Write-Verbose -Message "targetprofile context: $($targetprofile.Name)"
        $SQLContainer = Get-AzRecoveryServicesBackupContainer -ContainerType 'AzureVMAppContainer' -FriendlyName $myVM.Name -VaultId $myVault.ID
        Write-Verbose -Message "BackupContainer context: $($SQLContainer.Name)"
    }

    Process {

        try 
        {
            if($SQLContainer.count -gt 0 -and $SQLContainer.Status -eq 'Registered') 
            {
                $items = Get-AzRecoveryServicesBackupItem -Container $SQLContainer -WorkloadType 'MSSQL' -VaultId $myVault.ID | Where-Object -FilterScript {
                    ($_.ParentName -eq $instance) -and ($_.ProtectionPolicyName -eq $sourceprofile.Name)
                }
            }

            if($items.Count -gt 0) 
            {
                $BackupItems = 
                foreach($item in $items) 
                {
                    Write-Verbose -Message "Enabling Policy $targetprofile for database: $($item.FriendlyName)"
                    Set-AzRecoveryServicesBackupProtectionPolicy -Item $item -VaultId $myVault.ID -Policy $targetprofile.Name
                }
            }
            else 
            {
                Write-Verbose -Message 'No backup policy enabled'
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
