# Get-Report.ps1


function Get-Report {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ReportType,

        [Parameter(Mandatory=$true)]
        [object]$QBXMLRp,

        [Parameter(Mandatory=$true)]
        [string]$Ticket,

        [Parameter(Mandatory=$false)]
        [string]$FromDateRange,

        [Parameter(Mandatory=$false)]
        [string]$ToDateRange,

        [Parameter(Mandatory=$false)]
        [ValidateSet("EntireTable", "DateFiltered")]
        [string]$FilterType = "EntireTable"
    )

    try {
        $dateFilter = ""
        if ($FilterType -eq "DateFiltered" -and $FromDateRange -and $ToDateRange) {
            $dateFilter = "<ModifiedDateRangeFilter>
                               <FromModifiedDate>$FromDateRange</FromModifiedDate>
                               <ToModifiedDate>$ToDateRange</ToModifiedDate>
                           </ModifiedDateRangeFilter>"
        }
        
        $maxReturnedElement = $script:IsTestMode ? "<MaxReturned>10</MaxReturned>" : ""
        
        $qbxmlRequest = @"
        <?qbxml version="13.0"?>
        <QBXML>
          <QBXMLMsgsRq onError="continueOnError">
            <${ReportType}QueryRq requestID="2">
              $dateFilter
              $maxReturnedElement
            </${ReportType}QueryRq>
          </QBXMLMsgsRq>
        </QBXML>
"@
        Write-Verbose "Sending query request to QuickBooks"
        $XMLResponse = $QBXMLRp.ProcessRequest($Ticket, $qbxmlRequest)
               
        return $XMLResponse
    }
    catch {
        throw "An error occured: $_"
    } 
}
