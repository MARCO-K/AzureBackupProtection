function Enable-AzureBackupAutoProtection
{
    <#
            .SYNOPSIS
            The "Enable-AzureBackupAutoProtection" cmdlet sets Azure backup AutoProtection policy on an instance.

            .DESCRIPTION
            The "Enable-AzureBackupAutoProtection" cmdlet sets Azure backup AutoProtection policy on an instance.
            This commands allows users to automatically protect all existing unprotected DBs and any DB which will be added later with the given policy. Azure backup service will then regularly scan auto-protected containers for any new DBs and automatically protect them.

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER RecoveryServicesVault
            The name of the RecoveryServicesVault.

            .PARAMETER VM
            This parameter specifies a single VM in the RecoveryServicesVault.

            .PARAMETER instance
            This parameter specifies a single instance on a VM.

            .PARAMETER targetprofile
            Specifies the new protection policy that will be applied to an item.

            .EXAMPLE
            The cmdlet enables the backup AutoProtection policy for an instance.
            Enable-AzureBackupAutoProtection -ResourceGroupName RGName -RecoveryServicesVault Name -VM VMName -Instance Name -targetprofile Name

            .OUTPUTS
            The function will return the results as object.
    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$RecoveryServicesVault,
        [parameter(Mandatory,ValueFromPipeline)][string]$VM,
        [parameter(ValueFromPipeline)][string]$Instance,
        [parameter(Mandatory,ValueFromPipeline)][string]$targetprofile

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
        $defaultprofile = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $myVault.ID -WorkloadType 'MSSQL' | Where-Object -Property 'Name' -EQ -Value $targetprofile
        Write-Verbose -Message "targetprofile context: $($defaultprofile.Name)"
        $SQLContainer = Get-AzRecoveryServicesBackupContainer -ContainerType 'AzureVMAppContainer' -FriendlyName $myVM.Name -VaultId $myVault.ID
        Write-Verbose -Message "BackupContainer context: $($SQLContainer.Name)"
    }
    Process {
        try 
        {
            if($SQLContainer.count -gt 0 -and $SQLContainer.Status -eq 'Registered') 
            {
                $items = Get-AzRecoveryServicesBackupProtectableItem -Container $SQLContainer -VaultId $myVault.ID -WorkloadType 'MSSQL' -ItemType 'SQLInstance' | Where-Object -FilterScript {
                    $_.IsAutoProtected -eq $false
                }
                
                if($Instance) 
                {
                    $items = $items | Where-Object -FilterScript {
                        $_.ParentName -eq $Instance
                    }
                }
            }
            if($items.Count -gt 0) 
            {
                $BackupItems = 
                foreach($item in $items) 
                {
                    Write-Verbose -Message "Enabling AutoProtection for: $($item.ParentName)"
                    Enable-AzRecoveryServicesBackupAutoProtection -InputItem $item  -BackupManagementType 'AzureWorkload' -WorkloadType 'MSSQL' -Policy $defaultprofile -Verbose -VaultId $myVault.ID
                }
            }
            else 
            {
                Write-Verbose -Message 'No item to enable AutoProtection'
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
