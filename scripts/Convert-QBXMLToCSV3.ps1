# ------------------------------------------------------------
# .SYNOPSIS
#     Converts QuickBooks Desktop QBXML query responses (*.xml) into flat CSV files.
#
# .DESCRIPTION
#     A single, unified converter that replaces the older bin/ converters. It handles
#     every document type the division exports today (Customer, Vendor, Item, Invoice,
#     Bill, SalesOrder, PurchaseOrder) plus anything else shaped like a standard QBXML
#     query response, with no per-type configuration required.
#
#     Key behaviours
#       * Auto-discovers record types. It reads each *QueryRs* block and treats its
#         element children (e.g. CustomerRet, InvoiceRet, ItemInventoryRet) as records,
#         so Item queries that return many sub-types (ItemInventoryRet, ItemServiceRet,
#         ...) each get their own CSV automatically.
#       * Splits parent rows from line items. Any child element ending in "LineRet" or
#         "LineGroupRet" (InvoiceLineRet, ExpenseLineRet, ItemLineRet, ...) is written to
#         its own CSV, linked back to the parent by ParentTxnID. Line groups also emit
#         their nested lines, linked by GroupTxnLineID.
#       * Schema-driven columns. When a matching schema JSON is found (searched
#         recursively under -SchemaFolderPath, so files split across files\schema and
#         files\schema\clean are both picked up), its field list defines the column set
#         and order. This is the "column contract" the Azure ETL depends on.
#       * No silent data loss. Fields present in the XML but absent from the schema are
#         appended as extra columns (sorted) instead of being dropped, with a warning.
#         Use -StrictSchema to keep exactly the schema columns (old behaviour).
#       * Falls back to auto-discovery (union of all fields, sorted) when no schema
#         exists for a section, so Customer/Bill/Item still convert without a schema.
#       * Writes UTF-8 without BOM, which is what PostgreSQL \COPY and Azure ingestion
#         expect.
#
# .PARAMETER InputPath
#     A folder of .xml files, or a single .xml file. Defaults to the current directory.
#
# .PARAMETER OutputPath
#     Folder for the CSV output. Defaults to <InputPath>\CSV_Output.
#
# .PARAMETER SchemaFolderPath
#     Root folder to search (recursively) for schema JSON files. Defaults to
#     .\files\schema relative to the input, then relative to this script. Optional;
#     sections without a schema are auto-discovered.
#
# .PARAMETER StrictSchema
#     Emit only the columns defined by the schema (drop any extra fields found in the
#     data). Off by default so nothing is lost.
#
# .PARAMETER Delimiter
#     CSV delimiter. Defaults to ",".
#
# .EXAMPLE
#     .\Convert-QBXMLToCSV3.ps1 -InputPath .\files\exports\ssi -SchemaFolderPath .\files\schema
#
# .EXAMPLE
#     .\Convert-QBXMLToCSV3.ps1 -InputPath .\files\exports\ssi\20260730_144402_SSI_Invoice.xml
# ------------------------------------------------------------

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$InputPath,

  [Parameter()]
  [string]$OutputPath,

  [Parameter()]
  [string]$SchemaFolderPath,

  [Parameter()]
  [switch]$StrictSchema,

  [Parameter()]
  [string]$Delimiter = ','
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------------- #
# Helpers                                                                        #
# ----------------------------------------------------------------------------- #

function Test-IsLineNode
{
  param([string]$Name)
  return ($Name -like '*LineRet') -or ($Name -like '*LineGroupRet')
}

