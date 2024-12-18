function ConvertTo-PostgreSQLTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$CSVFilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$PostgresTableName,

        [Parameter(Mandatory = $false)]
        [string]$TableSchema = "public"  # Optional schema parameter
    )

    begin {
        # Get module configuration
        $moduleRoot = $PSScriptRoot | Split-Path -Parent
        $config = Import-PowerShellDataFile -Path (Join-Path $moduleRoot "PostgreSQLConfig.psd1")
        $pgConfig = $config.PostgreSQL

        # Validate CSV file exists
        if (-not (Test-Path $CSVFilePath)) {
            throw "CSV file not found: $CSVFilePath"
        }
    }

    process {
        try {
            # Set password as environment variable for psql
            $env:PGPASSWORD = $pgConfig.Password
    
            # Combine schema and table name
            $QualifiedTableName = "$TableSchema.$PostgresTableName"
    
            # Read the CSV file to get headers
            $csvHeaders = (Get-Content $CSVFilePath -First 1).Split(',') | 
                ForEach-Object { $_.Trim('"') }
    
            # Create table schema based on CSV headers
            $columns = $csvHeaders | ForEach-Object { """$_"" TEXT" }
            $createTableSQL = "CREATE TABLE IF NOT EXISTS $QualifiedTableName ($($columns -join ', '));"
    
            # Save SQL to temporary file
            $tempSqlFile = [System.IO.Path]::GetTempFileName()
            $createTableSQL | Out-File -FilePath $tempSqlFile -Encoding UTF8
    
            # Execute table creation and check success
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -f $tempSqlFile
            if ($LASTEXITCODE -ne 0) {
                throw "Table creation failed for $QualifiedTableName. Ensure the schema exists and you have the correct permissions."
            }
            Remove-Item $tempSqlFile
    
            # Import the CSV file using COPY command
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c `
                "\COPY $QualifiedTableName FROM '$CSVFilePath' WITH CSV HEADER"
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to import CSV file to table $QualifiedTableName. Verify the file format and table structure."
            }
    
            Write-Host "CSV file successfully imported to table $QualifiedTableName"
        }
        catch {
            Write-Error "An error occurred: $_"
        }
        finally {
            $env:PGPASSWORD = ""
            if ($tempSqlFile -and (Test-Path $tempSqlFile)) {
                Remove-Item $tempSqlFile
            }
        }
    }    
}
