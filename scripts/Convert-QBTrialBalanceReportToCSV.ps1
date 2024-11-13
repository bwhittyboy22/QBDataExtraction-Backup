# Parameters for input/output paths
param(
    [Parameter(Mandatory=$true)]
    [string]$InputXMLPath,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputCSVPath = (Join-Path (Split-Path $InputXMLPath) "TrialBalance_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"),

    [Parameter(Mandatory=$false)]
    [string]$Separator = " - "  # You can change this to whatever separator you prefer
)

function Convert-QBXMLToCSV {
    param(
        [string]$XMLPath,
        [string]$CSVPath,
        [string]$Separator
    )
    
    try {
        # Load XML file with encoding specification
        Write-Host "Loading XML file from: $XMLPath"
        $xmlContent = New-Object System.Xml.XmlDocument
        $xmlContent.PreserveWhitespace = $true
        $xmlContent.Load($XMLPath)
        
        # Get report details
        $reportTitle = $xmlContent.SelectSingleNode("//ReportTitle").InnerText
        $reportDate = $xmlContent.SelectSingleNode("//ReportSubtitle").InnerText
        
        Write-Host "Processing $reportTitle $reportDate"
        
        # Initialize array to hold rows
        $rows = @()
        
        # Process each data row
        $dataRows = $xmlContent.SelectNodes("//DataRow")
        
        foreach ($row in $dataRows) {
            # Get the account name and clean it up
            $accountName = $row.SelectSingleNode(".//ColData[@colID='1']").Value
            
            # Clean up the account name:
            # 1. Replace UTF-8 middle dot and surrounding whitespace
            $accountName = $accountName -replace '\s*Â·\s*', $Separator
            # 2. Replace HTML entity if still present
            $accountName = $accountName -replace '\s*&#183;\s*', $Separator
            # 3. Replace any other middle dot character
            $accountName = $accountName -replace '\s*·\s*', $Separator
            # 4. Clean up any resulting multiple spaces
            $accountName = $accountName -replace '\s+', ' '
            $accountName = $accountName.Trim()
            
            $debitAmount = $row.SelectSingleNode(".//ColData[@colID='2']")?.Value ?? "0.00"
            $creditAmount = $row.SelectSingleNode(".//ColData[@colID='3']")?.Value ?? "0.00"
            
            # Create custom object for each row
            $rowObject = [PSCustomObject]@{
                'Account' = $accountName
                'Debit' = [decimal]::Parse($debitAmount)
                'Credit' = [decimal]::Parse($creditAmount)
                'Net' = [decimal]::Parse($debitAmount) - [decimal]::Parse($creditAmount)
            }
            
            $rows += $rowObject
        }
        
        # Get totals row
        $totalRow = $xmlContent.SelectSingleNode("//TotalRow")
        $totalDebit = $totalRow.SelectSingleNode(".//ColData[@colID='2']").Value
        $totalCredit = $totalRow.SelectSingleNode(".//ColData[@colID='3']").Value
        
        # Add total row
        $rows += [PSCustomObject]@{
            'Account' = 'TOTAL'
            'Debit' = [decimal]::Parse($totalDebit)
            'Credit' = [decimal]::Parse($totalCredit)
            'Net' = [decimal]::Parse($totalDebit) - [decimal]::Parse($totalCredit)
        }
        
        # Export to CSV with UTF-8 encoding (without BOM)
        Write-Host "Exporting to CSV: $CSVPath"
        $rows | Export-Csv -Path $CSVPath -NoTypeInformation -Encoding UTF8NoBOM
        
        # Print summary
        Write-Host "`nConversion completed successfully!"
        Write-Host "Total rows processed: $($rows.Count)"
        Write-Host "Total Debits: $($totalDebit)"
        Write-Host "Total Credits: $($totalCredit)"
        Write-Host "Output saved to: $CSVPath"
    }
    catch {
        Write-Error "Error processing XML file: $_"
        exit 1
    }
}

# Execute the conversion
Convert-QBXMLToCSV -XMLPath $InputXMLPath -CSVPath $OutputCSVPath -Separator $Separator