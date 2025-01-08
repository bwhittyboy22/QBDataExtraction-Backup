function Get-TableRow {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyColumn,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyValue,

        [Parameter(Mandatory = $false)]
        [string]$TableSchema = "public"
    )
    

    begin {
        # Get module configuration
        $moduleRoot = $PSScriptRoot | Split-Path -Parent
        $config = Import-PowerShellDataFile -Path (Join-Path $moduleRoot "PostgreSQLConfig.psd1")
        $pgConfig = $config.PostgreSQL
    }

    process {
        try {
            # Validate table exists
            $tableExists = Test-TableExists -TableName $TableName -TableSchema $TableSchema
            if (-not $tableExists) {
                throw "Table '$TableSchema.$TableName' does not exist."
            }

            # Validate key column exists
            $columnExists = Test-ColumnExists -TableName $TableName -ColumnName $KeyColumn -TableSchema $TableSchema
            if (-not $columnExists) {
                throw "Key column '$KeyColumn' does not exist in table '$TableSchema.$TableName'."
            }

            # Set the PGPASSWORD environment variable
            $env:PGPASSWORD = $pgConfig.Password

            # SQL query to fetch column headers and row data
            $sql = @"
SELECT *
FROM "$TableSchema"."$TableName"
WHERE "$KeyColumn" = '$KeyValue';
"@

            # Get column headers
            $headerSql = @"
SELECT column_name
FROM information_schema.columns
WHERE table_schema = '$TableSchema'
  AND table_name = '$TableName';
"@

            # Execute SQL queries
            $headersOutput = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $headerSql
            $rowOutput = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -F"," -c $sql

            # Process headers and row into a key-value structure
            $results = @()
            if ($rowOutput -ne "" -and $headersOutput -ne "") {
                $headers = $headersOutput.Trim().Split("`n")
                $values = $rowOutput.Split(",")
                
                # Create a key-value pair for headers and values
                $data = @{}
                for ($i = 0; $i -lt $headers.Count; $i++) {
                    $data[$headers[$i]] = $values[$i]
                }

                $results = [PSCustomObject]@{
                    Table = $TableName
                    KeyColumn = $KeyColumn
                    KeyValue = $KeyValue
                    Data = $data
                }
            }

            # Return the results
            return $results
        }
        catch {
            Write-Error "An error occurred: $_"
            return $null
        }
        finally {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        }
    }
}
