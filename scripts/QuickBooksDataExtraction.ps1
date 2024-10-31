
param (
    [Parameter(Mandatory=$false)]
    [string[]]$Divisions,

    [Parameter(Mandatory=$false)]
    [string[]]$ReportType = "All",

    [switch]$DisableConversion,

    [switch]$DisableUpload,

    [switch]$TestMode
)

$currentDate = Get-Date -Format "yyyyMMdd"
$companyFilePaths = Get-Content "C:\Users\BenjaminW.admin\Developer\QBDataExtraction\CompanyFilePaths2.json" | ConvertFrom-Json
$reportPath = "C:\Users\BenjaminW.admin\Documents\QBExractions\$currentDate"
$reportTypes = @("Vendor", "Invoice", "SalesOrder", "PurchaseOrder", "Account", "JournalEntry")
$divisionsToProcess = 
    if ($Divisions -eq "All") {
        $companyFilePaths
    } elseif ([string]::IsNullOrEmpty($Divisions)) {
        Write-Host "No division provided."
        exit
    } else {
        $companyFilePaths | Where-Object Division -in $Divisions.Split(',')
    }
$reportsToProcess = 
    if($ReportType -eq "All") { $reportTypes }
    elseif ([string]::IsNullOrEmpty($ReportType)) { 
        Write-Host "No report specified."
        exit
    } else {
        $ReportType
    }
    
if(-not (Test-Path -Path $reportPath)) {
    New-Item -ItemType Directory -Path $reportPath | Out-Null
}

Import-Module "C:\Users\BenjaminW.admin\Developer\QBDataExtraction\src\QuickBooksInterface\QuickBooksInterface.psd1" -Force

Set-TestMode -Enabled $TestMode

foreach ($division in $divisionsToProcess) {

    $maxConnectionRetries = 3
    $maxSessionRetries = 3
    $connectionRetryCount = 0
    $sessionRetryCount = 0
    $connectionSucceeded = $false
    $sessionSucceeded = $false
    $waitTime = 30
    $qBComObject = $null
    $ticket = $null

    # This is the open connection block. The script will try 3 times to open a connection before moving on
    # to a different division. If successful then an OpenConnection2.RequestProcessor object is
    # returned.
    while ($connectionRetryCount -le $maxConnectionRetries) {

        try {
            $connectionRetryCount++
            Write-Host "Attempting to Open Connection for $($division.Division)..."
            $qBComObject = Start-OpenConnection2ForQuickBooks -DivisionName $division.Division
            Write-Host "OpenConnection2 successful for $($division.Division)"
            $connectionSucceeded = $true
            Start-Sleep -Seconds 5
            break
        }
        catch {
            $errorMessage = "An error occurred: $($_.Exception.Message)"
            Write-Host $errorMessage
            if ($connectionRetryCount -lt $maxConnectionRetries) {
                Write-Host "Waiting $waitTime seconds before retrying to connect..."
                Start-Sleep -Seconds $waitTime
            } else {
                Write-Host "Maximum retry attempts for connection reached for $($division.Division). Moving on to next division."
            }
        }
    }

    # If connection failed, skip to next division
    if (-not $connectionSucceeded) {
        continue
    }

    # This is the start Session block. The script will try 3 times to open a connection before moving on
    # to a different division.
    while ($sessionRetryCount -le $maxSessionRetries) {

        try {
            $sessionRetryCount++
            Write-Host "Attempting to start a session for $($division.Division)"
            $ticket = Start-SessionInQuickBooks -QBxmlrp $qBComObject -CompanyFilePath $division.CompanyFilePath
            Write-Host "Session started for $($division.Division)"
            $sessionSucceeded = $true
            Start-Sleep -Seconds 5
            break
        }
        catch {
            $errorMessage = "An error occurred: $($_.Exception.Message)"
            Write-Host $errorMessage
            if ($sessionRetryCount -lt $maxSessionRetries) {
                Write-Host "Waiting $waitTime seconds before retrying to start a session..."
                Start-Sleep -Seconds $waitTime
            } else {
                Write-Host "Maximum retry attempts to start a session reached for $($division.Division). Moving on to next division."
            }
        }
    }

    # If session failed, close connection and skip to next division
    if (-not $sessionSucceeded) {
        if ($qBComObject) {
            try {
                Stop-OpenConnection2ForQuickBooks -QBxmlrp $qBComObject
                Write-Host "$($division.Division) connection closed."
            }
            catch {
                Write-Host "Failed to close connection for $($division.Division)"
            }
        }
        continue
    }

    ### This is the query blcok. This block of code is for getting 
    # the response query from Quickbooks and saving it to a 
    # location as an xml file.
    foreach ($reportType in $reportsToProcess) {
        try {
            Write-Host "Attempting to get the $reportType report for $($division.Division)."
            $XMLResponse = Get-Report -ReportType $($reportType) -QBXMLRp $qBComObject -Ticket $ticket -PriorDay -IncludeLineItems
            $CurrentDateTimeForExportFileName = Get-Date -Format "yyyyMMdd_HHmm"
            $OutputPath = Join-Path -Path $reportPath -ChildPath "test_${CurrentDateTimeForExportFileName}_$($division.Division)_$reportType.xml"
            Save-QBXMLFile -QBXMLData $XMLResponse -SavePath $OutputPath
        }
        catch {
            throw "Error getting $reportType report: $_"
            continue
        }
    }
    ### End query block

    # Close the session
    if ($ticket) {
        try {
            Stop-SessionInQuickBooks -qbxmlrp $qBComObject -ticket $ticket
            Write-Host "$($division.Division) session closed."
        }
        catch {
            Write-Host "Failed to stop session for $($division.Division)"
        }
    }
    # Close the connection
    if ($qBComObject) {
        try {
            Stop-OpenConnection2ForQuickBooks -QBxmlrp $qBComObject
            Write-Host "$($division.Division) connection closed."
        }
        catch {
            Write-Host "Failed to close connection for $($division.Division)"
        }
        finally {
            # Waiting 45 seconds before moving on to the next division.
            # Through testing, we have found that waiting for QuickBooks
            # to catch-up and settle provides a more stable data pipeline.
            Start-Sleep -Seconds 45
        }
    } 
}
