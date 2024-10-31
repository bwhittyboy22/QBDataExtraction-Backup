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

  # Define report types for date filters
  $reportsWithModifiedDateRangeFilter = @('Invoice', 'SalesOrder', 'PurchaseOrder', 'JournalEntry')
  $reportsWithDirectDateFilter = @('Vendor', 'Account')

  # Determine the date filter
  $dateFilter = ""
  if ($PriorDay) {
      # Use specific times for the prior day date range
      $fromDateTime = (Get-Date).AddDays(-1).Date.AddHours(0).AddMinutes(0).AddSeconds(0)
      $toDateTime = (Get-Date).AddDays(-1).Date.AddHours(23).AddMinutes(59).AddSeconds(59)

      # Format dates with 'T' and time zone offset
      $fromDate = $fromDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
      $toDate = $toDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")

      Write-Host "Using date range: $fromDate to $toDate"

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
  elseif ($YTD) {
      # Use Year-to-Date filter with specific times
      $startOfYearDateTime = (Get-Date -Year (Get-Date).Year -Month 1 -Day 1).Date.AddHours(0).AddMinutes(0).AddSeconds(0)
      $todayDateTime = (Get-Date).Date.AddHours(23).AddMinutes(59).AddSeconds(59)

      # Format dates with 'T' and time zone offset
      $fromDate = $startOfYearDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
      $toDate = $todayDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")

      Write-Host "Using date range: $fromDate to $toDate"

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
  elseif ($FromDateRange) {
      # Use custom date range filter with times
      # Convert FromDateRange to DateTime
      $fromDateTime = [DateTime]::Parse($FromDateRange).Date.AddHours(0).AddMinutes(0).AddSeconds(0)

      if (-not $ToDateRange) {
          $toDateTime = (Get-Date).Date.AddHours(23).AddMinutes(59).AddSeconds(59) # Default to end of current day if ToDateRange is not provided
      } else {
          # Convert ToDateRange to DateTime
          $toDateTime = [DateTime]::Parse($ToDateRange).Date.AddHours(23).AddMinutes(59).AddSeconds(59)
      }

      # Format dates with 'T' and time zone offset
      $fromDate = $fromDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
      $toDate = $toDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")

      Write-Host "Using date range: $fromDate to $toDate"

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

  try {
      $maxReturnedElement = $script:IsTestMode ? "<MaxReturned>10</MaxReturned>" : ""

      # Build the query elements
      $queryElements = @()

      if ($dateFilter) {
          $queryElements += $dateFilter
      }

      if ($includeLineItemsElement) {
          $queryElements += $includeLineItemsElement
      }

      # Optionally include IncludeRetElement
      # Be cautious, including it as '*' may cause errors
      # $queryElements += "<IncludeRetElement>*</IncludeRetElement>"

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

      Write-Verbose "Sending query request to QuickBooks"
      # Optionally print the request for debugging
      # Write-Host "DEBUG: Generated QBXML Request for $ReportType :" -ForegroundColor Yellow
      # Write-Host $qbxmlRequest -ForegroundColor Cyan

      $XMLResponse = $QBXMLRp.ProcessRequest($Ticket, $qbxmlRequest)

      return $XMLResponse
  }
  catch {
      throw "An error occurred: $_"
  }
}
