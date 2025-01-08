##################################################################################################################
# Slowly changing dimensions type 3 and merge tables                                                             #
##################################################################################################################
foreach ($division in $Results.Keys) {
    $tableName = "${division}_transactions"
    
    try {
        $deltaCounts = Get-TableRowCount -TableName $tableName -TableSchema "delta" -ErrorAction Stop
        if ($deltaCounts -eq 0) {
            Write-Host "No records in delta table for ${tableName}. Skipping merge."
            continue
        }
    }
    catch {
        Write-Host "Delta table does not exist for ${tableName}. Skipping merge."
        continue
    }

    $prePublicCount = Get-TableRowCount -TableName $tableName -TableSchema "public"
    $expectedFinalCount = $prePublicCount + $deltaCounts

    Write-Host "Pre-merge counts for table ${tableName}"
    Write-Host "  Public table: $prePublicCount rows"
    Write-Host "  Delta table: $deltaCounts rows"
    Write-Host "  Expected final count: $expectedFinalCount rows"

    try {
        $deltaKeys = Get-TableColumn -TableName $tableName -ColumnName "TxnID" -TableSchema "delta" | Sort-Object -Unique
        Write-Host "Found $($deltaKeys.Count) distinct keys in delta table"

        $masterMatchingRows = @()
        $deltaMatchingRows = @()
        $newRecordCount = 0
        $updatedRecordCount = 0
        $originalRows = @()

        foreach ($key in $deltaKeys) {
            $masterRow = Get-TableRow -TableName $tableName -KeyColumn "TxnID" -KeyValue $key -ErrorAction SilentlyContinue
            $deltaRow = Get-TableRow -TableName $tableName -KeyColumn "TxnID" -KeyValue $key -TableSchema "delta" -ErrorAction SilentlyContinue
                
            if ($masterRow -and $deltaRow) {
                $masterMatchingRows += $masterRow
                $deltaMatchingRows += $deltaRow
                $updatedRecordCount++
                $originalRows += $masterRow
            }
            elseif ($deltaRow) {
                $newRecordCount++
            }
        }

        Write-Host "Analysis complete for table ${tableName}"
        Write-Host "  Found $($masterMatchingRows.Count) matching rows between tables"
        Write-Host "  Found $newRecordCount new records in delta table"
        Write-Host "  Found $updatedRecordCount records to be updated"

        Write-Host "Starting merge operation at $(Get-Date)"
        Merge-DeltaData -TableName $tableName -KeyColumn "TxnID"
            
        $postPublicCount = Get-TableRowCount -TableName $tableName -TableSchema "public"
        Write-Host "Post-merge counts for table ${tableName}"
        Write-Host "  Public table: $postPublicCount rows"
        Write-Host "  Delta rows processed: $($postPublicCount - $prePublicCount)"
            
        if ($postPublicCount -ne $expectedFinalCount) {
            Write-Warning "Row count mismatch for table ${tableName}"
            Write-Warning "Expected: $expectedFinalCount, Actual: $postPublicCount"
        }
        else {
            Write-Host "Row count verification successful for table ${tableName}"
        }
    }
    catch {
        Write-Error "Merge failed for table ${tableName}: $_"
        if ($originalRows.Count -gt 0) {
            try {
                Restore-TableState -TableName $tableName -OriginalRows $originalRows
                Write-Host "Restore completed successfully"
            }
            catch {
                Write-Error "Restore failed: $_"
                Write-Error "MANUAL INTERVENTION REQUIRED"
            }
        }
    }
    finally {
        Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
}
