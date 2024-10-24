

function Start-SessionInQuickBooks {

    param(
        [object]$QBxmlrp,
        [string]$CompanyFilePath
    )

    try {
        $openMode = 2  # 2 corresponds to omDontCare
        $ticket = $qbxmlrp.BeginSession($CompanyFilePath, $openMode)
        Write-Verbose "BeginSession successful"
        return $ticket
    } catch {
        Write-Verbose "Failed to begin session"
        throw $_
    }

}