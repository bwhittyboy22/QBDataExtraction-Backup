function Test-TableExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TableName,

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

            # SQL query to check if table exists
            $sql = @"
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = '$TableSchema' 
    AND table_name = '$TableName'
);
"@

            # Execute the command and capture the output
            $output = & psql -h $pgConfig.Server -p $pgConfig.Port -d $pgConfig.Database -U $pgConfig.Username -t -A -c $sql

            # Convert the PostgreSQL boolean output to PowerShell boolean
            $exists = $output.Trim() -eq "t"
            
            return $exists
        }
        catch {
            Write-Error "An error occurred while checking table existence: $_"
            return $false
        }
        finally {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        }
    }
}
