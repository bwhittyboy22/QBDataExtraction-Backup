function Get-TableRows {
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
        [string[]]$KeyValues,

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

            # Create a temporary table for the key values
            $createTempSQL = @"
CREATE TEMP TABLE temp_keys (key_value text);
"@
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $createTempSQL

            # Insert key values into temp table
            $valuesList = $KeyValues -join "`n"
            $copySQL = "COPY temp_keys FROM STDIN;"
            $valuesList | & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $copySQL

            # SQL query to fetch column headers and row data
            $sql = @"
WITH matched_rows AS (
    SELECT *
    FROM "$TableSchema"."$TableName"
    WHERE "$KeyColumn"::text IN (SELECT key_value FROM temp_keys)
)
SELECT row_to_json(matched_rows)::text
FROM matched_rows;
"@

            # Execute SQL query
            $rowsOutput = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $sql

            # Process results
            $results = @()
            foreach ($row in $rowsOutput) {
                if ($row -ne "") {
                    $data = $row | ConvertFrom-Json
                    $results += [PSCustomObject]@{
                        Table = $TableName
                        KeyColumn = $KeyColumn
                        KeyValue = $data.$KeyColumn
                        Data = $data
                    }
                }
            }

            # Cleanup temp table
            $dropTempSQL = "DROP TABLE temp_keys;"
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $dropTempSQL

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
