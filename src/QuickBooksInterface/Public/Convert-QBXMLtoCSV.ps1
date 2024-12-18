function Convert-QBXMLtoCSV {
    # [CmdletBinding(DefaultParameterSetName='Folder')]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("Invoice", "Vendor", "Bill", "Customer", "JournalEntry", "Transfer", "Transaction")]
        [string]$ReportType,

        [Parameter(ParameterSetName='Folder')]
        [string]$FolderPath,

        [Parameter(ParameterSetName='SingleFile')]
        [string]$XMLFilePath,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    # Function to properly escape CSV values
    function Format-CsvValue {
        param([string]$value)
        
        if ($value -match '[,"\r\n]') {
            # Escape double quotes by doubling them and wrap in quotes
            $escaped = $value -replace '"', '""'
            return """$escaped"""
        }
        return $value
    }

    # Function to extract keys and values simultaneously
    function Process-XmlNode {
        param (
            [System.Xml.XmlNode]$node,
            [string]$prefix = "",
            [hashtable]$keys,
            [System.Collections.ArrayList]$values
        )

        $currentValues = @{}
        
        foreach ($child in $node.ChildNodes) {
            if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                $newPrefix = if ($prefix) { "$prefix.$($child.Name)" } else { $child.Name }
                
                if ($child.HasChildNodes -and $child.ChildNodes.Count -eq 1 -and 
                    $child.ChildNodes[0].NodeType -eq [System.Xml.XmlNodeType]::Text) {
                    # This is a leaf node with a value
                    $keys[$newPrefix] = $true
                    $currentValues[$newPrefix] = $child.InnerText
                } else {
                    # Recurse for non-leaf nodes
                    $nestedValues = Process-XmlNode -node $child -prefix $newPrefix -keys $keys -values $values
                    foreach ($kvp in $nestedValues.GetEnumerator()) {
                        $currentValues[$kvp.Key] = $kvp.Value
                    }
                }
            }
        }
        
        return $currentValues
    }

    # Validate paths
    <#
    if ($PSCmdlet.ParameterSetName -eq 'Folder') {
        if (-not (Test-Path -Path $FolderPath -PathType Container)) {
            Write-Error "Folder path does not exist: $FolderPath"
            return
        }
        $xmlFiles = Get-ChildItem -Path $FolderPath -Filter "*.xml" | Select-Object -ExpandProperty FullName
    } else {
        if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
            Write-Error "File does not exist: $FilePath"
            return
        }
        $xmlFiles = @($FilePath)
    }
    #>

    if (-not (Test-Path -Path $XMLFilePath -PathType Leaf)) {
        Write-Error "File does not exist: $XMLFilePath"
        return
    }
    $xmlFiles = @($XMLFilePath)

    # Create output directory if it doesn't exist
    if (-not (Test-Path -Path (Split-Path -Path $OutputPath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path -Path $OutputPath -Parent) -Force | Out-Null
    }

    # Process each file
    foreach ($file in $xmlFiles) {
        try {
            Write-Output "Processing file: $file"
            
            # Load XML content
            $xmlContent = Get-Content -Path $file -Raw
            [xml]$xmlDoc = $xmlContent
            
            # Get all nodes of the specified report type
            $typeNodes = $xmlDoc.SelectNodes("//${ReportType}Ret")
            if ($typeNodes.Count -eq 0) {
                Write-Warning "No ${ReportType}Ret nodes found in $file"
                continue
            }
            
            Write-Output "Found $($typeNodes.Count) ${ReportType}Ret nodes"
            
            # Initialize collections
            $keys = @{}
            $rows = [System.Collections.ArrayList]::new()
            
            # Process all nodes in a single pass
            foreach ($node in $typeNodes) {
                $values = Process-XmlNode -node $node -keys $keys -values $rows
                [void]$rows.Add($values)
            }
            
            # Sort headers once
            $headers = $keys.Keys | Sort-Object -CaseSensitive:$false
            
            # Prepare output file path
            $outputFile = if ($PSCmdlet.ParameterSetName -eq 'Folder') {
                $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file)
                Join-Path -Path $OutputPath -ChildPath "${fileName}_${ReportType}.csv"
            } else {
                $OutputPath
            }
            
            # Write CSV header
            $headers -join ',' | Out-File -FilePath $outputFile -Encoding UTF8
            
            # Write rows with proper CSV escaping
            foreach ($row in $rows) {
                $csvLine = ($headers | ForEach-Object { Format-CsvValue ($row[$_] ?? '') }) -join ','
                $csvLine | Add-Content -Path $outputFile -Encoding UTF8
            }
            
            Write-Output "Created CSV file: $outputFile"
            
        } catch {
            Write-Error "Error processing file $file : $_"
        }
    }
}
