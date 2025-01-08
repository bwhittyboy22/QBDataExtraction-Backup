param(
    [Parameter(Mandatory=$true)]
    [string]$FromDate,
    [string]$ToDate = (Get-Date -Format "yyyy-MM-dd")
)


# Validate and convert FromDate
try {
  $FromDateTime = [DateTime]::ParseExact($FromDate, "yyyy-MM-dd", $null)
  $FromDate = $FromDateTime.ToString("yyyy-MM-ddT00:00:00")
} catch {
  throw "FromDate must be in the format 'YYYY-MM-DD'"
}

# Handle ToDate - if provided, validate it. If not, use current date and time
try {
  $currentDate = Get-Date
  if ($ToDate) {
      $ToDateTime = [DateTime]::ParseExact($ToDate, "yyyy-MM-dd", $null)
      # If ToDate is today, use current time
      if ($ToDateTime.Date -eq $currentDate.Date) {
          $ToDateTime = $currentDate
      }
      # If ToDate is before today, use end of day (23:59:59)
      elseif ($ToDateTime.Date -lt $currentDate.Date) {
          $ToDateTime = $ToDateTime.Date.AddHours(23).AddMinutes(59).AddSeconds(59)
      }
  } else {
      # No ToDate provided, use current date and time
      $ToDateTime = $currentDate
  }
  $ToDate = $ToDateTime.ToString("yyyy-MM-ddTHH:mm:ss")
} catch {
  throw "ToDate must be in the format 'YYYY-MM-DD'"
}

# Create instance of COM object
$qbxmlrp = New-Object -ComObject QBXMLRP2.RequestProcessor

# Path to QB company file
$companyFile = "C:\QB Files\SSI\QB SSI Enterprise 2020.QBW"

$StringToPrint = @"
From date: $FromDate, To date: $ToDate
"@
Write-Host $StringToPrint

# Open connection to QuickBooks
try {
  $qbxmlrp.OpenConnection2("","SSIQBAutomation", 1)
  $connectionStatus = "Connection successful"
  Write-Output $connectionStatus
} catch {
  $connectionStatus = "Connections not successful"
  Write-Output $connectionStatus
}

# Begin a session
try {
  $ticket = $qbxmlrp.BeginSession($companyFile, 2)
  $sessionStatus = "Session sucessful"
  Write-Output $sessionStatus
} catch {
  $sessionStatus = "Session not established"
  Write-Output $sessionStatus
}

# QBXML request
$qbxmlRequest = @"
<?qbxml version="13.0"?>
  <QBXML>
    <QBXMLMsgsRq onError="continueOnError">
        <TransactionQueryRq requestID="2">
                <TransactionModifiedDateRangeFilter>
                    <FromModifiedDate>$FromDate</FromModifiedDate>
                    <ToModifiedDate>$ToDate</ToModifiedDate>
                </TransactionModifiedDateRangeFilter>
        </TransactionQueryRq>
    </QBXMLMsgsRq>
  </QBXML>
"@

# Try to send the request and catch any errors
try {
    # Send the request
    Write-Output "Sending query..."
    $response = $qbxmlrp.ProcessRequest($ticket, $qbxmlRequest)
    Write-Output "Query received"
    
    # Save the response if successful
    # Get the current date and time
    $currentDateTime_FolderPath = Get-Date -Format "yyyyMMdd"
    $currentDateTime_FileName = Get-Date -Format "yyyyMMdd_HHmm"
    
    $documentsPath = [System.Environment]::GetFolderPath("MyDocuments")
    $subfolderPath = Join-Path -Path $documentsPath -ChildPath "QBFileExports\$currentDateTime_FolderPath"
    if (-not (Test-Path -Path $subfolderPath)) {
        New-Item -ItemType Directory -Path $subfolderPath | Out-Null
    }
    $filePath = Join-Path -Path $subfolderPath -ChildPath "Transactions_SSI_${currentDateTime_FileName}.xml"
    
    # Save the response to the file
    $response | Out-File -FilePath $filePath

    Write-Host "Response saved to $filePath"
}
catch {
    Write-Host "An error occurred during the QuickBooks request: $($_.Exception.Message)"
}
finally {
    # End the session and close the connection, regardless of success or failure
    $qbxmlrp.EndSession($ticket)
    $qbxmlrp.CloseConnection()
}
