# Create instance of COM object
$qbxmlrp = New-Object -ComObject QBXMLRP2.RequestProcessor

# Path to QB file
$companyFile = "C:\QB Files\ECH\NEW Eastern Crane & Hoist, Inc.QBW"

try {
  # Open connection to QuickBooks
  $qbxmlrp.OpenConnection2("","ECHQBAutomation", 1)
  $connectionStatus = "Connection successful"
  Write-Output $connectionStatus
} catch {
  $connectionStatus = "Connections not successful"
  Write-Output $connectionStatus
}


# Begin a session
$ticket = $qbxmlrp.BeginSession($companyFile, 2)

# QBXML request
$qbxmlRequest = @"
<?qbxml version="13.0"?>
  <QBXML>
    <QBXMLMsgsRq onError="continueOnError">
      <JournalEntryQueryRq requestID="2">
        <TxnDateRangeFilter>
          <FromTxnDate>2024-08-01</FromTxnDate>
          <ToTxnDate>2024-08-31</ToTxnDate>
        </TxnDateRangeFilter>
        <IncludeLineItems>true</IncludeLineItems>
      </JournalEntryQueryRq>
    </QBXMLMsgsRq>
  </QBXML>
"@

# Try to send the request and catch any errors
try {
    # Send the request
    $response = $qbxmlrp.ProcessRequest($ticket, $qbxmlRequest)
    
    # Save the response if successful
    # Get the current date and time
    $currentDateTime_FolderPath = Get-Date -Format "yyyyMMdd"
    $currentDateTime_FileName = Get-Date -Format "yyyyMMddHHmmss"
    
    # Path to Documents folder
    $documentsPath = [System.Environment]::GetFolderPath("MyDocuments")
    
    # Create the subfolder with the current date and time
    $subfolderPath = Join-Path -Path $documentsPath -ChildPath "QBFileExports\$currentDateTime_FolderPath"
    if (-not (Test-Path -Path $subfolderPath)) {
        New-Item -ItemType Directory -Path $subfolderPath | Out-Null
    }
    
    # Create the file path with the date prefix
    $filePath = Join-Path -Path $subfolderPath -ChildPath "${currentDateTime_FileName}_ECH_JournalEntryWithLineItems.xml"
    
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
