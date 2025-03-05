#Create instance of COM object
$qbxmlrp = New-Object -ComObject QBXMLRP2.RequestProcessor

#Path to QB file
$companyFile = "C:\QB Files\FP\FP Fabrication LLC.QBW"

try {
    # Open connection to QuickBooks
    $qbxmlrp.OpenConnection2("","FPQBAutomation", 1)
    Write-Host "OpenConnection2 successful"
} catch {
    Write-Host "OpenConnection2 failed"
}

try {
    # Begin a session
    $ticket = $qbxmlrp.BeginSession($companyFile, 2)
    Write-Host "Began session successful"
} catch {
    Write-Host "Failed to begin session"
}

#QBXML request
$qbxmlRequest = @"
<?qbxml version="2.0"?>
<QBXML>
  <QBXMLMsgsRq onError="continueOnError">
    <VendorQueryRq requestID="2" />
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

$filePath = Join-Path -Path $documentsPath -ChildPath "FP_Vendor.xml"

$response | Out-File -FilePath $filePath

Write-Host "Response saved to $filePath"