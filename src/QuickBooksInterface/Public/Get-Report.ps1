function Get-Report {
    [CmdletBinding(DefaultParameterSetName = "None")]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ReportType,

        [Parameter(Mandatory = $true)]
        [object]$QBXMLRp,

        [Parameter(Mandatory = $true)]
        [string]$Ticket,

        [Parameter(ParameterSetName = "DateRange", Mandatory = $true)]
        [string]$FromDateRange,

        [Parameter(ParameterSetName = "DateRange", Mandatory = $false)]
        [string]$ToDateRange,

        [Parameter(ParameterSetName = "PriorDay", Mandatory = $true)]
        [switch]$PriorDay,

        [Parameter(ParameterSetName = "YTD", Mandatory = $true)]
        [switch]$YTD,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeLineItems,

        [Parameter(Mandatory = $false)]
        [string]$CustomQueryFilePath
    )

    # Check for a custom query file path
    if ($CustomQueryFilePath) {
        if (Test-Path $CustomQueryFilePath) {
            # Load the custom query file, assuming it contains a here-string XML variable named $qbxmlRequest
            . $CustomQueryFilePath  # Executes the script file to define $qbxmlRequest
            Write-Host "Using custom query from file: $CustomQueryFilePath"
        } else {
            throw "The specified file path does not exist: $CustomQueryFilePath"
        }
    }
    else {
        # Define report types for date filters
        $reportsWithModifiedDateRangeFilter = @('Invoice', 'SalesOrder', 'PurchaseOrder', 'JournalEntry')
        $reportsWithDirectDateFilter = @('Vendor', 'Account')

        # Determine the date filter based on the parameter set
        $dateFilter = ""
        switch ($PSCmdlet.ParameterSetName) {
            "PriorDay" {
                $fromDateTime = (Get-Date).AddDays(-1).Date.AddHours(0).AddMinutes(0).AddSeconds(0)
                $toDateTime = (Get-Date).AddDays(-1).Date.AddHours(23).AddMinutes(59).AddSeconds(59)
                $fromDate = $fromDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
                $toDate = $toDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
            }
            "YTD" {
                $startOfYearDateTime = (Get-Date -Year (Get-Date).Year -Month 1 -Day 1).Date.AddHours(0).AddMinutes(0).AddSeconds(0)
                $todayDateTime = (Get-Date).Date.AddHours(23).AddMinutes(59).AddSeconds(59)
                $fromDate = $startOfYearDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
                $toDate = $todayDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
            }
            "DateRange" {
                $fromDateTime = [DateTime]::Parse($FromDateRange).Date.AddHours(0).AddMinutes(0).AddSeconds(0)
                $toDateTime = if ($ToDateRange) {
                    [DateTime]::Parse($ToDateRange).Date.AddHours(23).AddMinutes(59).AddSeconds(59)
                } else {
                    (Get-Date).Date.AddHours(23).AddMinutes(59).AddSeconds(59)
                }
                $fromDate = $fromDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
                $toDate = $toDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
            }
        }

        if ($dateFilter) {
            if ($reportsWithModifiedDateRangeFilter -contains $ReportType) {
                $dateFilter = @"
<ModifiedDateRangeFilter>
  <FromModifiedDate>$fromDate</FromModifiedDate>
  <ToModifiedDate>$toDate</ToModifiedDate>
</ModifiedDateRangeFilter>
"@
            } elseif ($reportsWithDirectDateFilter -contains $ReportType) {
                $dateFilter = @"
<FromModifiedDate>$fromDate</FromModifiedDate>
<ToModifiedDate>$toDate</ToModifiedDate>
"@
            }
        }

        # Determine the IncludeLineItems setting
        $includeLineItemsElement = ""
        $reportsWithLineItems = @('Invoice', 'SalesOrder', 'PurchaseOrder', 'JournalEntry')
        if ($IncludeLineItems -and ($reportsWithLineItems -contains $ReportType)) {
            $includeLineItemsElement = "<IncludeLineItems>true</IncludeLineItems>"
        }

        # Build the query from dynamic elements if not using a custom file
        $maxReturnedElement = $script:IsTestMode ? "<MaxReturned>10</MaxReturned>" : ""

        # Build the query elements
        $queryElements = @()
        if ($dateFilter) { $queryElements += $dateFilter }
        if ($includeLineItemsElement) { $queryElements += $includeLineItemsElement }

        # Assemble the query elements with line breaks
        $queryContent = [string]::Join("`n", $queryElements)

        $qbxmlRequest = @"
<?xml version="1.0" encoding="utf-8"?>
<?qbxml version="13.0"?>
<QBXML>
  <QBXMLMsgsRq onError="continueOnError">
    <${ReportType}QueryRq requestID="2">
      $queryContent
    </${ReportType}QueryRq>
  </QBXMLMsgsRq>
</QBXML>
"@
    }

    # Send the query request to QuickBooks
    try {
        Write-Verbose "Sending query request to QuickBooks"
        $XMLResponse = $QBXMLRp.ProcessRequest($Ticket, $qbxmlRequest)
        return $XMLResponse
    }
    catch {
        throw "An error occurred: $_"
    }
}
