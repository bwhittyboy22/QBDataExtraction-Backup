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

        # Compare data hash tables
        $dataA = $RowA.Data
        $dataB = $RowB.Data

        # Ensure both data sets have the same keys and then compare the key-value pair
        if ($dataA.Keys.Count -ne $dataB.Keys.Count) {
            return $false
        }

        if (-not ($dataA.Keys | Sort-Object | Compare-Object -ReferenceObject ($dataB.Keys | Sort-Object) -ExcludeDifferent)) {
            return $false
        }

        foreach ($key in $dataA.Keys) {
            if ($dataA[$key] -ne $dataB[$key]) {
                return $false
            }
        }

        # If all checks pass, rows are equal
        return $true
    }
}
