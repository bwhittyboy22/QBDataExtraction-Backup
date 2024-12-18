function ConvertTo-PostgreSQLTable {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$CSVFilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$PostgresTableName,

        [Parameter(Mandatory = $false)]
        [string]$TableSchema = "public",

        [Parameter(Mandatory = $false)]
        [switch]$Force
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
    
            # Combine schema and table name with proper quoting
            $QualifiedTableName = """$TableSchema"".""$PostgresTableName"""

            # Check if table exists
            $checkTableSQL = @"
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = '$TableSchema' 
    AND table_name = '$PostgresTableName'
);
"@
            $tableExists = (& psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $checkTableSQL).Trim() -eq "t"

            if ($tableExists -and $TableSchema -eq "public") {
                $operation = "Truncate and reload"
                $target = "$TableSchema.$PostgresTableName"
                
                if (-not $Force) {
                    if (-not $PSCmdlet.ShouldProcess($target, $operation)) {
                        Write-Warning "Operation cancelled by user. Table $QualifiedTableName already exists."
                        return
                    }
                }
            }
    
            # Read the CSV file to get headers
            $csvHeaders = (Get-Content $CSVFilePath -First 1).Split(',') | 
                ForEach-Object { $_.Trim('"') }
    
            # Create column definitions based on schema
            $columns = if ($TableSchema -eq "public") {
                # For public schema (master tables), add the tracking columns
                $baseColumns = $csvHeaders | ForEach-Object { """$_"" TEXT" }
                $baseColumns + @(
                    """IsCurrent"" BOOLEAN DEFAULT TRUE",
                    """UploadDate"" TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
                    """LastUpdated"" TIMESTAMP"
                )
            } else {
                # For other schemas (staging/delta tables), just use the CSV columns
                $csvHeaders | ForEach-Object { """$_"" TEXT" }
            }

            # Create temporary file for all SQL operations
            $tempSqlFile = [System.IO.Path]::GetTempFileName()
            
            # Build the column list for COPY command
            $columnList = ($csvHeaders | ForEach-Object { """$_""" }) -join ','
            
            # Build SQL script with transaction handling
            $sqlScript = @"
BEGIN;

"@
            
            if (-not $tableExists) {
                $sqlScript += @"
-- Create table if it doesn't exist
CREATE TABLE $QualifiedTableName (
    $($columns -join ',')
);

"@
            } elseif ($TableSchema -eq "public") {
                $sqlScript += @"
-- Truncate existing public table
TRUNCATE TABLE $QualifiedTableName;

"@
            } elseif ($TableSchema -ne "public") {
                $sqlScript += @"
-- Truncate existing non-public table
TRUNCATE TABLE $QualifiedTableName;

"@
            }

            # Add COPY command
            $sqlScript += @"
-- Copy data
\COPY $QualifiedTableName($columnList) FROM '$CSVFilePath' WITH CSV HEADER;

COMMIT;
"@

            # Save SQL script to temp file
            $sqlScript | Out-File -FilePath $tempSqlFile -Encoding UTF8
    
            # Execute the entire script
            $output = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -v ON_ERROR_STOP=1 -f $tempSqlFile 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                $errorDetails = $output -join "`n"
                throw "Transaction failed: $errorDetails"
            }
    
            Write-Host "CSV file successfully imported to table $QualifiedTableName"
        }
        catch {
            Write-Error "An error occurred: $_"
            throw
        }
        finally {
            $env:PGPASSWORD = ""
            if ($tempSqlFile -and (Test-Path $tempSqlFile)) {
                Remove-Item $tempSqlFile
            }
        }
    }    
}