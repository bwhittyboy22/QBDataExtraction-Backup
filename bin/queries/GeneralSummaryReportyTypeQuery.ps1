[CmdletBinding(DefaultParameterSetName='DateMacro')]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReportType,
    
    [Parameter(Mandatory=$true, ParameterSetName='DateRange')]
    [DateTime]$FromReportDate,
    
    [Parameter(Mandatory=$true, ParameterSetName='DateRange')]
    [DateTime]$ToReportDate,
    
    [Parameter(Mandatory=$true, ParameterSetName='DateMacro')]
    [ValidateSet(
        'All', 'Today', 'ThisWeek', 'ThisWeekToDate', 'ThisMonth', 
        'ThisMonthToDate', 'ThisQuarter', 'ThisQuarterToDate', 
        'ThisYear', 'ThisYearToDate', 'Yesterday', 'LastWeek', 
        'LastWeekToDate', 'LastMonth', 'LastMonthToDate', 'LastQuarter', 
        'LastQuarterToDate', 'LastYear', 'LastYearToDate', 'NextWeek', 
        'NextFourWeeks', 'NextMonth', 'NextQuarter', 'NextYear'
    )]
    [string]$DateMacro,

    [Parameter()]
    [string]$CompanyFilePath,

    [Parameter()]
    [string]$OutputFileName,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [string]$Division
)

# Create instance of COM object
$qbxmlrp = New-Object -ComObject QBXMLRP2.RequestProcessor

try {
    # Open connection to QuickBooks
    $qbxmlrp.OpenConnection2("", "$($Division)QBAutomation", 1)
    Write-Output "Connection successful"

    # Begin a session
    $ticket = $qbxmlrp.BeginSession($CompanyFilePath, 2)

    # Build the XML request based on parameters
    $dateSection = if ($PSCmdlet.ParameterSetName -eq 'DateRange') {
        @"
        <ReportPeriod>
            <FromReportDate>$($FromReportDate.ToString('yyyy-MM-dd'))</FromReportDate>
            <ToReportDate>$($ToReportDate.ToString('yyyy-MM-dd'))</ToReportDate>
        </ReportPeriod>
"@
    } else {
        "<ReportDateMacro>$DateMacro</ReportDateMacro>"
    }

    # QBXML request
    $qbxmlRequest = @"
<?qbxml version="13.0"?>
<QBXML>
    <QBXMLMsgsRq onError="stopOnError">
        <GeneralSummaryReportQueryRq>
            <GeneralSummaryReportType>$ReportType</GeneralSummaryReportType>
            $dateSection
        </GeneralSummaryReportQueryRq>
    </QBXMLMsgsRq>
</QBXML>
"@

    # Try to send the request and catch any errors
    try {
        # Send the request
        $response = $qbxmlrp.ProcessRequest($ticket, $qbxmlRequest)
        
        # Handle file paths and names
        if (-not $OutputPath) {
            $currentDateTime_FolderPath = Get-Date -Format "yyyyMMdd"
            $documentsPath = [System.Environment]::GetFolderPath("MyDocuments")
            $OutputPath = Join-Path -Path $documentsPath -ChildPath "QBFileExports\$currentDateTime_FolderPath"
        }
        
        # Create directory if it doesn't exist
        if (-not (Test-Path -Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath | Out-Null
        }
        
        # Handle file name
        if (-not $OutputFileName) {
            $currentDateTime_FileName = Get-Date -Format "yyyyMMddHHmmss"
            $OutputFileName = "${currentDateTime_FileName}_ECH_$ReportType.xml"
        }
        
        # Save the response
        $filePath = Join-Path -Path $OutputPath -ChildPath $OutputFileName
        $response | Out-File -FilePath $filePath
        Write-Host "Response saved to $filePath"
    }
    catch {
        Write-Host "An error occurred during the QuickBooks request: $($_.Exception.Message)"
    }
}
catch {
    Write-Host "Connection not successful: $($_.Exception.Message)"
}
finally {
    # End the session and close the connection if they were established
    if ($ticket) {
        $qbxmlrp.EndSession($ticket)
    }
    if ($qbxmlrp) {
        $qbxmlrp.CloseConnection()
    }
}