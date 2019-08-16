function Get-AzureBackupProtectionPolicy
{
    <#
            .SYNOPSIS
            The function "Get-AzureBackupProtectionPolicy" will list all available backup policies for a RecoveryServicesVault

            .DESCRIPTION
            The function "Get-AzureBackupProtectionPolicy" will list all available backup policies for a RecoveryServicesVault:
			It will only show policies for MSSQL workload.
            

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER RecoveryServicesVault
            The name of the RecoveryServicesVault.


            .EXAMPLE
            Returns all unprotected items in a VM.
            Get-AzureBackupProtectionPolicy -ResourceGroupName Value -RecoveryServicesVault Value

            .OUTPUTS
            The function will return the results as object.
    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$RecoveryServicesVault
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

    }
    Process {
        try 
        {

                $items = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $myVault.ID -WorkloadType 'MSSQL'
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
