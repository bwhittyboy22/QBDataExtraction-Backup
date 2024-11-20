param(
    [Parameter(Mandatory=$true)]
    [string]$StartYear,
    
    [Parameter(Mandatory=$true)]
    [string]$StartMonth,
    
    [Parameter(Mandatory=$true)]
    [string]$EndYear,
    
    [Parameter(Mandatory=$true)]
    [string]$EndMonth
)

# Create instance of COM object
$qbxmlrp = New-Object -ComObject QBXMLRP2.RequestProcessor
$companyFile = "C:\QB Files\FP\FP Fabrication LLC.QBW"

try {
    $qbxmlrp.OpenConnection2("","FPQBAutomation", 1)
    Write-Output "Connection successful"
    $ticket = $qbxmlrp.BeginSession($companyFile, 2)
    
    $startDate = [DateTime]::ParseExact("$StartYear$StartMonth", "yyyyMM", $null)
    $endDate = [DateTime]::ParseExact("$EndYear$EndMonth", "yyyyMM", $null)
    $currentDate = $startDate

    while ($currentDate -le $endDate) {
        $YearNumber = $currentDate.ToString("yyyy")
        $MonthNumber = $currentDate.ToString("MM")
        $FromReportDate = "$YearNumber-$MonthNumber-01"
        $LastDayOfMonth = [datetime]::DaysInMonth($currentDate.Year, $currentDate.Month)
        $ToReportDate = "$YearNumber-$MonthNumber-$LastDayOfMonth"
        
        Write-Host "Processing: $YearNumber-$MonthNumber"

        $qbxmlRequest = @"
<?qbxml version="13.0"?>
<QBXML>
  <QBXMLMsgsRq onError="stopOnError">
    <GeneralSummaryReportQueryRq>
      <GeneralSummaryReportType>TrialBalance</GeneralSummaryReportType>
        <ReportPeriod>
          <FromReportDate>$FromReportDate</FromReportDate>
          <ToReportDate>$ToReportDate</ToReportDate>
        </ReportPeriod>
      </GeneralSummaryReportQueryRq>
  </QBXMLMsgsRq>
</QBXML>
"@

        try {
            $response = $qbxmlrp.ProcessRequest($ticket, $qbxmlRequest)
            
            $currentDateTime_FolderPath = Get-Date -Format "yyyyMMdd"
            $documentsPath = [System.Environment]::GetFolderPath("MyDocuments")
            $subfolderPath = Join-Path -Path $documentsPath -ChildPath "QBFileExports\$currentDateTime_FolderPath"
            
            if (-not (Test-Path -Path $subfolderPath)) {
                New-Item -ItemType Directory -Path $subfolderPath | Out-Null
            }
            
            $filePath = Join-Path -Path $subfolderPath -ChildPath "TrialBalance_FP_$($YearNumber)M$($MonthNumber).xml"
            $response | Out-File -FilePath $filePath
            Write-Host "Saved: $filePath"
        }
        catch {
            Write-Host "Error processing $YearNumber-$($MonthNumber): $($_.Exception.Message)"
        }
        Start-Sleep -Seconds 5
        $currentDate = $currentDate.AddMonths(1)
    }
}
catch {
    Write-Host "Connection error: $($_.Exception.Message)"
}
finally {
    if ($ticket) {
        $qbxmlrp.EndSession($ticket)
        $qbxmlrp.CloseConnection()
    }
}