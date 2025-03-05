param(
    [switch]$IncludeDeltaTables,
    [Parameter(Mandatory = $false)]
    [string[]]$DivisionPublicTableToDrop = @("FP", "ECH", "PCH", "SSI")
)

Import-Module ".\src\PostgreSQLUtils\PostgreSQLUtils.psd1" -Force
Import-Module ".\src\QuickBooksInterface\QuickBooksInterface.psd1" -Force

# Drop tables based on provided divisions
foreach ($division in $DivisionPublicTableToDrop) {
    $tableName = "${division}_transactions".ToLower()
    Remove-PostgreSQLTable -TableName $tableName -TableSchema "public"
    
    if ($IncludeDeltaTables) {
        Remove-PostgreSQLTable -TableName $tableName -TableSchema "delta"
    }
}

$uploadDate = "2024-11-13"
$baseFilePath = "C:\Users\BenjaminW.admin\Documents\QBFileExports\20241114"

# Process each division
foreach ($division in $DivisionPublicTableToDrop) {
    $tableName = "${division}_transactions".ToLower()
    $csvFile = Join-Path $baseFilePath "Transactions_${division}_20241113_2034.csv"
    
    try {
        ConvertTo-PostgreSQLTable2 -CSVFilePath $csvFile -PostgresTableName $tableName -TableSchema "public" -MDUploadDate $uploadDate
        Start-Sleep -Seconds 2
        Set-LastLoadDate -TableName $tableName -LoadDate $uploadDate
    }
    catch {
        Write-Error "Couldn't process table for $division. Error: $_"
    }
}