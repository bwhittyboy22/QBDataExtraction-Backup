# QuickBooksSchemaTools.psm1

#Region Helper Functions
function Join-DataType {
    param([string]$QBDataType)
    switch ($QBDataType) {
        "IDTYPE" { return "string" }
        "DATETIMETYPE" { return "datetime" }
        "DATETYPE" { return "date" }
        "STRTYPE" { return "string" }
        "INTTYPE" { return "integer" }
        "AMTTYPE" { return "decimal" }
        "PRICETYPE" { return "decimal" }
        "QUANTYPE" { return "decimal" }
        "BOOLTYPE" { return "boolean" }
        "GUIDTYPE" { return "string" }
        "FLOATTYPE" { return "float" }
        "PERCENTTYPE" { return "float" }
        "ENUMTYPE" { return "string" }
        default { return "string" }
    }
}

function ConvertTo-SortedJsonObject {
    param (
        [Parameter(Mandatory=$true)]
        [object]$InputObject
    )

    if ($InputObject -is [PSCustomObject]) {
        $properties = $InputObject.PSObject.Properties | 
            Sort-Object -Property Name |
            ForEach-Object {
                $name = $_.Name
                $value = $_.Value
                
                if ($value -is [PSCustomObject] -or $value -is [Array]) {
                    $value = ConvertTo-SortedJsonObject -InputObject $value
                }
                
                @{
                    Name = $name
                    Value = $value
                }
            }
        
        $sortedObject = [PSCustomObject]@{}
        $properties | ForEach-Object {
            $sortedObject | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
        }
        return $sortedObject
    }
    elseif ($InputObject -is [Array]) {
        return @($InputObject | ForEach-Object {
            if ($_ -is [PSCustomObject] -or $_ -is [Array]) {
                ConvertTo-SortedJsonObject -InputObject $_
            } else {
                $_
            }
        })
    }
    else {
        return $InputObject
    }
}

function Invoke-ProcessSchemaNode {
    param(
        [System.Xml.XmlNode]$Node,
        [hashtable]$SchemaFields,
        [string]$CurrentPath = ""
    )
    
    $childNodes = $Node.ChildNodes
    $i = 0
    while ($i -lt $childNodes.Count) {
        $childNode = $childNodes[$i]
        
        if ($childNode.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            $nodeName = $childNode.Name
            $nodePath = if ($CurrentPath) { "$CurrentPath.$nodeName" } else { $nodeName }
            
            $qbDataType = $childNode.InnerText.Trim()
            $dataType = Join-DataType $qbDataType
            
            $isRequired = $false
            $isArray = $false
            
            $nextSiblingIndex = $i + 1
            while ($nextSiblingIndex -lt $childNodes.Count) {
                $nextSibling = $childNodes[$nextSiblingIndex]
                if ($nextSibling.NodeType -eq [System.Xml.XmlNodeType]::Comment) {
                    $comment = $nextSibling.Value
                    if ($comment -match 'required') {
                        $isRequired = $true
                    }
                    if ($comment -match 'may repeat') {
                        $isArray = $true
                    }
                    $nextSiblingIndex++
                } else {
                    break
                }
            }
            
            $hasElementChildren = $childNode.HasChildNodes -and ($childNode.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
            if (-not $hasElementChildren) {
                if (-not $SchemaFields.ContainsKey($nodePath)) {
                    $parentPath = $CurrentPath
                    $field = [PSCustomObject]@{
                        Name       = $nodeName
                        ParentPath = $parentPath
                        DataType   = $dataType
                        IsArray    = $isArray
                        IsRequired = $isRequired
                    }
                    $SchemaFields[$nodePath] = $field
                }
            }
            
            if ($hasElementChildren) {
                Invoke-ProcessSchemaNode -Node $childNode -SchemaFields $SchemaFields -CurrentPath $nodePath
            }
        }
        $i++
    }
}

function Get-JsonNodesCountByObject {
    param ($jsonObject)
    $count = 0

    foreach ($key in $jsonObject.PSObject.Properties) {
        $count++

        if ($key.Value -is [System.Management.Automation.PSCustomObject]) {
            $count += Get-JsonNodesCountByObject -jsonObject $key.Value
        }
        elseif ($key.Value -is [System.Collections.IEnumerable] -and -not ($key.Value -is [string])) {
            foreach ($item in $key.Value) {
                if ($item -is [System.Management.Automation.PSCustomObject]) {
                    $count += Get-JsonNodesCountByObject -jsonObject $item
                }
            }
        }
    }

    return $count
}
#EndRegion

#Region Public Functions
function ConvertTo-SortedSchemaKeys {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputPath,

        [Parameter(Mandatory=$false)]
        [string]$OutputPath
    )

    if (-not $OutputPath) {
        $directory = Split-Path -Parent $InputPath
        $filename = Split-Path -Leaf $InputPath
        $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($filename)
        $extension = [System.IO.Path]::GetExtension($filename)
        $OutputPath = Join-Path $directory "$fileNameWithoutExtension`_sorted$extension"
    }

    try {
        if (-not (Test-Path $InputPath)) {
            throw "Input file not found: $InputPath"
        }

        $outputDir = Split-Path -Parent $OutputPath
        if (-not (Test-Path $outputDir)) {
            throw "Output directory does not exist: $outputDir"
        }

        $jsonContent = Get-Content -Path $InputPath -Raw | ConvertFrom-Json
        $sortedJson = ConvertTo-SortedJsonObject -InputObject $jsonContent
        $sortedJson | ConvertTo-Json -Depth 100 | Set-Content -Path $OutputPath
        Write-Host "Sorted JSON saved to: $OutputPath"
    }
    catch {
        Write-Error "An error occurred: $_"
        throw
    }
}

