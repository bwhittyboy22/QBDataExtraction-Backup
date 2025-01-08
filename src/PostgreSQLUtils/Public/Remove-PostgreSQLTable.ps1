function Remove-PostgreSQLTable {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TableName,

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
    }

    process {
        try {
            # Protect the extraction_log table
            if ($TableName -eq "extraction_log" -and $TableSchema -eq "public") {
                Write-Warning "The public.extraction_log table cannot be deleted via this PowerShell module for safety reasons."
                return
            }

            # Set password as environment variable for psql
            $env:PGPASSWORD = $pgConfig.Password
    
            # Combine schema and table name with proper quoting
            $QualifiedTableName = """$TableSchema"".""$TableName"""

            # Check if table exists
            $checkTableSQL = @"
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = '$TableSchema' 
    AND table_name = '$TableName'
);
"@
            $tableExists = (& psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $checkTableSQL).Trim() -eq "t"

            if (-not $tableExists) {
                Write-Warning "Table $QualifiedTableName does not exist."
                return
            }

            $operation = "Drop table"
            $target = "$TableSchema.$TableName"
                
            if (-not $Force) {
                if (-not $PSCmdlet.ShouldProcess($target, $operation)) {
                    Write-Warning "Operation cancelled by user."
                    return
                }
            }

            # Create temporary file for SQL operation
            $tempSqlFile = [System.IO.Path]::GetTempFileName()
            
            # Build SQL script with transaction handling
            $sqlScript = @"
BEGIN;

DROP TABLE $QualifiedTableName;

COMMIT;
"@

            # Save SQL script to temp file
            $sqlScript | Out-File -FilePath $tempSqlFile -Encoding UTF8
    
            # Execute the script
            $output = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -v ON_ERROR_STOP=1 -f $tempSqlFile 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                $errorDetails = $output -join "`n"
                throw "Transaction failed: $errorDetails"
            }
    
            Write-Host "Table $QualifiedTableName successfully deleted"
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