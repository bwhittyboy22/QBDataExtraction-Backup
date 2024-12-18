Import-Module ".\src\PostgreSQLUtils\PostgreSQLUtils.psd1" -Force
Import-Module ".\src\QuickBooksInterface\QuickBooksInterface.psd1" -Force

$CompanyFilePath = Get-Content "C:\Users\BenjaminW.admin\Developer\QBDataExtraction\CompanyFIlePaths.json" -Raw | ConvertFrom-Json
$Divisions = New-Object System.Collections.ArrayList
$Divisions.Clear()

# Loop through each property name and add it to $Divisions individually
foreach ($divisionName in $CompanyFilePath.PSObject.Properties.Name) {
    $Divisions.Add($divisionName) | Out-Null
}
