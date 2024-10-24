function Start-OpenConnection2ForQuickBooks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DivisionName
    )

    # Create COM Object
    try {
        $qbxmlrp = New-Object -ComObject QBXMLRP2.RequestProcessor
    }
    catch {
        throw [System.Runtime.InteropServices.COMException]::new("Could not create COM object for division '$DivisionName'.", $_.Exception)
    }

    # Open Connection
    try {
        $connType = 1  # 1 corresponds to localQBD
        $qbxmlrp.OpenConnection2("", "${DivisionName}QBAutomation", $connType)
        Write-Verbose "OpenConnection2 successful for ${DivisionName}"
        return $qbxmlrp
    }
    catch {
        Write-Verbose "OpenConnection2 failed for ${DivisionName}"
        throw [System.InvalidOperationException]::new("Connection failed for '${DivisionName}'.", $_.Exception)
    }
}
