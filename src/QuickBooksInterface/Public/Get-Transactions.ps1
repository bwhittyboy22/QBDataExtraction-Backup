function Get-Transactions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FromDate,
        [string]$ToDate = (Get-Date -Format "yyyy-MM-dd"),
        [Parameter(Mandatory=$true)]
        [string]$DivisionName,
        [Parameter(Mandatory=$true)]
        [string]$CompanyFilePath
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

    $StringToPrint = @"
From date: $FromDate, To date: $ToDate
"@
    Write-Host $StringToPrint

    # Initialize result object
    $result = @{
        divName = $DivisionName
        deltaCSVPath = $null
        success = $false
        error = $null
    }

    # Open connection to QuickBooks
    try {
        $qbxmlrp.OpenConnection2("","${DivisionName}QBAutomation", 1)
        Write-Output "Connection successful"
    } catch {
        $result.error = "Connection failed: $_"
        return $result
    }

    # Begin a session
    try {
        $ticket = $qbxmlrp.BeginSession($CompanyFilePath, 2)
        Write-Output "Session successful"
    } catch {
        $result.error = "Session failed: $_"
        return $result
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

    try {
        # Send the request
        Write-Output "Sending query..."
        $response = $qbxmlrp.ProcessRequest($ticket, $qbxmlRequest)
        Write-Output "Query received"
        
        # Save the response if successful
        $currentDateTime_FolderPath = Get-Date -Format "yyyyMMdd"
        $currentDateTime_FileName = Get-Date -Format "yyyyMMdd_HHmm"
        
        $documentsPath = [System.Environment]::GetFolderPath("MyDocuments")
        $subfolderPath = Join-Path -Path $documentsPath -ChildPath "QBFileExports\$currentDateTime_FolderPath"
        if (-not (Test-Path -Path $subfolderPath)) {
            New-Item -ItemType Directory -Path $subfolderPath | Out-Null
        }
        $filePath = Join-Path -Path $subfolderPath -ChildPath "Transactions_${DivisionName}_${currentDateTime_FileName}.xml"
        
        # Save the response to the file
        $response | Out-File -FilePath $filePath

        Write-Host "Response saved to $filePath"
        
        # Set success values in result
        $result.deltaCSVPath = $filePath
        $result.success = $true
    }
    catch {
        $result.error = "Query failed: $_"
    }
    finally {
        # End the session and close the connection, regardless of success or failure
        $qbxmlrp.EndSession($ticket)
        $qbxmlrp.CloseConnection()
    }

    return $result
}