# Database connection parameters
$pgServer = "localhost"
$pgPort = "5432"
$pgDatabase = "AmquipQBExtraction"
$pgUsername = "postgres"
$pgPassword = "REMOVES-handles-dreaded-remained"  # Your password here

# CSV file path
$csvPath = "C:\Users\BenjaminW.admin\Documents\QBFileExports\20241114\Transactions_ECH_20241113_2034.csv"
$tableName = "ECH_Transactions"

# Set password as environment variable for psql
$env:PGPASSWORD = $pgPassword

try {
    # Read the CSV file to get headers
    $csvHeaders = (Get-Content $csvPath -First 1).Split(',') | ForEach-Object { $_.Trim('"') }

    # Create table schema based on CSV headers
    $columns = $csvHeaders | ForEach-Object { """$_"" TEXT" }
    $createTableSQL = "CREATE TABLE IF NOT EXISTS $tableName ($($columns -join ', '));"

    # Save SQL to a temporary file to avoid command line parsing issues
    $tempSqlFile = [System.IO.Path]::GetTempFileName()
    $createTableSQL | Out-File -FilePath $tempSqlFile -Encoding UTF8

    # Execute the SQL from file
    & psql -h $pgServer -p $pgPort -d $pgDatabase -U $pgUsername -f $tempSqlFile
    Remove-Item $tempSqlFile

    # Import the CSV file using a simpler COPY command
    & psql -h $pgServer -p $pgPort -d $pgDatabase -U $pgUsername -c "\COPY $tableName FROM '$csvPath' WITH CSV HEADER"
    
    Write-Host "CSV file successfully imported to table $tableName"
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    # Clear the password from environment variables
    $env:PGPASSWORD = ""
    if (Test-Path $tempSqlFile) {
        Remove-Item $tempSqlFile
    }
}