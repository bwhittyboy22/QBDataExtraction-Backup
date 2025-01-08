function Test-TableRowsEqual {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RowA,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RowB
    )
    

    process {
        # Compare metadata
        if ($RowA.Table -ne $RowB.Table -or
            $RowA.KeyColumn -ne $RowB.KeyColumn -or
            $RowA.KeyValue -ne $RowB.KeyValue) {
            return $false
        }

        # Compare data arrays
        $dataA = $RowA.Data
        $dataB = $RowB.Data

        # Ensure lengths are the same
        if ($dataA.Count -ne $dataB.Count) {
            return $false
        }

        # Compare each element
        for ($i = 0; $i -lt $dataA.Count; $i++) {
            if ($dataA[$i] -ne $dataB[$i]) {
                return $false
            }
        }

        # If all checks pass, rows are equal
        return $true
    }
}
