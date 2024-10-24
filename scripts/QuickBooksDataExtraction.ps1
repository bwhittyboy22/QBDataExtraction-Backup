
param (
    [Parameter(Mandatory=$false)]
    [string[]]$Divisions,

    [Parameter(Mandatory=$false)]
    [string]$ReportType = "All",

    [switch]$DisableConversion,

    [switch]$DisableUpload,

    [switch]$TestMode
)

$currentDate = Get-Date -Format "yyyyMMdd"
$companyFilePaths = Get-Content "C:\Users\BenjaminW.admin\Developer\QBDataExtraction\CompanyFilePaths2.json" | ConvertFrom-Json
$reportPath = "C:\Users\BenjaminW.admin\Documents\QBExractions\$currentDate"
$divisionsToProcess = 
    if ($Divisions -eq "All") {
        $companyFilePaths
    } elseif ([string]::IsNullOrEmpty($Divisions)) {
        Write-Host "No division provided."
        exit
    } else {
        $companyFilePaths | Where-Object Division -in $Divisions.Split(',')
    }

if(-not (Test-Path -Path $reportPath)) {
    New-Item -ItemType Directory -Path $reportPath | Out-Null
}

Import-Module "C:\Users\BenjaminW.admin\Developer\QBDataExtraction\src\QuickBooksInterface\QuickBooksInterface.psd1" -Force

foreach ($division in $divisionsToProcess) {

    $maxConnectionRetries = 3
    $maxSessionRetries = 3
    $connectionRetryCount = 0
    $sessionRetryCount = 0
    $waitTime = 30

    # This is the connection block. The script will try 3 times to open a connection before moving on
    # to a different division. If successful then an OpenConnection2.RequestProcessor object is
    # returned.
    while ($connectionRetryCount -le $maxConnectionRetries) {
        $qBComObject = $null

        try {
            $connectionRetryCount++
            Write-Host "Attempting to Open Connection for $($division.Division)..."
            $qBComObject = Start-OpenConnection2ForQuickBooks -DivisionName $division.Division
            Write-Host "OpenConnection2 successful for $($division.Division)"
            break
        }
        catch {
            $errorMessage = "An error occurred: $($_.Exception.Message)"
            Write-Host $errorMessage
            if ($connectionRetryCount -lt $maxConnectionRetries) {
                Write-Host "Waiting $waitTime before retrying to connect..."
                Start-Sleep -Seconds $waitTime
            } else {
                Write-Host "Maximum retry attempts for connection reached for $($divsion.Division). Moving on to next division."
            }
        }
    } 

    # This is the Session block. The script will try 3 times to open a connection before moving on
    # to a different division.
    while($sessionRetryCount -lt $maxSessionRetries) {
        $ticket = $null

        try {
            $sessionRetryCount++
            Write-Host "Attempting to start a session for $($division.Division)"
            $ticket = Start-SessionInQuickBooks -QBxmlrp $qBComObject -CompanyFilePath $($division.CompanyFilePath)
            Write-Host "Session started for $($division.Division)"
            break
        }
        catch {
            $errorMessage = "An error occurred: $($_.Exception.Message)"
            Write-Host $errorMessage
            if ($sessionRetryCount -lt $maxSessionRetries) {
                Write-Host "Waiting $waitTime before retrying to to start a session..."
                Start-Sleep -Seconds $waitTime
            } else {
                Write-Host "Maximum retry attempts to start a session reached for $($divsion.Division). Moving on to next division."
            }
        }
    }

    Write-Host "Doing something for 15 seconds ..."
    Start-Sleep -Seconds 15

    if ($ticket) {
        try {
            Stop-SessionInQuickBooks -qbxmlrp $qBComObject -ticket $ticket
            Write-Host "$($division.Division) session closed."
        }
        catch {
            Write-Host "Failed to stop session for $($division.Division)"
        }
    }
    if ($qBComObject) {
        try {
            Stop-OpenConnection2ForQuickBooks -QBxmlrp $qBComObject
            Write-Host "$($division.Division) connection closed."
        }
        catch {
            Write-Host "Failed to close connection for $($division.Division)"
        } finally {
            # Waiting 45 seconds before moving on to the next division.
            # Through testing, we have found that waiting for QuickBooks
            # to catch-up and settle provides a more stable data pipeline.
            Start-Sleep -Seconds 45
        }
    } 
}
