function Get-TableColumn {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ColumnName,

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

            # Validate column exists
            $columnExists = Test-ColumnExists -TableName $TableName -ColumnName $ColumnName -TableSchema $TableSchema
            if (-not $columnExists) {
                throw "Column '$ColumnName' does not exist in table '$TableSchema.$TableName'."
            }

            # Set the PGPASSWORD environment variable
            $env:PGPASSWORD = $pgConfig.Password

            # SQL query to get column data
            $sql = @"
SELECT "$ColumnName"
FROM "$TableSchema"."$TableName"
WHERE "$ColumnName" IS NOT NULL;
"@

            # Execute the command and capture the output
            $output = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $sql

            # Process the output into an array of values
            $results = $output.Trim() -split "`n" | Where-Object { $_ -ne "" }

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
