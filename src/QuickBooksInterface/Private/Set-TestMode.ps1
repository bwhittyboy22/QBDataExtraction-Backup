## Set-TestMode.ps1


$script:IsTestMode = $false

<#
.SYNOPSIS
Enables the TestMode
.DESCRIPTION
Sets the TestMode value which limits the max record pull from each table to 10. Useful for testing purposes.
 
.PARAMETER Enabled
Boolean value indicating if TestMode is active.
.EXAMPLE
QuickBooksController.ps1 -Division All -ReportType All -TestMode
#>
function Set-TestMode {
    param(
        [bool]$Enabled
    )
    $script:IsTestMode = $Enabled
}

Export-ModuleMember -Function Set-TestMode