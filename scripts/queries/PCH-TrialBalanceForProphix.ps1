# Script to generate monthly trial balance reports from January 2020 to previous month
# This uses the script called GeneralSummaryReportTypeQuery.ps1

# Get the directory where this script is located
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# Get current date information
$currentDate = Get-Date
$currentYear = $currentDate.Year
$currentMonth = $currentDate.Month
$previousMonth = $currentDate.AddMonths(-1)

# Function to get the last day of a month
function Get-LastDayOfMonth([DateTime]$date) {
    return [DateTime]::DaysInMonth($date.Year, $date.Month)
}

# Create the base output path
$baseOutputPath = Join-Path -Path ([System.Environment]::GetFolderPath("MyDocuments")) -ChildPath "QBFileExports\$(Get-Date -Format 'yyyyMMdd')"

# Ensure the directory exists
if (-not (Test-Path -Path $baseOutputPath)) {
    New-Item -ItemType Directory -Path $baseOutputPath | Out-Null
}

# Generate date range from January 2020 to previous month
$startDate = Get-Date -Year 2020 -Month 1 -Day 1
$endDate = $previousMonth

$currentDate = $startDate
while ($currentDate -le $endDate) {
    $year = $currentDate.Year
    $month = $currentDate.Month
    $lastDay = Get-LastDayOfMonth -date $currentDate
    
    # Format month number with leading zero
    $monthPadded = $month.ToString("00")
    
    # Create the date range for this month
    $fromDate = Get-Date -Year $year -Month $month -Day 1
    $toDate = Get-Date -Year $year -Month $month -Day $lastDay
    
    # Create filename with new naming convention
    $fileName = "TrialBalance_PCH_${year}M${monthPadded}.xml"
    
    Write-Host "Generating report for $($currentDate.ToString('MMMM')) $year..."
    
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
    
    # Move to next month
    $currentDate = $currentDate.AddMonths(1)
}

Write-Host "All monthly reports have been generated."