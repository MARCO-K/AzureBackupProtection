function Remove-AzureBackupBlobItem
{
    <#
            .SYNOPSIS
            The "Remove-AzureBackupBlobItem" cmdlet removes the specified blob from a storage account in Azure.

            .DESCRIPTION
            The "Remove-AzureBackupBlobItem" cmdlet removes the specified blob from a storage account in Azure.
            You can specify how long, in days, the deletion will happen.

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER StorageAccountName
            This parameter specifies the name of the StorageAccount.

            .PARAMETER retentionDays
            The number of days to define the end of the time range.

            .EXAMPLE
            Remove-AzureBackupBlobItem -ResourceGroupName Value -StorageAccountName Value -retentionDays 30
            This will delete all blob items older than 30 days.

            .OUTPUTS
            The function will return the results as object.
    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$StorageAccountName,
        [parameter(Mandatory,ValueFromPipeline)][ValidateRange(1,99)][int]$RetentionDays
    )

    begin { 
        $today = Get-Date
        $isOldDate = [DateTime]::UtcNow.AddDays(-$RetentionDays)

        $storageaccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
        Write-Verbose -Message ('Working with StorageAccount: ' + $storageaccount.StorageAccountName)
        $key = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
        $key = $key[0]

        $Context = New-AzStorageContext -StorageAccountName $storageaccount.StorageAccountName -StorageAccountKey $key.Value
        $container = Get-AzStorageContainer -Context $Context
        Write-Verbose -Message ('Working with StorageContainer: ' + $container.Name)
        Write-Verbose -Message 'Retrieving blob items from container'
        $blobs = Get-AzStorageBlob -Container $container.Name -Context $Context
    }

    process { 

        $blobs = $blobs | Where-Object -FilterScript {
            $_.LastModified.UtcDateTime -lt $isOldDate -and $_.BlobType -eq 'BlockBlob'
        }
        try 
        { 
            if($blobs) 
            {
                $result = 
                foreach ($blob in $blobs) 
                {
                    Write-Verbose -Message ('Removing blob: ' + $blob.Name)
                    Remove-AzStorageBlob -Blob $blob.Name -Container $container.Name -Context $Context
                }
            }
            else 
            {
                Write-Output -InputObject ('No blob items found in the time range: ' + $today+ ' to ' + $isOldDate) 
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

    end {$result}
}