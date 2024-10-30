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
      [switch]$PriorDay,

      [Parameter(Mandatory=$false)]
      [switch]$YTD,

      [Parameter(Mandatory=$false)]
      [switch]$IncludeLineItems
  )

  # Ensure there are no conflicting date filters
  if ($PriorDay -and $YTD) {
      throw "Cannot use both -PriorDay and -YTD switches simultaneously."
  }

  # Ensure ToDateRange is not provided without FromDateRange
  if ($ToDateRange -and -not $FromDateRange) {
      throw "ToDateRange cannot be specified without FromDateRange. Please provide FromDateRange or use a different filter option."
  }

  # Determine the date filter
  $dateFilter = ""
  if ($PriorDay) {
      # Use prior day date range
      $yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
      $dateFilter = "<ModifiedDateRangeFilter>
                         <FromModifiedDate>$yesterday</FromModifiedDate>
                         <ToModifiedDate>$yesterday</ToModifiedDate>
                     </ModifiedDateRangeFilter>"
  }
  elseif ($YTD) {
      # Use Year-to-Date filter
      $startOfYear = (Get-Date -Year (Get-Date).Year -Month 1 -Day 1).ToString("yyyy-MM-dd")
      $today = (Get-Date).ToString("yyyy-MM-dd")
      $dateFilter = "<ModifiedDateRangeFilter>
                         <FromModifiedDate>$startOfYear</FromModifiedDate>
                         <ToModifiedDate>$today</ToModifiedDate>
                     </ModifiedDateRangeFilter>"
  }
  elseif ($FromDateRange) {
      # Use custom date range filter
      if (-not $ToDateRange) {
          $ToDateRange = (Get-Date).ToString("yyyy-MM-dd") # Default to current date if ToDateRange is not provided
      }

      $dateFilter = "<ModifiedDateRangeFilter>
                         <FromModifiedDate>$FromDateRange</FromModifiedDate>
                         <ToModifiedDate>$ToDateRange</ToModifiedDate>
                     </ModifiedDateRangeFilter>"
  }

  # Determine the IncludeLineItems setting
  $includeLineItemsElement = ""
  if ($IncludeLineItems) {
      $includeLineItemsElement = "<IncludeLineItems>true</IncludeLineItems>"
  }

  try {
      $maxReturnedElement = $script:IsTestMode ? "<MaxReturned>10</MaxReturned>" : ""

      $qbxmlRequest = @"
      <?qbxml version="13.0"?>
      <QBXML>
        <QBXMLMsgsRq onError="continueOnError">
          <${ReportType}QueryRq requestID="2">
            $dateFilter
            $maxReturnedElement
            $includeLineItemsElement
          </${ReportType}QueryRq>
        </QBXMLMsgsRq>
      </QBXML>
"@
      Write-Verbose "Sending query request to QuickBooks"
      $XMLResponse = $QBXMLRp.ProcessRequest($Ticket, $qbxmlRequest)
             
      return $XMLResponse
  }
  catch {
      throw "An error occurred: $_"
  }
}
