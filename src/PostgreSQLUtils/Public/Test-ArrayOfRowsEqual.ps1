function Test-ArrayOfRowsEqual {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$MasterRows,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$DeltaRows,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyProperty,

        [Parameter(Mandatory = $false)]
        [Switch]$IgnoreMetaData,

        [Parameter(Mandatory = $false)]
        [Switch]$ShowRows
    )


    process {
        # Sort both arrays by the KeyProperty
        $sortedMasterRows = $MasterRows | Sort-Object -Property $KeyProperty
        $sortedDeltaRows = $DeltaRows | Sort-Object -Property $KeyProperty

        # Initialize equality flag
        $areEqual = $true

        # Check for matching row counts
        if ($sortedMasterRows.Count -ne $sortedDeltaRows.Count) {
            Write-Host "The arrays have different row counts."
            return $false
        }

        # Compare rows
        for ($i = 0; $i -lt $sortedMasterRows.Count; $i++) {
            $masterRow = $sortedMasterRows[$i]
            $deltaRow = $sortedDeltaRows[$i]

            if (-not (Test-TableRowsEqual -RowA $masterRow -RowB $deltaRow -IgnoreMetaData:$IgnoreMetaData)) {
                Write-Host "Mismatch found at index $i"
                if ($ShowRows) {
                    Write-Host "Master Row: $($masterRow.Data | Format-Table | Out-String)"
                    Write-Host "Delta Row:  $($deltaRow.Data | Format-Table | Out-String)"
                }
                $areEqual = $false
                break
            }
        }

        return $areEqual
    }
}
