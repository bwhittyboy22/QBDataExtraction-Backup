# XML to CSV Converter for QuickBooks Data
param(
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,
    
    [Parameter(Mandatory=$true)]
    [string]$SchemaFolderPath
)

# Define document types and their configurations
$documentTypes = @{
    "Account" = @{
        XmlPattern = "*_Account.xml"
        SchemaFiles = @{
            Parent = "Account_schema_sorted.json"
        }
        HasLineItems = $false
        RootNode = "AccountRet"
    }
    "Vendor" = @{
        XmlPattern = "*_Vendor.xml"
        SchemaFiles = @{
            Parent = "Vendor_schema_sorted.json"
        }
        HasLineItems = $false
        RootNode = "VendorRet"
    }
    "Invoice" = @{
        XmlPattern = "*_Invoice.xml"
        SchemaFiles = @{
            Parent = "Invoice_Parent_Schema.json"
            LineItems = @{
                "InvoiceLineRet" = "Invoice_InvoiceLineRet_Schema.json"
                "InvoiceLineGroupRet" = "Invoice_InvoiceLineGroupRet_Schema.json"
            }
        }
        HasLineItems = $true
        RootNode = "InvoiceRet"
    }
    "JournalEntry" = @{
        XmlPattern = "*_JournalEntry.xml"
        SchemaFiles = @{
            Parent = "JournalEntry_Parent_Schema.json"
            LineItems = @{
                "JournalDebitLine" = "JournalEntry_JournalDebitLine_Schema.json"
                "JournalCreditLine" = "JournalEntry_JournalCreditLine_Schema.json"
            }
        }
        HasLineItems = $true
        RootNode = "JournalEntryRet"
    }
    "PurchaseOrder" = @{
        XmlPattern = "*_PurchaseOrder.xml"
        SchemaFiles = @{
            Parent = "PurchaseOrder_Parent_Schema.json"
            LineItems = @{
                "PurchaseOrderLineRet" = "PurchaseOrder_PurchaseOrderLineRet_Schema.json"
                "PurchaseOrderLineGroupRet" = "PurchaseOrder_PurchaseOrderLineGroupRet_Schema.json"
            }
        }
        HasLineItems = $true
        RootNode = "PurchaseOrderRet"
    }
    "SalesOrder" = @{
        XmlPattern = "*_SalesOrder.xml"
        SchemaFiles = @{
            Parent = "SalesOrder_Parent_Schema.json"
            LineItems = @{
                "SalesOrderLineRet" = "SalesOrder_SalesOrderLineRet_Schema.json"
                "SalesOrderLineGroupRet" = "SalesOrder_SalesOrderLineGroupRet_Schema.json"
            }
        }
        HasLineItems = $true
        RootNode = "SalesOrderRet"
    }
}


