# Script to generate monthly trial balance reports for January through October
# This uses the script called GeneralSummaryReportTypeQuery.ps1

# Get the directory where this script is located
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# Array of month information
$months = @(
    @{ Name = "January";   StartDay = "01"; EndDay = "31"; MonthNumber = '01' },
    @{ Name = "February";  StartDay = "01"; EndDay = "28"; MonthNumber = '02' },
    @{ Name = "March";     StartDay = "01"; EndDay = "31"; MonthNumber = '03' },
    @{ Name = "April";     StartDay = "01"; EndDay = "30"; MonthNumber = '04' },
    @{ Name = "May";       StartDay = "01"; EndDay = "31"; MonthNumber = '05' },
    @{ Name = "June";      StartDay = "01"; EndDay = "30"; MonthNumber = '06' },
    @{ Name = "July";      StartDay = "01"; EndDay = "31"; MonthNumber = '07' },
    @{ Name = "August";    StartDay = "01"; EndDay = "31"; MonthNumber = '08' },
    @{ Name = "September"; StartDay = "01"; EndDay = "30"; MonthNumber = '09' },
    @{ Name = "October";   StartDay = "01"; EndDay = "31"; MonthNumber = '10' }
)

# Get the current year
$year = Get-Date -Format "yyyy"

# Create the base output path
$baseOutputPath = Join-Path -Path ([System.Environment]::GetFolderPath("MyDocuments")) -ChildPath "QBFileExports\$(Get-Date -Format 'yyyyMMdd')"

# Ensure the directory exists
if (-not (Test-Path -Path $baseOutputPath)) {
    New-Item -ItemType Directory -Path $baseOutputPath | Out-Null
}

# Generate reports for each month
foreach ($month in $months) {
    $monthNumber = [array]::IndexOf($months, $month) + 1
    $fromDate = Get-Date -Year $year -Month $monthNumber -Day ([int]$month.StartDay)
    $toDate = Get-Date -Year $year -Month $monthNumber -Day ([int]$month.EndDay)
    
    # Create filename with timestamp and month
    # $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $fileName = "PCH_TrialBalance_$($month.MonthNumber)_$($month.Name).xml"
    
    Write-Host "Generating report for $($month.Name) $year..."
    
    # Parameters for the report script
    $params = @{
        ReportType = "TrialBalance"
        FromReportDate = $fromDate
        ToReportDate = $toDate
        OutputFileName = $fileName
        OutputPath = $baseOutputPath
        CompanyFilePath = "C:\QB Files\PCH\pchver2017.QBW"
        Division = "PCH"
    }
    
    # Build the full path to the report script
    $reportScriptPath = Join-Path -Path $scriptDirectory -ChildPath "GeneralSummaryReportyTypeQuery.ps1"
    
    # Execute the report script with parameters
    & $reportScriptPath @params
    
    # Add a small delay to ensure unique timestamps
    Start-Sleep -Seconds 10
}

Write-Host "All monthly reports have been generated."