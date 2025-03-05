param(
    [Parameter(Mandatory=$true)]
    [string[]]$FolderPath
)

$XMLFiles = Get-ChildItem -Path $FolderPath -Filter "TrialBalance_*.xml"

function ConvertTrialBalanceXMLTo-CSV {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$XMLFile
    )

    foreach ($file in $XMLFile) {
        Write-Host "Converting: $file.Name"
    }
}

ConvertTrialBalanceXMLTo-CSV -XMLFile $XMLFiles
