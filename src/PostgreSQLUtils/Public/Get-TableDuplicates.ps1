function Get-TableDuplicates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyColumn,

        [Parameter(Mandatory = $false)]
        [string]$TableSchema = "public"
    )
    

    begin {
        $moduleRoot = $PSScriptRoot | Split-Path -Parent
        $config = Import-PowerShellDataFile -Path (Join-Path $moduleRoot "PostgreSQLConfig.psd1")
        $pgConfig = $config.PostgreSQL
    }

    process {
        try {
            $env:PGPASSWORD = $pgConfig.Password
            
            $duplicatesSQL = @"
SELECT "$KeyColumn", COUNT(*) as duplicate_count
FROM "$TableSchema"."$TableName"
GROUP BY "$KeyColumn"
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;
"@
            $duplicates = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $duplicatesSQL
            return $duplicates
        }
        catch {
            Write-Error "Error checking for duplicates: $_"
            return $null
        }
        finally {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        }
    }
}
