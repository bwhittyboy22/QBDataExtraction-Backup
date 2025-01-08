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

            # SQL query to get the row data
            $sql = @"
SELECT *
FROM "$TableSchema"."$TableName"
WHERE "$KeyColumn" = '$KeyValue';
"@

            # Execute the command and capture the output
            $output = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -F"," -c $sql

            # Process the output into a structured object
            $results = @()
            if ($output -ne "") {
                $columns = $output.Split(",")
                $results = [PSCustomObject]@{
                    Table = $TableName
                    KeyColumn = $KeyColumn
                    KeyValue = $KeyValue
                    Data = $columns
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
