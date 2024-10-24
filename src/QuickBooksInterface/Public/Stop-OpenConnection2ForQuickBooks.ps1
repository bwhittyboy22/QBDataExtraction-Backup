function Stop-OpenConnection2ForQuickBooks {
    param (
        [Parameter(Mandatory = $true)]
        [object]$QBxmlrp
    )

    # Validate the COM object
    if ($null -eq $QBxmlrp) {
        throw [System.ArgumentNullException]::new("qbxmlrp", "The QBXMLRP2.RequestProcessor COM object cannot be null.")
    }

    try {
        # Attempt to close the connection
        $QBxmlrp.CloseConnection()
        Write-Verbose "Connection closed successfully."

        # Release the COM object to free up resources
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($QBxmlrp)
        Write-Verbose "COM object released."
        
        # Optionally set the object to null to aid garbage collection
        $QBxmlrp = $null
    }
    catch {
        Write-Verbose "Error closing connection."
        throw [System.InvalidOperationException]::new("Failed to close the QuickBooks connection.", $_.Exception)
    }
}
