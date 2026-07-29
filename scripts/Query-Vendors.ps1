param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("SSI", "ECH", "WCH", "FE")]
    [string]$Division,

    [Parameter(Mandatory=$true)]
    [string]$CompanyFile,

    [Parameter(Mandatory=$false)]
    [string]$SavePath
)

# Validate the company file exists before we bother connecting.
if (-not (Test-Path -Path $CompanyFile -PathType Leaf)) {
    Write-Error "Company file not found: $CompanyFile"
    exit 1
}

# Default: <project root>/files/exports/<Division>
if (-not $SavePath) {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $SavePath = Join-Path $projectRoot 'files' 'exports' $Division
}

if (-not (Test-Path $SavePath)) {
    New-Item -ItemType Directory -Path $SavePath -Force | Out-Null
}

# Track what we actually started so we only tear down what exists.
$qbxmlrp        = $null
$ticket         = $null
$connectionOpen = $false
$sessionBegun   = $false

try {
    # --- Create the COM object ---
    try {
        $qbxmlrp = New-Object -ComObject QBXMLRP2.RequestProcessor
    }
    catch {
        throw "Could not create the QuickBooks COM object (QBXMLRP2.RequestProcessor). Is the QuickBooks SDK installed and registered? Underlying error: $($_.Exception.Message)"
    }

    # --- Open connection & begin session ---
    $qbxmlrp.OpenConnection2("", "SSIQBAutomation", 1)
    $connectionOpen = $true

    $ticket = $qbxmlrp.BeginSession($CompanyFile, 2)
    $sessionBegun = $true

    # --- Vendor query ---
    $qbxmlRequest = @"
<?qbxml version="2.0"?>
<QBXML>
  <QBXMLMsgsRq onError="continueOnError">
    <VendorQueryRq requestID="1" />
  </QBXMLMsgsRq>
</QBXML>
"@

    $response = $qbxmlrp.ProcessRequest($ticket, $qbxmlRequest)

    # --- Save (only reached if the query succeeded) ---
    $fileName = "$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($Division)_Vendor.xml"
    $filePath = Join-Path -Path $SavePath -ChildPath $fileName
    $response | Out-File -FilePath $filePath -Encoding UTF8
    Write-Output "Vendor Query saved to $filePath"
}
catch {
    Write-Error "QuickBooks operation failed: $($_.Exception.Message)"
    exit 1
}
finally {
    if ($sessionBegun) {
        try { $qbxmlrp.EndSession($ticket) } catch { Write-Warning "Failed to end QB session: $($_.Exception.Message)" }
    }
    if ($connectionOpen) {
        try { $qbxmlrp.CloseConnection() } catch { Write-Warning "Failed to close QB connection: $($_.Exception.Message)" }
    }
    if ($qbxmlrp) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($qbxmlrp)
    }
}