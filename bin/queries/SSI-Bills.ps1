#Create instance of COM object
$qbxmlrp = New-Object -ComObject QBXMLRP2.RequestProcessor

#Path to QB file
$companyFile = "C:\QB Files\SSI\QB SSI Enterprise 2020.QBW"

#Open connection to QuickBooks
$qbxmlrp.OpenConnection2("","SSIQBAutomation", 1)

# Begin a session
$ticket = $qbxmlrp.BeginSession($companyFile, 2)

#QBXML request
$qbxmlRequest = @"
<?qbxml version="2.0"?>
<QBXML>
  <QBXMLMsgsRq onError="continueOnError">
    <BillQueryRq requestID="2" />
  </QBXMLMsgsRq>
</QBXML>
"@

# Send the request
$response = $qbxmlrp.ProcessRequest($ticket, $qbxmlRequest)

# End the session
$qbxmlrp.EndSession($ticket)

# Close the connection
$qbxmlrp.CloseConnection()

$documentsPath = [System.Environment]::GetFolderPath("MyDocuments")

$filePath = Join-Path -Path $documentsPath -ChildPath "SSI_Bills.xml"

$response | Out-File -FilePath $filePath

Write-Host "Response saved to $filePath"