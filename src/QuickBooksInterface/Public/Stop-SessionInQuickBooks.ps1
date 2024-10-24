

<#
.SYNOPSIS
Stops a QuickBooks session.

.DESCRIPTION
This function ends a QuickBooks session using the provided QBXMLRP2.RequestProcessor object and session ticket.

.PARAMETER qbxmlrp
The QBXMLRP2.RequestProcessor object used for the session.

.PARAMETER ticket
The session ticket to end.

.EXAMPLE
Stop-SessionInQuickBooks -qbxmlrp $qbxmlrp -ticket $ticket
#>
function Stop-SessionInQuickBooks {
    param (
        [object]$qbxmlrp,
        [string]$ticket
    )
    try {
        $qbxmlrp.EndSession($ticket)
        Write-Verbose "Session stopped"
    } catch {
        Write-Verbose "Error stopping session"
        throw [System.InvalidOperationException]::new("Failed to stop session: ", $_.Exception)
    }
}