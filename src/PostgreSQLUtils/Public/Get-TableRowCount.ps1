function Get-TableRowCount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName,

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
            
            $countSQL = @"
SELECT COUNT(*)
FROM "$TableSchema"."$TableName";
"@
            $count = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $countSQL
            return [int]$count
        }
        catch {
            Write-Error "Error getting row count: $_"
            return -1
        }
        finally {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        }
    }
}