function New-QuickBooksSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputFile,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$SaveSchemaJSON
    )

    try {
        # Validate input file exists
        if (-not (Test-Path -Path $InputFile)) {
            throw "Input file does not exist: $InputFile"
        }

        # Try to read the file content first
        $fileContent = Get-Content -Path $InputFile -Raw
        if ([string]::IsNullOrWhiteSpace($fileContent)) {
            throw "Input file is empty"
        }

        # Check if content looks like XML
        if (-not ($fileContent.TrimStart().StartsWith("<"))) {
            throw "Input file does not appear to be XML. File content starts with: $($fileContent.Substring(0, [Math]::Min(50, $fileContent.Length)))..."
        }

        Write-Verbose "Input file validation passed. Creating XML document..."

        $schemaJson = @{
            ReportType = $ReportType
            GeneratedDate = (Get-Date).ToString("o")
            Fields = @{}
        }

        $xml = New-Object System.Xml.XmlDocument
        $xml.PreserveWhitespace = $true
        
        # Try loading the XML with better error handling
        try {
            # First try loading as-is
            $xml.LoadXml($fileContent)
        }
        catch {
            Write-Verbose "Direct XML loading failed, attempting to read file directly..."
            try {
                # If that fails, try loading from file
                $xml.Load($InputFile)
            }
            catch {
                # If both methods fail, try to identify common issues
                if ($fileContent -match '<?xml') {
                    Write-Warning "File appears to contain XML declaration. Checking for encoding issues..."
                }
                if ($fileContent -match '<\?xml.*encoding=["'']([^"'']+)["'']') {
                    Write-Warning "Found XML encoding: $($matches[1])"
                }
                throw "Failed to load XML content. Error: $_`nFirst 100 characters of file: $($fileContent.Substring(0, [Math]::Min(100, $fileContent.Length)))"
            }
        }

        Write-Verbose "XML loaded successfully. Searching for $ReportType nodes..."

        $baseNodeName = $ReportType + "Ret"
        $reportTypeNodes = $xml.SelectNodes("//$baseNodeName")

        if ($reportTypeNodes.Count -eq 0) {
            Write-Warning "No $ReportType nodes found in the schema file."
            return $null
        }

        Write-Host "Processing schema for $ReportType..."
        $schemaFields = @{}

        foreach ($node in $reportTypeNodes) {
            Invoke-ProcessSchemaNode -Node $node -SchemaFields $schemaFields
        }

        foreach ($fieldPath in $schemaFields.Keys | Sort-Object) {
            $field = $schemaFields[$fieldPath]
            $schemaJson.Fields[$fieldPath] = @{
                Name       = $field.Name
                ParentPath = $field.ParentPath
                DataType   = $field.DataType
                IsArray    = $field.IsArray
                IsRequired = $field.IsRequired
            }
        }

        if ($SaveSchemaJSON -and $OutputPath) {
            if (-not (Test-Path $OutputPath)) {
                New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
            }

            $schemaFile = Join-Path $OutputPath "$($ReportType)_schema.json"
            $schemaJson | ConvertTo-Json -Depth 10 | Out-File -FilePath $schemaFile -Encoding UTF8
            Write-Host "Schema file generated at: $schemaFile"
        }

        return $schemaJson
    }
    catch {
        Write-Error "Error generating QuickBooks schema: $_"
        throw
    }
}

