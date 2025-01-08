function Merge-DeltaData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyColumn,

        [Parameter(Mandatory = $false)]
        [string]$PublicSchema = "public",

        [Parameter(Mandatory = $false)]
        [string]$DeltaSchema = "delta"
    )
    

    begin {
        # Get module configuration
        $moduleRoot = $PSScriptRoot | Split-Path -Parent
        $config = Import-PowerShellDataFile -Path (Join-Path $moduleRoot "PostgreSQLConfig.psd1")
        $pgConfig = $config.PostgreSQL
    }

    process {
        try {
            # Set the PGPASSWORD environment variable
            $env:PGPASSWORD = $pgConfig.Password

            # Start transaction
            $startTransactionSQL = "BEGIN;"
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $startTransactionSQL

            # Get current date for metadata
            $currentDate = (Get-Date).ToString('yyyy-MM-dd')

            # First, let's get the exact case of the column name from PostgreSQL
            $columnCaseSQL = @"
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema = '$PublicSchema' 
AND table_name = '$TableName' 
AND lower(column_name) = lower('$KeyColumn');
"@
            $exactColumnName = (& psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $columnCaseSQL).Trim()
            
            if (-not $exactColumnName) {
                throw "Column $KeyColumn not found in table $PublicSchema.$TableName"
            }

            # Update existing records (SCD Type 3)
            $updateExistingSQL = @"
WITH matching_records AS (
    SELECT p."$exactColumnName"
    FROM "$PublicSchema"."$TableName" p
    INNER JOIN "$DeltaSchema"."$TableName" d ON p."$exactColumnName" = d."$exactColumnName"
    WHERE p.md_is_current = true
)
UPDATE "$PublicSchema"."$TableName" 
SET 
    md_is_current = false,
    md_replaced_date = '$currentDate'
WHERE "$exactColumnName" IN (SELECT "$exactColumnName" FROM matching_records)
  AND md_is_current = true;
"@
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $updateExistingSQL

            # Insert new versions of existing records
            $insertExistingSQL = @"
INSERT INTO "$PublicSchema"."$TableName" (
    SELECT d.*,
           true as md_is_current,
           '$currentDate' as md_upload_date,
           NULL as md_replaced_date
    FROM "$DeltaSchema"."$TableName" d
    INNER JOIN "$PublicSchema"."$TableName" p ON d."$exactColumnName" = p."$exactColumnName"
    WHERE p.md_is_current = false
);
"@
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $insertExistingSQL

            # Insert completely new records
            $insertNewSQL = @"
INSERT INTO "$PublicSchema"."$TableName" (
    SELECT d.*,
           true as md_is_current,
           '$currentDate' as md_upload_date,
           NULL as md_replaced_date
    FROM "$DeltaSchema"."$TableName" d
    WHERE NOT EXISTS (
        SELECT 1
        FROM "$PublicSchema"."$TableName" p
        WHERE p."$exactColumnName" = d."$exactColumnName"
    )
);
"@
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $insertNewSQL

            # Commit transaction
            $commitTransactionSQL = "COMMIT;"
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $commitTransactionSQL

            Write-Host "Successfully merged delta data into $PublicSchema.$TableName"
        }
        catch {
            # Rollback transaction if anything fails
            $rollbackTransactionSQL = "ROLLBACK;"
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $rollbackTransactionSQL
            
            Write-Error "An error occurred during merge: $_"
            throw
        }
        finally {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        }
    }
}
