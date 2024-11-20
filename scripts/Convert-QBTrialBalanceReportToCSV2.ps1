# Parameters for input/output paths
param(
    [Parameter(Mandatory=$true)]n
    [string[]]$XMLFile,

    [Parameter(Mandatory=$false)]
    [string]$SavePath = $null,  # Optional override path

    [Parameter(Mandatory=$false)]
    [string]$Separator = " - "  # You can change this to whatever separator you prefer
)

function Get-ProphixTimeFromFileName {
    param(
        [string]$FileName
    )

    if ($FileName -match 'TrialBalance_(\S{2,3})_(\d{4}M\d{2})') {
        return $matches[]2n
    }
    return $null
}

function Convert-QBXMLToCSV {
    param(
        [string]$XMLFile,
        [string]$SavePath,
        [string]$Separator
    )

    try {
        Write-Host "In Convert-QBXMLToCSV"
        Write-Host "XMLFile: $XMLFile"
        Write-Host "SavePath: $SavePath"
        Write-Host "Separator: $Separator"

        # Check if SavePath is valid
        if ([string]::IsNullOrEmpty($SavePath)) {
            throw "SavePath cannot be null or empty."
        }

        # Extract ProphixTime from filename
        $prophixTime = Get-ProphixTimeFromFileName (Split-Path $XMLFile -Leaf)
        if (-not $prophixTime) {
            Write-Warning "Could not extract date from filename: $XMLFile"
            $prophixTime = "Unknown"
        }

        # Load XML file with encoding specification
        Write-Host "Loading XML file from: $XMLFile"
        $xmlContent = New-Object System.Xml.XmlDocument
        $xmlContent.PreserveWhitespace = $true
        $xmlContent.Load($XMLFile)

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
                'Branch' = $accountName  # Placeholder as requested
                'Product Line' = $accountName  # Placeholder as requested
                'Debit' = [decimal]::Parse($debitAmount)
                'Credit' = [decimal]::Parse($creditAmount)
                'Net' = [decimal]::Parse($debitAmount) - [decimal]::Parse($creditAmount)
                'ProphixTime' = $prophixTime
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
            'Branch' = 'TOTAL'
            'Product Line' = 'TOTAL'
            'Debit' = [decimal]::Parse($totalDebit)
            'Credit' = [decimal]::Parse($totalCredit)
            'Net' = [decimal]::Parse($totalDebit) - [decimal]::Parse($totalCredit)
            'ProphixTime' = $prophixTime
        }

        # Export to CSV with UTF-8 encoding (without BOM)
        Write-Host "Exporting to CSV: $SavePath"
        $rows | Export-Csv -Path $SavePath -NoTypeInformation -Encoding UTF8NoBOM

        # Print summary
        Write-Host "`nConversion completed successfully!"
        Write-Host "Total rows processed: $($rows.Count)"
        Write-Host "Total Debits: $($totalDebit)"
        Write-Host "Total Credits: $($totalCredit)"
        Write-Host "Output saved to: $SavePath"
    }
    catch {
        Write-Error "Error processing XML file: $($_.Exception.Message)"
        exit 1
    }
}

# Main execution block
try {
    foreach ($file in $XMLFile) {
        Write-Host "Checking if path exists: $file"
        if (-not (Test-Path -Path $file)) {
            Write-Error "The specified path does not exist: $file"
            continue
        }

        # Resolve the full path and extract the Path property
        $resolvedPath = (Resolve-Path $file).Path
        Write-Host "Resolved path: $resolvedPath"

        # Determine if the path is a directory or a file
        $item = Get-Item $resolvedPath
        if ($item.PSIsContainer) {
            Write-Host "Processing directory: $resolvedPath"

            # Collect the file paths as strings, ensuring only files are included
            $xmlFiles = Get-ChildItem -Path $resolvedPath -Filter "TrialBalance_*.xml" | Where-Object { -not $_.PSIsContainer } | Select-Object -ExpandProperty FullName

            Write-Host "Number of XML files found: $($xmlFiles.Count)"
            # List the files found
            Write-Host "XML files found:"
            foreach ($filePath in $xmlFiles) {
                Write-Host " - $filePath"
            }

            if ($xmlFiles.Count -eq 0) {
                Write-Warning "No matching XML files found in directory: $resolvedPath"
                continue
            }

            foreach ($xmlFilePath in $xmlFiles) {
                Write-Host "Processing file: $xmlFilePath"

                # Determine the output path
                if ($SavePath) {
                    # If SavePath is provided, use it but keep original filename
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($xmlFilePath)
                    $outputPath = Join-Path $SavePath ($baseName + '.csv')
                } else {
                    # Use same directory and base name as XML file
                    $directory = [System.IO.Path]::GetDirectoryName($xmlFilePath)
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($xmlFilePath)
                    $outputPath = Join-Path $directory ($baseName + '.csv')
                }
                Write-Host "Output path: $outputPath"

                # Call the conversion function
                Convert-QBXMLToCSV -XMLFile $xmlFilePath -SavePath $outputPath -Separator $Separator
            }
        }
        elseif (-not $item.PSIsContainer) {
            Write-Host "Processing file: $resolvedPath"

            # Determine the output path
            if ($SavePath) {
                # If SavePath is provided, use it but keep original filename
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
                $outputPath = Join-Path $SavePath ($baseName + '.csv')
            } else {
                # Use same directory and base name as XML file
                $directory = [System.IO.Path]::GetDirectoryName($resolvedPath)
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
                $outputPath = Join-Path $directory ($baseName + '.csv')
            }
            Write-Host "Output path: $outputPath"

            # Call the conversion function
            Convert-QBXMLToCSV -XMLFile $resolvedPath -SavePath $outputPath -Separator $Separator
        }
        else {
            Write-Error "Invalid path specified: $file"
            continue
        }
    }
}
catch {
    Write-Error "Error in main execution block: $($_.Exception.Message)"
    exit 1
}