function ConvertTo-FlatRecord
{
  # ------------------------------------------------------------
  #     Flattens one XML node into an ordered dictionary of dotted-path -> value,
  #     relative to the node's own children (the root element name is NOT included,
  #     which matches how the schema files are keyed).
  #
  #     Line/line-group children are skipped here; they are handled separately so
  #     they can be emitted to their own CSVs. Repeated non-line complex children
  #     (e.g. LinkedTxn) collapse last-wins into single columns, matching the
  #     single-column shape the schemas assume.
  # ------------------------------------------------------------
  param(
    [System.Xml.XmlNode]$Node,
    [string]$Prefix = '',
    [System.Collections.Specialized.OrderedDictionary]$Acc
  )

  if ($null -eq $Acc)
  {
    $Acc = [ordered]@{}
  }

  # Attributes (rare on Ret nodes, but preserved for completeness).
  if ($Node.Attributes)
  {
    foreach ($attr in $Node.Attributes)
    {
      $key = if ($Prefix)
      { "$Prefix.$($attr.Name)" 
      } else
      { $attr.Name 
      }
      $Acc[$key] = $attr.Value
    }
  }

  foreach ($child in $Node.ChildNodes)
  {
    if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element)
    { continue 
    }

    # Use LocalName, not Name: PowerShell shadows .Name with a child <Name>
    # element's text, so .Name can't be trusted to give the tag name.
    $childName = $child.LocalName

    # Skip line sections - handled by the caller.
    if (-not $Prefix -and (Test-IsLineNode $childName))
    { continue 
    }

    $childPath = if ($Prefix)
    { "$Prefix.$childName" 
    } else
    { $childName 
    }

    $isLeaf = $child.HasChildNodes -and
    $child.ChildNodes.Count -eq 1 -and
    $child.ChildNodes[0].NodeType -eq [System.Xml.XmlNodeType]::Text

    if ($isLeaf)
    {
      $Acc[$childPath] = $child.InnerText          # last-wins on repeats
    } elseif ($child.HasChildNodes)
    {
      [void](ConvertTo-FlatRecord -Node $child -Prefix $childPath -Acc $Acc)
    } else
    {
      # Empty element - record its presence as empty string.
      if (-not $Acc.Contains($childPath))
      { $Acc[$childPath] = '' 
      }
    }
  }

  return $Acc
}

function Get-RecordKey
{
  param([System.Collections.Specialized.OrderedDictionary]$Record)
  foreach ($k in 'TxnID', 'ListID')
  {
    if ($Record.Contains($k) -and $Record[$k])
    { return $Record[$k] 
    }
  }
  return $null
}

function Resolve-SchemaColumns
{
  # ------------------------------------------------------------
  #     Returns the ordered list of schema column names for a section, or $null when
  #     no schema file is found. Searches -SchemaFolderPath recursively for the first
  #     candidate file that exists. For combined "*_schema_sorted.json" files, line
  #     fields are filtered out when resolving a PARENT section.
  # ------------------------------------------------------------
  param(
    [string[]]$CandidateNames,
    [string]$SchemaRoot,
    [switch]$IsParent
  )

  if (-not $SchemaRoot -or -not (Test-Path $SchemaRoot))
  { return $null 
  }

  foreach ($name in $CandidateNames)
  {
    $hit = Get-ChildItem -Path $SchemaRoot -Filter $name -Recurse -File -ErrorAction SilentlyContinue |
      Select-Object -First 1
    if ($hit)
    {
      try
      {
        $json = Get-Content $hit.FullName -Raw | ConvertFrom-Json
      } catch
      {
        Write-Warning "Could not parse schema '$($hit.FullName)': $_"
        continue
      }
      if (-not ($json.PSObject.Properties.Name -contains 'Fields'))
      { continue 
      }
      $cols = @($json.Fields.PSObject.Properties | ForEach-Object { $_.Name })

      if ($IsParent)
      {
        # Drop any line-section columns a combined schema may contain.
        $cols = @($cols | Where-Object {
            $head = ($_ -split '\.')[0]
            -not (Test-IsLineNode $head)
          })
      }
      if ($cols.Count -gt 0)
      {
        Write-Verbose "  schema: $($hit.Name) ($($cols.Count) columns)"
        return , $cols
      }
    }
  }
  return $null
}

function Get-SchemaCandidates
{
  param([string]$RecordName, [switch]$IsParent, [string]$ParentType)

  # RecordName like 'InvoiceRet' -> base 'Invoice'; 'InvoiceLineRet' stays.
  if ($IsParent)
  {
    $base = $RecordName -replace 'Ret$', ''
    return @(
      "${base}_Parent_Schema.json",
      "${base}_schema_sorted.json",
      "${RecordName}_Schema.json",
      "${base}_Schema.json"
    )
  } else
  {
    return @(
      "${ParentType}_${RecordName}_Schema.json",
      "${RecordName}_Schema.json"
    )
  }
}

function Format-CsvField
{
  param([string]$Value, [string]$Delim)
  if ($null -eq $Value)
  { return '' 
  }
  if ($Value.IndexOf($Delim) -ge 0 -or
    $Value.IndexOf('"') -ge 0 -or
    $Value.IndexOf("`n") -ge 0 -or
    $Value.IndexOf("`r") -ge 0)
  {
    return '"' + ($Value -replace '"', '""') + '"'
  }
  return $Value
}

