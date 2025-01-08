Import-Module ".\src\PostgreSQLUtils\PostgreSQLUtils.psd1" -Force
Import-Module ".\src\QuickBooksInterface\QuickBooksInterface.psd1" -Force

$CompanyFilePath = Get-Content "C:\Users\BenjaminW.admin\Developer\QBDataExtraction\CompanyFIlePaths.json" -Raw | ConvertFrom-Json
$Results = @{}

# Loop through each property name and add it to $Results
foreach ($divisionName in $CompanyFilePath.PSObject.Properties.Name) {
    ##################################################################################################################
    # Get date of last update from PostgreSQL table                                                                  #
    ##################################################################################################################
    $division_transactions = "${divisionName}_transactions"

    # Ensure Get-LastLoadDate doesn't fail silently
    try {
        $extractionDate = Get-LastLoadDate -TableName $division_transactions -ErrorAction SilentlyContinue
        $queryFormattedDate = $extractionDate.ToString("yyyy-MM-dd")
        Write-Output "Date of last upload for ${divisionName}: $queryFormattedDate"
    } catch {
        Write-Error "Failed to get last load date for ${divisionName}. Error: $_"
        continue
    }

    ##################################################################################################################
    # Query QB from the last update date and current date                                                            #
    ##################################################################################################################
    $CompanyFilePath.$divisionName
    $result = Get-Transactions -FromDate $queryFormattedDate -DivisionName $divisionName -CompanyFilePath $CompanyFilePath.$divisionName
  

    if ($result.success) {
        $Results[$divisionName] = $result
        Write-Output "Successfully processed $divisionName"
    } else {
        Write-Error "Failed to process $divisionName : $($result.error)"
    }

    Start-Sleep -Seconds 3

}

##################################################################################################################
# Convert XML document to CSV                                                                                    #
##################################################################################################################
# Create new hashtable to store converted paths
$ConvertedResults = @{}
foreach ($division in $Results.Keys) {
    $csvOutputPath = $Results[$division].deltaCSVPath -replace '\.xml$', '.csv'
    Convert-QBXMLtoCSV -ReportType "Transaction" -XMLFilePath $Results[$division].deltaCSVPath -OutputPath $csvOutputPath
    $ConvertedResults[$division] = @{ deltaCSVPath = $csvOutputPath }
}
$Results = $ConvertedResults

##################################################################################################################
# Upload CSV file to PostgreSQL server                                                                           #
##################################################################################################################
foreach ($division in $Results.Keys) {
    try {
        $filePath = $Results[$division].deltaCSVPath
        if ($filePath -notmatch '\.csv$') {
            Write-Error "Invalid file type for $division. Expected CSV file."
            continue
        }
        Write-Output "Uploading DELTA CSV file to PostgreSQL table"
        Write-Output "Division: $division"
        Write-Output "File Path: $filePath"
        ConvertTo-PostgreSQLTable2 -CSVFilePath $filePath -PostgresTableName "${division}_transactions" -TableSchema "delta"
        Write-Output "DELTA table creation complete"
    }
    catch {
        Write-Error "Failed to create DELTA table for: $division"
        Write-Error "Error: $_"
    }
}

& "$PSScriptRoot\MergeTransactionTables.ps1"
