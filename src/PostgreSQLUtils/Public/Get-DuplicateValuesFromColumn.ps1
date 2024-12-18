function Get-DuplicateValuesFromColumn {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [string[]]$ColumnValues
    )

    
    begin {
        # Initialize an array to store all values if receiving from pipeline
        $allValues = @()
    }

    process {
        # If receiving from pipeline, accumulate values
        if ($PSCmdlet.MyInvocation.ExpectingInput) {
            $allValues += $ColumnValues
        }
        else {
            $allValues = $ColumnValues
        }
    }

    end {
        try {
            # Group the values and find those that appear more than once
            $duplicates = $allValues | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name

            # If no duplicates found, return empty array rather than null
            if (-not $duplicates) {
                return @()
            }

            return $duplicates
        }
        catch {
            Write-Error "An error occurred while finding duplicate values: $_"
            return @()
        }
    }
}