function Write-Csv
{
  param(
    [string]$Path,
    [string[]]$Columns,
    [System.Collections.Generic.List[object]]$Rows,
    [string]$Delim
  )
  $enc = [System.Text.UTF8Encoding]::new($false)   # no BOM
  $sw = [System.IO.StreamWriter]::new($Path, $false, $enc)
  try
  {
    # Header names use '_' as the path separator instead of '.' (the internal
    # column keys keep '.' so they still match the schema field names).
    $headerCells = foreach ($c in $Columns)
    { Format-CsvField ($c -replace '\.', '_') $Delim 
    }
    $sw.WriteLine($headerCells -join $Delim)
    foreach ($row in $Rows)
    {
      $line = foreach ($c in $Columns)
      {
        $v = if ($row.Contains($c))
        { [string]$row[$c] 
        } else
        { '' 
        }
        Format-CsvField $v $Delim
      }
      $sw.WriteLine(($line -join $Delim))
    }
  } finally
  {
    $sw.Close()
  }
}

# ----------------------------------------------------------------------------- #
# Section accumulator                                                            #
# ----------------------------------------------------------------------------- #
# One "section" == one output CSV (a parent type or a line type within one file).

function New-Section
{
  param([string]$Name, [bool]$IsParent, [string]$ParentType)
  return [pscustomobject]@{
    Name       = $Name
    IsParent   = $IsParent
    ParentType = $ParentType
    Rows       = [System.Collections.Generic.List[object]]::new()
    Keys       = [System.Collections.Specialized.OrderedDictionary]::new()  # ordered set
  }
}

function Add-Row
{
  param($Section, [System.Collections.Specialized.OrderedDictionary]$Row)
  $Section.Rows.Add($Row)
  foreach ($k in $Row.Keys)
  {
    if (-not $Section.Keys.Contains($k))
    { $Section.Keys[$k] = $true 
    }
  }
}

# ----------------------------------------------------------------------------- #
# Core: process one parent record (and its lines) into sections                 #
# ----------------------------------------------------------------------------- #

function Add-RecordToSections
{
  param(
    [System.Xml.XmlNode]$RecordNode,
    [hashtable]$Sections            # keyed by section name
  )

  $recordName = $RecordNode.LocalName          # LocalName avoids <Name>-child shadowing
  $parentType = $recordName -replace 'Ret$', ''

  # ---- parent row ----
  if (-not $Sections.ContainsKey($recordName))
  {
    $Sections[$recordName] = New-Section -Name $recordName -IsParent $true -ParentType $parentType
  }
  $parentFlat = ConvertTo-FlatRecord -Node $RecordNode
  Add-Row -Section $Sections[$recordName] -Row $parentFlat
  $parentKey = Get-RecordKey -Record $parentFlat

  # ---- line sections ----
  foreach ($child in $RecordNode.ChildNodes)
  {
    if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element)
    { continue 
    }
    $childName = $child.LocalName
    if (-not (Test-IsLineNode $childName))
    { continue 
    }

    $lineName = $childName
    $secKey = "$recordName.$lineName"

    if (-not $Sections.ContainsKey($secKey))
    {
      $Sections[$secKey] = New-Section -Name $lineName -IsParent $false -ParentType $parentType
    }

    if ($lineName -like '*LineGroupRet')
    {
      # Group's own scalar fields (nested lines excluded via flatten rules is
      # not automatic here because Prefix is set, so exclude explicitly below).
      $groupFlat = [ordered]@{ ParentTxnID = $parentKey }
      foreach ($gc in $child.ChildNodes)
      {
        if ($gc.NodeType -ne [System.Xml.XmlNodeType]::Element)
        { continue 
        }
        $gcName = $gc.LocalName
        if (Test-IsLineNode $gcName)
        { continue 
        }   # nested lines handled below
        $sub = ConvertTo-FlatRecord -Node $gc -Prefix $gcName
        foreach ($kv in $sub.GetEnumerator())
        { $groupFlat[$kv.Key] = $kv.Value 
        }
      }
      # also capture the group's direct leaf/attr fields
      $groupSelf = ConvertTo-FlatRecord -Node $child
      foreach ($kv in $groupSelf.GetEnumerator())
      {
        if (-not $groupFlat.Contains($kv.Key))
        { $groupFlat[$kv.Key] = $kv.Value 
        }
      }
      Add-Row -Section $Sections[$secKey] -Row $groupFlat
      $groupLineId = if ($groupFlat.Contains('TxnLineID'))
      { $groupFlat['TxnLineID'] 
      } else
      { $null 
      }

      # nested lines within the group
      foreach ($nested in $child.ChildNodes)
      {
        if ($nested.NodeType -ne [System.Xml.XmlNodeType]::Element)
        { continue 
        }
        $nestedName = $nested.LocalName
        if (-not (Test-IsLineNode $nestedName))
        { continue 
        }
        $nestedKey = "$recordName.$nestedName"
        if (-not $Sections.ContainsKey($nestedKey))
        {
          $Sections[$nestedKey] = New-Section -Name $nestedName -IsParent $false -ParentType $parentType
        }
        $row = [ordered]@{ ParentTxnID = $parentKey; GroupTxnLineID = $groupLineId }
        $flat = ConvertTo-FlatRecord -Node $nested
        foreach ($kv in $flat.GetEnumerator())
        { $row[$kv.Key] = $kv.Value 
        }
        Add-Row -Section $Sections[$nestedKey] -Row $row
      }
    } else
    {
      $row = [ordered]@{ ParentTxnID = $parentKey }
      $flat = ConvertTo-FlatRecord -Node $child
      foreach ($kv in $flat.GetEnumerator())
      { $row[$kv.Key] = $kv.Value 
      }
      Add-Row -Section $Sections[$secKey] -Row $row
    }
  }
}

