function Get-AzureBackupBlobItem
{
    <#
            .SYNOPSIS
            The "Get-AzureBackupBlobItem" cmdlet retrieves blob items from a storage account in Azure.

            .DESCRIPTION
            The "Get-AzureBackupBlobItem" cmdlet retrieves the specified blob from a storage account in Azure.
            You can specify RetentionDays, backuptype and database name as filter.

            .PARAMETER ResourceGroupName
            This parameter specifies the name of the resource group.

            .PARAMETER StorageAccountName
            This parameter specifies the name of the StorageAccount.

            .PARAMETER retentionDays
            The number of days to define the end of the time range.
            Only numbers between 1 and 99 are allowed.

            .PARAMETER backuptype
            The type of backup you're looking for.
            Allowed values are 'all','full','log' 

            .PARAMETER database
            The beginning of the database name. The search pattern is"-like "$database*"

            .EXAMPLE
            This will retrieve all blob items of the last 30 days for all backuptypes.
            Get-AzureBackupBlobItem -ResourceGroupName Value -StorageAccountName Value -retentionDays 30 -backuptype 'all'

            This will retrieve all blob items of the last 30 days for all databases with Test at the begining of the name.
            Get-AzureBackupBlobItem -ResourceGroupName Value -StorageAccountName Value -retentionDays 30 -database 'Test'
            
            .OUTPUTS
            The function will return the results as object including the ULR of the blob.

    #>


    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$ResourceGroupName,
        [parameter(Mandatory,ValueFromPipeline)][string]$StorageAccountName,
        [parameter(Mandatory,ValueFromPipeline)][ValidateRange(1,99)][int]$RetentionDays,
        [parameter(Mandatory,ValueFromPipeline)][ValidateSet('all','full','log')][string]$backuptype,
        [string]$database = $null
    )

    begin { 

        Switch ($backuptype)
        {
            'all'	
            {
                $type = '*'
            }
            'log'	
            {
                $type = '*.trn'
            }
            'full' 
            {
                $type = '*.bak'
            }
        }

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
        try 
        { 
            if($RetentionDays -and !($database) ) 
            {
                $isOldDate = [DateTime]::UtcNow.AddDays(-$RetentionDays)
                Write-Verbose -Message ('returning results for: backuptype ' +$backuptype + ' and last ' + $RetentionDays + ' days')
                $result = $blobs | Where-Object -FilterScript {
                    $_.LastModified.UtcDateTime -ge $isOldDate -and $_.BlobType -eq 'BlockBlob' -and $_.Name -like $type 
                }
            } 

            if($database) 
            {
                $isOldDate = [DateTime]::UtcNow.AddDays(-$RetentionDays) 
                Write-Verbose -Message ('returning results for: database ' +$database + ' and last ' + $RetentionDays + ' days')
                $result = $blobs | Where-Object -FilterScript {
                    $_.LastModified.UtcDateTime -ge $isOldDate -and $_.BlobType -eq 'BlockBlob' -and $_.Name -like "$database*" 
                }
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

    end {
        $result | Select-Object -Property Name, LastModified, Length, @{
            n = 'URL'
            e = {
                $Context.BlobEndPoint + $container.Name + '/' + $_.Name
            }
        }
    }
}
