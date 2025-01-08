function Test-TableRowsEqual {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RowA,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RowB,

        [Parameter(Mandatory = $false)]
        [switch]$IgnoreMetaData
    )

    process {
        # Compare metadata
        if ($RowA.Table -ne $RowB.Table -or
            $RowA.KeyColumn -ne $RowB.KeyColumn -or
            $RowA.KeyValue -ne $RowB.KeyValue) {
            return $false
        }

        # Compare data hash tables
        $dataA = $RowA.Data
        $dataB = $RowB.Data

        # If IgnoreMetaData is enabled, filter out keys starting with "md_"
        if ($IgnoreMetaData) {
            $filteredKeysA = $dataA.Keys.Where({ -not $_.StartsWith("md_") })
            $filteredKeysB = $dataB.Keys.Where({ -not $_.StartsWith("md_") })

            # Create filtered hash tables for comparison
            $dataA = @{}
            foreach ($key in $filteredKeysA) {
                $dataA[$key] = $RowA.Data[$key]
            }

            $dataB = @{}
            foreach ($key in $filteredKeysB) {
                $dataB[$key] = $RowB.Data[$key]
            }
        }

        # Ensure both data sets have the same keys and then compare the key-value pairs
        if ($dataA.Keys.Count -ne $dataB.Keys.Count) {
            return $false
        }

        # Compare keys and their values
        foreach ($key in $dataA.Keys) {
            if (-not $dataB.ContainsKey($key) -or $dataA[$key] -ne $dataB[$key]) {
                return $false
            }
        }

        # If all checks pass, rows are equal
        return $true
    }
}
