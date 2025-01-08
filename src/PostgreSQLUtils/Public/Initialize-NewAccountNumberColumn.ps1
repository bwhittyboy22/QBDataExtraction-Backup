function Initialize-NewAccountNumberColumn {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TableSchema = "public",

        [Parameter()]
        [ValidateSet("fp", "ech", "pch", "ssi")]
        [string[]]$Division = @("fp", "ech", "pch", "ssi")
    )

    begin {
        $moduleRoot = $PSScriptRoot | Split-Path -Parent
        $config = Import-PowerShellDataFile -Path (Join-Path $moduleRoot "PostgreSQLConfig.psd1")
        $pgConfig = $config.PostgreSQL
    }

    process {
        try {
            $env:PGPASSWORD = $pgConfig.Password

            # Add the new column if it doesn't exist
            $addColumnSQL = 'ALTER TABLE "' + $TableSchema + '"."account" ADD COLUMN IF NOT EXISTS "account_number" VARCHAR(50);'
            & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $addColumnSQL

            foreach ($div in $Division) {
                if ($div -eq "fp") {
                    # Update FP accounts - find pattern xxxxx-xx-xxx
                    $updateFPSQL = @"
                    UPDATE "$TableSchema"."account" 
                    SET "account_number" = 
                        CASE 
                            WHEN "AccountNumber" ~ '\d{5}-\d{2}-\d{3}' 
                            THEN regexp_matches("AccountNumber", '\d{5}-\d{2}-\d{3}')::text[]
                            ELSE 'N/A' 
                        END
                    WHERE LOWER("division") = 'fp';
"@
                    & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $updateFPSQL
                }
                else {
                    # Update other divisions - extract text before first hyphen
                    $updateOtherSQL = @"
                    UPDATE "$TableSchema"."account"
                    SET "account_number" = 
                        CASE 
                            WHEN position('-' in "AccountNumber") > 0 
                            THEN trim(substring("AccountNumber" from 1 for position('-' in "AccountNumber") - 1))
                            ELSE 'N/A' 
                        END
                    WHERE LOWER("division") = '$div';
"@
                    & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $updateOtherSQL
                }

                Write-Host "Successfully updated account_number column for division: $div"
            }
        }
        catch {
            Write-Error "An error occurred: $_"
        }
        finally {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        }
    }
}