function Get-JsonKeyCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputFile
    )

    try {
        $jsonContent = Get-Content -Path $InputFile -Raw | ConvertFrom-Json
        $totalNodes = Get-JsonNodesCountByObject -jsonObject $jsonContent
        return $totalNodes
    }
    catch {
        Write-Error "Error counting JSON keys: $_"
        throw
    }
}

function Compare-SchemaFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Schema1Path,

        [Parameter(Mandatory = $true)]
        [string]$Schema2Path
    )

    try {
        $jsonContent1 = Get-Content -Path $Schema1Path -Raw | ConvertFrom-Json
        $jsonContent2 = Get-Content -Path $Schema2Path -Raw | ConvertFrom-Json

        $fields1 = @{}
        $fields2 = @{}

        $jsonContent1.Fields.PSObject.Properties | ForEach-Object {
            $fields1[$_.Name] = $_.Value
        }

        $jsonContent2.Fields.PSObject.Properties | ForEach-Object {
            $fields2[$_.Name] = $_.Value
        }

        $keysFile1 = $fields1.Keys
        $keysFile2 = $fields2.Keys

        $uniqueToFile1 = $keysFile1 | Where-Object { $_ -notin $keysFile2 }
        $uniqueToFile2 = $keysFile2 | Where-Object { $_ -notin $keysFile1 }

        return @{
            Schema1KeyCount = $keysFile1.Count
            Schema2KeyCount = $keysFile2.Count
            UniqueToSchema1 = $uniqueToFile1
            UniqueToSchema2 = $uniqueToFile2
        }
    }
    catch {
        Write-Error "Error comparing schema fields: $_"
        throw
    }
}

function Export-LineItemSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SchemaJsonFilePath,
        
        [Parameter(Mandatory=$true)]
        [string[]]$LineItemKeyNames,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputFolder
    )

    try {
        if (-not (Test-Path $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder | Out-Null
        }

        $schema = Get-Content $SchemaJsonFilePath -Raw | ConvertFrom-Json
        $lineItemSchemas = @{}
        
        $parentSchema = @{
            TotalRecords = $schema.TotalRecords
            ReportType = $schema.ReportType
            Fields = @{}
        }

        foreach ($lineItemKey in $LineItemKeyNames) {
            $lineItemSchemas[$lineItemKey] = @{
                TotalRecords = $schema.TotalRecords
                ReportType = $schema.ReportType
                Fields = @{}
            }
        }

        foreach ($field in $schema.Fields.PSObject.Properties) {
            $fieldName = $field.Name
            $fieldValue = $field.Value
            
            $belongsToLineItem = $false
            $isLineItemRoot = $false

            foreach ($lineItemKey in $LineItemKeyNames) {
                if ($fieldName -eq $lineItemKey) {
                    $isLineItemRoot = $true
                    break
                }
                elseif ($fieldName.StartsWith("$lineItemKey.")) {
                    $belongsToLineItem = $true
                    $shortFieldName = $fieldName.Substring("$lineItemKey.".Length)
                    $lineItemSchemas[$lineItemKey].Fields[$shortFieldName] = $fieldValue
                    break
                }
            }
            
            if (-not $belongsToLineItem -and -not $isLineItemRoot) {
                $parentSchema.Fields[$fieldName] = $fieldValue
            }
        }

        $parentOutputPath = Join-Path $OutputFolder "$($schema.ReportType)_Parent_Schema.json"
        $parentSchema | ConvertTo-Json -Depth 10 | Set-Content $parentOutputPath
        Write-Host "Exported parent schema to $parentOutputPath"

        foreach ($lineItemKey in $LineItemKeyNames) {
            $outputPath = Join-Path $OutputFolder "$($schema.ReportType)_$($lineItemKey)_Schema.json"
            $lineItemSchemas[$lineItemKey] | ConvertTo-Json -Depth 10 | Set-Content $outputPath
            Write-Host "Exported schema for $lineItemKey to $outputPath"
        }

        return @{
            ParentSchema = $parentSchema
            LineItemSchemas = $lineItemSchemas
        }
    }
    catch {
        Write-Error "Error exporting line item schema: $_"
        throw
    }
}
#EndRegion

# Export public functions
Export-ModuleMember -Function @(
    'ConvertTo-SortedSchemaKeys',
    'New-QuickBooksSchema',
    'Get-JsonKeyCount',
    'Compare-SchemaFields',
    'Export-LineItemSchema'
)