## Save-QBXMLFile.ps1


<#
.SYNOPSIS
Saves a QuickBooks XML response to a file.

.DESCRIPTION
This function saves a QuickBooks XML response to a file with a name format of "DateTime_Division_ReportType.xml".

.PARAMETER response
The XML response string to save.

.PARAMETER division
The division name to include in the filename.

.PARAMETER reportType
The report type to include in the filename.

.PARAMETER outputPath
The directory path where the file should be saved.

.EXAMPLE
$filePath = Save-QBXMLFile -response $xmlResponse -division "ECH" -reportType "Invoice" -outputPath "C:\QuickBooks\Exports"
#>
function Save-QBXMLFile {
    param (
        [string]$QBXMLData,
        [string]$SavePath
    )

    $QBXMLData | Out-File -FilePath $SavePath

    if (-not (Test-Path -Path $SavePath)) {
        throw "Failed to create the file at $filePath"
    }

    Write-Host "Response saved to $SavePath"
    return $SavePath
}

Export-ModuleMember -Function Save-QBXMLFile