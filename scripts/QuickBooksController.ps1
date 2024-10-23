
param (
    [Parameter(Mandatory=$false)]
    [string]$DivisionName = "All"
)

$companyFilePaths = Get-Content "C:\Users\BenjaminW.admin\Developer\QBDataExtraction\CompanyFilePaths.json" | ConvertFrom-Json
$divisions = @("ECH", "PCH", "SSI", "FP")
$divisionsToProcess = if ($DivisionName -eq "All") { $divisions } else { @($DivisionName) }

foreach ($division in $divisionsToProcess) {
    Write-Host $companyFilePaths.$division
}