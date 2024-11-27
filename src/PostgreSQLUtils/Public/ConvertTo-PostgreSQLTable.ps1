function ConvertTo-PostgreSQLTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$CSVFilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$PostgresTableName
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

            # Read the CSV file to get headers
            $csvHeaders = (Get-Content $CSVFilePath -First 1).Split(',') | 
                ForEach-Object { $_.Trim('"') }

            # Create table schema based on CSV headers
            $columns = $csvHeaders | ForEach-Object { """$_"" TEXT" }
            $createTableSQL = "CREATE TABLE IF NOT EXISTS $PostgresTableName ($($columns -join ', '));"

            # Save SQL to a temporary file to avoid command line parsing issues
            $tempSqlFile = [System.IO.Path]::GetTempFileName()
            $createTableSQL | Out-File -FilePath $tempSqlFile -Encoding UTF8

            # Execute the SQL from file
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -f $tempSqlFile
            Remove-Item $tempSqlFile

            # Import the CSV file using COPY command
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c `
                "\COPY $PostgresTableName FROM '$CSVFilePath' WITH CSV HEADER"
            
            Write-Host "CSV file successfully imported to table $PostgresTableName"
        }
        catch {
            Write-Error "An error occurred: $_"
        }
        finally {
            $env:PGPASSWORD = ""
            if (Test-Path $tempSqlFile) {
                Remove-Item $tempSqlFile
            }
        }
    }
}