# ----------------------------------------------------------------------------- #
# Core: process one XML file                                                     #
# ----------------------------------------------------------------------------- #

function Get-RecordNodes
{
  param([System.Xml.XmlDocument]$Doc)

  # Preferred: element children of each *QueryRs block.
  $records = [System.Collections.Generic.List[System.Xml.XmlNode]]::new()
  $queryRs = $Doc.SelectNodes("//*[substring(name(), string-length(name()) - 6) = 'QueryRs']")
  if ($queryRs -and $queryRs.Count -gt 0)
  {
    foreach ($rs in $queryRs)
    {
      foreach ($child in $rs.ChildNodes)
      {
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element -and $child.LocalName -like '*Ret')
        {
          $records.Add($child)
        }
      }
    }
  }

  # Fallback: any *Ret with no *Ret ancestor (top-level records).
  if ($records.Count -eq 0)
  {
    $allRet = $Doc.SelectNodes("//*[substring(name(), string-length(name()) - 2) = 'Ret']")
    foreach ($n in $allRet)
    {
      $hasRetAncestor = $false
      $p = $n.ParentNode
      while ($p -and $p.NodeType -eq [System.Xml.XmlNodeType]::Element)
      {
        if ($p.LocalName -like '*Ret')
        { $hasRetAncestor = $true; break 
        }
        $p = $p.ParentNode
      }
      if (-not $hasRetAncestor)
      { $records.Add($n) 
      }
    }
  }
  return $records
}

