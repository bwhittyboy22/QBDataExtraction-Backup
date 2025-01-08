function Restore-TableState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [array]$OriginalRows,

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
            # Set the PGPASSWORD environment variable
            $env:PGPASSWORD = $pgConfig.Password

            # Start transaction
            $startTransactionSQL = "BEGIN;"
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $startTransactionSQL

            foreach ($row in $OriginalRows) {
                # Create update statement for each row
                $updateSQL = @"
UPDATE "$TableSchema"."$TableName"
SET
    md_is_current = $($row.Data.md_is_current),
    md_upload_date = '$($row.Data.md_upload_date)',
    md_replaced_date = $(if ($row.Data.md_replaced_date) { "'$($row.Data.md_replaced_date)'" } else { "NULL" })
WHERE "$($row.KeyColumn)" = '$($row.KeyValue)';
"@
                & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $updateSQL
            }

            # Commit transaction
            $commitTransactionSQL = "COMMIT;"
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $commitTransactionSQL

            Write-Host "Successfully restored table state for $TableSchema.$TableName"
        }
        catch {
            # Rollback transaction if anything fails
            $rollbackTransactionSQL = "ROLLBACK;"
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $rollbackTransactionSQL
            
            Write-Error "An error occurred during restore: $_"
            throw
        }
        finally {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        }
    }
}