function Convert-XmlNodeToFlatObject {
    param (
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlNode]$Node,
        
        [string]$ParentPath = ""
    )
    
    $result = @{}
    
    try {
        # Handle attributes
        if ($Node.Attributes) {
            foreach ($attr in $Node.Attributes) {
                $key = if ($ParentPath) { "$ParentPath.$($attr.Name)" } else { $attr.Name }
                $result[$key] = $attr.Value
            }
        }
        
        # Handle child nodes
        foreach ($childNode in $Node.ChildNodes) {
            if ($childNode.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                $childPath = if ($ParentPath) { "$ParentPath.$($childNode.Name)" } else { $childNode.Name }
                
                if ($childNode.HasChildNodes -and $childNode.ChildNodes.Count -eq 1 -and 
                    $childNode.ChildNodes[0].NodeType -eq [System.Xml.XmlNodeType]::Text) {
                    # Leaf node with text value
                    $result[$childPath] = $childNode.InnerText
                }
                else {
                    # Complex node - recurse
                    $childProperties = Convert-XmlNodeToFlatObject -Node $childNode -ParentPath $childPath
                    foreach ($prop in $childProperties.GetEnumerator()) {
                        $result[$prop.Key] = $prop.Value
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Error processing node $($Node.Name) : $_"
    }
    
    return $result
}

function Get-SchemaFields {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SchemaPath
    )
    
    try {
        $schema = Get-Content $SchemaPath -Raw | ConvertFrom-Json
        return $schema.Fields.PSObject.Properties | ForEach-Object { $_.Name }
    }
    catch {
        Write-Error "Error loading schema file $SchemaPat : $_"
        throw
    }
}

function Process-Document {
    param (
        [Parameter(Mandatory=$true)]
        [string]$XmlPath,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputFolder,
        
        [Parameter(Mandatory=$true)]
        [string]$DocumentType,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$DocumentConfig
    )
    
    try {
        $fileName = Split-Path $XmlPath -Leaf
        Write-Host "Processing $DocumentType file: $fileName"
        
        # Create output folder if it doesn't exist
        if (-not (Test-Path $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
        }
        
        # Load schemas
        $parentSchemaPath = Join-Path $SchemaFolderPath $DocumentConfig.SchemaFiles.Parent
        $parentFields = Get-SchemaFields -SchemaPath $parentSchemaPath
        
        # Initialize XML reader
        $xmlReader = [System.Xml.XmlReader]::Create($XmlPath)
        $baseFileName = [System.IO.Path]::GetFileNameWithoutExtension($XmlPath)
        
        # Initialize output files
        $parentCsvPath = Join-Path $OutputFolder "${baseFileName}_Parent.csv"
        $parentWriter = [System.IO.StreamWriter]::new($parentCsvPath)
        
        # Write CSV headers
        $parentWriter.WriteLine(($parentFields -join ","))
        
        # Initialize line item writers if needed
        $lineItemWriters = @{}
        $lineItemFields = @{}
        if ($DocumentConfig.HasLineItems) {
            foreach ($lineItemType in $DocumentConfig.SchemaFiles.LineItems.Keys) {
                $lineItemSchemaPath = Join-Path $SchemaFolderPath $DocumentConfig.SchemaFiles.LineItems[$lineItemType]
                $lineItemFields[$lineItemType] = Get-SchemaFields -SchemaPath $lineItemSchemaPath
                
                $lineItemCsvPath = Join-Path $OutputFolder "${baseFileName}_${lineItemType}.csv"
                $lineItemWriters[$lineItemType] = [System.IO.StreamWriter]::new($lineItemCsvPath)
                $lineItemWriters[$lineItemType].WriteLine(($lineItemFields[$lineItemType] -join ","))
            }
        }
        
        $recordCount = 0
        $depth = 0
        
        # Process XML stream
        while ($xmlReader.Read()) {
            if ($xmlReader.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                if ($xmlReader.Name -eq $DocumentConfig.RootNode) {
                    $depth = $xmlReader.Depth
                    
                    # Load the current node as XmlDocument for easier processing
                    $doc = New-Object System.Xml.XmlDocument
                    $node = $doc.ReadNode($xmlReader)
                    
                    # Process parent record
                    $parentRecord = Convert-XmlNodeToFlatObject -Node $node
                    $parentLine = ($parentFields | ForEach-Object { 
                        "`"$($parentRecord[$_] -replace '"','""')`""
                    }) -join ","
                    $parentWriter.WriteLine($parentLine)
                    
                    # Process line items if present
                    if ($DocumentConfig.HasLineItems) {
                        foreach ($lineItemType in $DocumentConfig.SchemaFiles.LineItems.Keys) {
                            foreach ($lineItem in $node.SelectNodes("./$lineItemType")) {
                                $lineItemRecord = Convert-XmlNodeToFlatObject -Node $lineItem
                                $lineItemRecord["ParentTxnID"] = $parentRecord["TxnID"]
                                $lineItemLine = ($lineItemFields[$lineItemType] | ForEach-Object { 
                                    "`"$($lineItemRecord[$_] -replace '"','""')`""
                                }) -join ","
                                $lineItemWriters[$lineItemType].WriteLine($lineItemLine)
                            }
                        }
                    }
                    
                    $recordCount++
                    if ($recordCount % 1000 -eq 0) {
                        Write-Host "Processed $recordCount records from $fileName"
                    }
                }
            }
        }
        
        # Cleanup
        $parentWriter.Close()
        if ($DocumentConfig.HasLineItems) {
            foreach ($writer in $lineItemWriters.Values) {
                $writer.Close()
            }
        }
        $xmlReader.Close()
        
        Write-Host "Completed processing $fileName. Total records: $recordCount"
    }
    catch {
        Write-Error "Error processing $XmlPath : $_"
        throw
    }
    finally {
        if ($parentWriter) { $parentWriter.Close() }
        if ($lineItemWriters) { 
            foreach ($writer in $lineItemWriters.Values) {
                if ($writer) { $writer.Close() }
            }
        }
        if ($xmlReader) { $xmlReader.Close() }
    }
}

# Main script execution
$outputFolder = Join-Path $FolderPath "CSV_Output"

# Process each document type
foreach ($documentType in $documentTypes.Keys) {
    $config = $documentTypes[$documentType]
    Get-ChildItem -Path $FolderPath -Filter $config.XmlPattern | ForEach-Object {
        Process-Document -XmlPath $_.FullName -OutputFolder $outputFolder -DocumentType $documentType -DocumentConfig $config
    }
}

Write-Host "Processing complete. Output files are in $outputFolder"