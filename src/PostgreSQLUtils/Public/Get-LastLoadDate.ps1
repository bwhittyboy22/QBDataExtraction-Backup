function Get-LastLoadDate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TableName
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

            # SQL query with proper quoting
            $sql = 'SELECT "lastupddte" FROM "extraction_log" WHERE "tablename" = ''' + $TableName + ''';'

            # Execute the command and capture the output
            $output = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $sql

            # Process and return the result
            $result = $output.Trim() -split "`n" | Where-Object { $_ -ne "" } | Select-Object -First 1
            
            if ($result) {
                return [datetime]$result
            }
            return $null
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