function Convert-OneFile
{
  param([string]$FilePath, [string]$OutDir, [string]$SchemaRoot)

  $base = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
  Write-Host "Processing $([System.IO.Path]::GetFileName($FilePath))"

  $doc = [System.Xml.XmlDocument]::new()
  $doc.Load($FilePath)

  $records = @(Get-RecordNodes -Doc $doc)   # @() keeps it an array when empty
  if ($records.Count -eq 0)
  {
    Write-Warning "  no records found - skipping"
    return @()
  }

  $sections = @{}
  foreach ($rec in $records)
  {
    Add-RecordToSections -RecordNode $rec -Sections $sections
  }

  $summaries = @()
  foreach ($secName in ($sections.Keys | Sort-Object))
  {
    $sec = $sections[$secName]
    $discovered = @($sec.Keys.Keys)

    # Resolve schema columns.
    $candidates = Get-SchemaCandidates -RecordName $sec.Name -IsParent:$sec.IsParent -ParentType $sec.ParentType
    $schemaCols = Resolve-SchemaColumns -CandidateNames $candidates -SchemaRoot $SchemaRoot -IsParent:$sec.IsParent
    $usedSchema = $null -ne $schemaCols

    # Build final ordered column list.
    $linkCols = @()
    if (-not $sec.IsParent)
    {
      foreach ($lc in 'ParentTxnID', 'GroupTxnLineID')
      {
        if ($discovered -contains $lc)
        { $linkCols += $lc 
        }
      }
    }

    if ($usedSchema)
    {
      $ordered = [System.Collections.Generic.List[string]]::new()
      foreach ($c in $linkCols)
      { if (-not $ordered.Contains($c))
        { $ordered.Add($c) 
        } 
      }
      foreach ($c in $schemaCols)
      { if (-not $ordered.Contains($c))
        { $ordered.Add($c) 
        } 
      }
      if (-not $StrictSchema)
      {
        $extra = @($discovered | Where-Object { $ordered -notcontains $_ } | Sort-Object)
        if ($extra.Count -gt 0)
        {
          Write-Warning "  $($sec.Name): $($extra.Count) field(s) not in schema, appended: $($extra -join ', ')"
          foreach ($c in $extra)
          { $ordered.Add($c) 
          }
        }
      }
      $columns = $ordered.ToArray()
    } else
    {
      if ($sec.IsParent)
      {
        Write-Warning "  $($sec.Name): no schema found - columns auto-discovered"
      }
      $rest = @($discovered | Where-Object { $linkCols -notcontains $_ } | Sort-Object)
      $columns = @($linkCols) + $rest
    }

    $outFile = Join-Path $OutDir ("{0}_{1}.csv" -f $base, $sec.Name)
    Write-Csv -Path $outFile -Columns $columns -Rows $sec.Rows -Delim $Delimiter

    $summaries += [pscustomobject]@{
      File    = [System.IO.Path]::GetFileName($FilePath)
      Section = $sec.Name
      Type    = if ($sec.IsParent)
      { 'parent' 
      } else
      { 'line' 
      }
      Rows    = $sec.Rows.Count
      Columns = $columns.Count
      Schema  = if ($usedSchema)
      { 'yes' 
      } else
      { 'auto' 
      }
      Output  = [System.IO.Path]::GetFileName($outFile)
    }
  }
  return $summaries
}

# ----------------------------------------------------------------------------- #
# Main                                                                           #
# ----------------------------------------------------------------------------- #

if (-not (Test-Path $InputPath))
{
  throw "InputPath not found: $InputPath"
}

$item = Get-Item $InputPath
# Assign inside each branch (not as an if-expression RHS): the expression form
# collapses a single-element @() back to a scalar, which then breaks .Count.
if ($item.PSIsContainer)
{
  $files = @(Get-ChildItem -Path $InputPath -Filter '*.xml' -File | Sort-Object Name)
} else
{
  $files = @($item)
}

if (@($files).Count -eq 0)
{
  Write-Warning "No .xml files found at $InputPath"
  return
}

# Output folder.
if (-not $OutputPath)
{
  $inRoot = if ($item.PSIsContainer)
  { $item.FullName 
  } else
  { $item.Directory.FullName 
  }
  $OutputPath = Join-Path $inRoot 'CSV_Output'
}
if (-not (Test-Path $OutputPath))
{
  New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Schema root resolution.
if (-not $SchemaFolderPath)
{
  $inRoot = if ($item.PSIsContainer)
  { $item.FullName 
  } else
  { $item.Directory.FullName 
  }
  $candidates = @(
    (Join-Path $inRoot 'files\schema'),
    (Join-Path $inRoot '..\..\schema'),
    (Join-Path $PSScriptRoot '..\files\schema'),
    (Join-Path $PSScriptRoot 'files\schema')
  )
  foreach ($c in $candidates)
  {
    if (Test-Path $c)
    { $SchemaFolderPath = (Resolve-Path $c).Path; break 
    }
  }
}
if ($SchemaFolderPath -and (Test-Path $SchemaFolderPath))
{
  Write-Host "Schema folder: $SchemaFolderPath"
} else
{
  Write-Warning "No schema folder found - all columns will be auto-discovered."
  $SchemaFolderPath = $null
}

$allSummaries = @()
foreach ($f in $files)
{
  try
  {
    $allSummaries += @(Convert-OneFile -FilePath $f.FullName -OutDir $OutputPath -SchemaRoot $SchemaFolderPath)
  } catch
  {
    Write-Error "Failed on $($f.Name): $_"
  }
}

Write-Host ""
Write-Host "===== Summary ====="
if ($allSummaries.Count -gt 0)
{
  # Out-String with an explicit width: -AutoSize renders blank when there is no
  # console (e.g. run non-interactively with -File).
  ($allSummaries | Format-Table -AutoSize | Out-String -Width 4096).TrimEnd() | Write-Host
} else
{
  Write-Host "(no records converted)"
}
Write-Host ""
Write-Host "Output folder: $OutputPath"
