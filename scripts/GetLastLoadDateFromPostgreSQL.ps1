# Database connection parameters
$pgServer = "localhost"
$pgPort = "5432"
$pgDatabase = "AmquipQBExtraction"
$pgUsername = "postgres"
$pgPassword = "REMOVES-handles-dreaded-remained" 

# SQL query with proper quoting for case-sensitive table and column names
$sql = 'SELECT "LastUpdDte" FROM "ExtractionLog" WHERE "TableName" = ''ech_transactions'';'

# Set the PGPASSWORD environment variable for password authentication
$env:PGPASSWORD = $pgPassword

try {
    # Execute the command and capture the output
    $output = & psql -h $pgServer -p $pgPort -d $pgDatabase -U $pgUsername -t -A -c $sql

    # Trim whitespace and split the output into lines
    $outputLines = $output.Trim() -split "`n"

    # Filter out any empty lines
    $outputLines = $outputLines | Where-Object { $_ -ne "" }

    # Display the result
    foreach ($line in $outputLines) {
        Write-Host "LastUpdDte: $line"
    }
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    # Remove the PGPASSWORD from the environment variables for security
    Remove-Item Env:PGPASSWORD
}