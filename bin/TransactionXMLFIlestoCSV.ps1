##################################################################################################################
# Config Variables                                                                                               #
##################################################################################################################
$XMLFilesPath = "C:\Users\BenjaminW.admin\Documents\QBFileExports\20250307"

##################################################################################################################
# Module Imports                                                                                                 #
##################################################################################################################
Import-Module ".\src\QuickBooksInterface\QuickBooksInterface.psd1" -Force

##################################################################################################################
# Convert XML files to CSV                                                                                       #
##################################################################################################################
# Get all XML files in the specified directory
$xmlFiles = Get-ChildItem -Path $XMLFilesPath -Filter "*.xml"

# Process each XML file
foreach ($xmlFile in $xmlFiles) {
    # Create CSV filename in the same directory as the XML
    $csvFileName = [System.IO.Path]::GetFileNameWithoutExtension($xmlFile.FullName) + ".csv"
    $csvOutputPath = Join-Path -Path $xmlFile.Directory -ChildPath $csvFileName
    
    # Convert XML to CSV
    try {
        Convert-QBXMLtoCSV -ReportType "Transaction" -XMLFilePath $xmlFile.FullName -OutputPath $csvOutputPath
        Write-Output "Successfully converted: $($xmlFile.Name) to $csvFileName"
    }
    catch {
        Write-Error "Failed to convert: $($xmlFile.Name). Error: $_"
    }
}

Write-Output "XML to CSV conversion complete"