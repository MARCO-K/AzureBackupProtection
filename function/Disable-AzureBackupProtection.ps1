function Disable-AzureBackupProtection
{
    <#
            .SYNOPSIS
            The cmdlet Disable-AzureBackupProtection disables the backup protection for all databases in a instance.

            .DESCRIPTION
            The cmdlet Disable-AzureBackupProtection disables the backup protection for all databases in a instance.
            This cmdlet stops regular scheduled backups of all items in an instance. This cmdlet can also delete existing recovery points for the backup item.

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER RecoveryServicesVault
            The name of the RecoveryServicesVault.

            .PARAMETER VM
            This parameter specifies a single VM in the RecoveryServicesVault.

            .PARAMETER instance
            This parameter specifies a single instance on a VM.

            .PARAMETER databases
            This parameter specifies a single or a list of databases.
        
            .PARAMETER RemoveRecoveryPoints
            This parameter controls if asll existing recovrey points will be deleted.

            .EXAMPLE
            Disables backups for all items for an instance in a VM and also deletes all existing recovery points from the vault.
            Disable-AzureBackupProtection -ResourceGroupName 'RG' -RecoveryServicesVault 'VAULT' -VM 'VM1' -instance '123' -RemoveRecoveryPoints $true
            
            Disables backups for all items for an instance in a VM but keeps existing recovery points .
            Disable-AzureBackupProtection -ResourceGroupName 'RG' -RecoveryServicesVault 'VAULT' -VM 'VM1' -instance '123' -databases 'db1','db2' -RemoveRecoveryPoints $false

            .OUTPUTS
            The function will return the results as object.
    #>


    [CmdletBinding(SupportsShouldProcess)]
    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$RecoveryServicesVault,
        [parameter(Mandatory,ValueFromPipeline)][string]$VM,
        [parameter(Mandatory,ValueFromPipeline)][string]$instance,
        [parameter(ValueFromPipeline)][object[]]$databases,
        [parameter(Mandatory,ValueFromPipeline)][bool]$RemoveRecoveryPoints,
        [switch]$Force
    )
    begin {

        if (-not $PSBoundParameters.ContainsKey('Verbose')) 
        {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }
        if (-not $PSBoundParameters.ContainsKey('Confirm')) 
        {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) 
        {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
        Write-Verbose -Message ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)


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
        $SQLContainer = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVMAppContainer -FriendlyName $myVM.Name -VaultId $myVault.ID
        Write-Verbose -Message "BackupContainer context: $($SQLContainer.Name)"
    }
    Process {

        try 
        {
            $bkpitems = Get-AzRecoveryServicesBackupItem -Container $SQLContainer -WorkloadType MSSQL -VaultId $myVault.ID | Where-Object -FilterScript {
                ($_.ParentName -eq $instance)
            }

            if($databases) 
            {
                $bkpitems = $bkpitems | Where-Object -FilterScript {
                    $_.FriendlyName -in $databases -and $_.ParentType -eq 'AzureVmWorkloadSQLInstance'
                }
            }

            if($bkpitems.count -gt 0) 
            {
                $BackupItems = 
                foreach($item in $bkpitems) 
                {
                    Write-Verbose -Message "Stop backup protection for: $($item.FriendlyName)"
               
                    if ($Force -or $PSCmdlet.ShouldProcess('ShouldProcess?')) 
                    {
                        $ConfirmPreference = 'None'
                        Disable-AzRecoveryServicesBackupProtection -Item $item -VaultId $myVault.ID -RemoveRecoveryPoints:$RemoveRecoveryPoints
                    }
                }
            }
            else 
            {
                Write-Verbose -Message 'No backup items to stop protection'
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
