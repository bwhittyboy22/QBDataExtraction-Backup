# Create instance of COM object
$qbxmlrp = New-Object -ComObject QBXMLRP2.RequestProcessor

# Path to QB file
$companyFile = "C:\QB Files\ECH\NEW Eastern Crane & Hoist, Inc.QBW"

# Open connection to QuickBooks
$qbxmlrp.OpenConnection2("","ECHQuickBooksAutomationScript", 1)

# Begin a session
$ticket = $qbxmlrp.BeginSession($companyFile, 2)

# QBXML request
$qbxmlRequest = @"
<?qbxml version="2.0"?>
<QBXML>
  <QBXMLMsgsRq onError="continueOnError">
    <InvoiceQueryRq requestID="2">
      <IncludeLineItems>true</IncludeLineItems>
    </InvoiceQueryRq>
  </QBXMLMsgsRq>
</QBXML>
"@


# Send the request
$response = $qbxmlrp.ProcessRequest($ticket, $qbxmlRequest)

# End the session
$qbxmlrp.EndSession($ticket)

# Close the connection
$qbxmlrp.CloseConnection()

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
$filePath = Join-Path -Path $subfolderPath -ChildPath "${currentDateTime_FileName}_ECH_Invoice.xml"

# Save the response to the file
$response | Out-File -FilePath $filePath

Write-Host "Response saved to $filePath"