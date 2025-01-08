function Set-LastLoadDate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [datetime]$LoadDate
    )

    begin {
        # Get module configuration
        $moduleRoot = $PSScriptRoot | Split-Path -Parent
        $config = Import-PowerShellDataFile -Path (Join-Path $moduleRoot "PostgreSQLConfig.psd1")
        $pgConfig = $config.PostgreSQL

        # Validate LoadDate is not in the future
        if ($LoadDate.Date -gt (Get-Date).Date) {
            throw "LoadDate cannot be in the future. Provided date: $($LoadDate.ToString('yyyy-MM-dd'))"
        }
    }

    process {
        try {
            # Set the PGPASSWORD environment variable
            $env:PGPASSWORD = $pgConfig.Password

            # Format the date in YYYY-MM-DD format for PostgreSQL
            $formattedDate = $LoadDate.ToString('yyyy-MM-dd')

            # First check if the record exists
            $checkSQL = 'SELECT COUNT(*) FROM "extraction_log" WHERE "tablename" = ''' + $TableName + ''';'
            $exists = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $checkSQL

            if ($exists.Trim() -eq "0") {
                # Insert new record
                $insertSQL = 'INSERT INTO "extraction_log" ("tablename", "lastupddte") VALUES (''' + $TableName + ''', ''' + $formattedDate + ''');'
                & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $insertSQL
            }
            else {
                # Update existing record
                $updateSQL = 'UPDATE "extraction_log" SET "lastupddte" = ''' + $formattedDate + ''' WHERE "tablename" = ''' + $TableName + ''';'
                & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -c $updateSQL
            }

            Write-Host "Successfully updated last load date for table '$TableName' to $formattedDate"
        }
        catch {
            Write-Error "An error occurred: $_"
        }
        finally {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        }
    }
}