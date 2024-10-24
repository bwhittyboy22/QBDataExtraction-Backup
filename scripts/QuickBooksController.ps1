
param (
    [Parameter(Mandatory=$false)]
    [string]$DivisionName = "All"
)

$companyFilePaths = Get-Content "C:\Users\BenjaminW.admin\Developer\QBDataExtraction\CompanyFilePaths.json" | ConvertFrom-Json
$divisions = @("ECH", "PCH", "SSI", "FP")
$divisionsToProcess = if ($DivisionName -eq "All") { $divisions } else { @($DivisionName) }

Import-Module "C:\Users\BenjaminW.admin\Developer\QBDataExtraction\src\QuickBooksInterface\QuickBooksInterface.psd1" -Force

try {
    $qBComObject = Start-OpenConnection2ForQuickBooks -DivisionName $DivisionName
    Write-Host "OpenConnection2 successful for ${DivisionName}"
    Start-Sleep -Seconds 10
}
catch {
    $errorMessage = "An error occurred: $($_.Exception.Message)" # | Add-Content -Path $logFile
    Write-Host $errorMessage
}

try {
    Stop-OpenConnection2ForQuickBooks -QBxmlrp $qBComObject
    Write-Host "Connection closed for ${DivisionName}"
}
catch {
    Write-Host "$_"
}