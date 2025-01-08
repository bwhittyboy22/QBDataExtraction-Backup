@{
    RootModule = 'QuickBooksInterface.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'e8ffa4f0-2a6d-4793-9517-afddc198d2f6' 
    Author = 'Ben Whitney'
    CompanyName = 'American Equipment'
    Description = 'PowerShell module for interacting with QuickBooks Enterprise Desktop using the SDK. Provides functions for querying and extracting reports.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Convert-QBXMLtoCSV',
        'Get-Report',
        'Save-QBXMLFile',
        'Set-TestMode',
        'Start-OpenConnection2ForQuickBooks',
        'Start-SessionInQuickBooks',
        'Stop-OpenConnection2ForQuickBooks',
        'Stop-SessionInQuickBooks',
        'Get-Transactions'
    )
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('QuickBooks', 'Accounting', 'API', 'XML', 'JSON', 'Conversion')
            RequireLicenseAcceptance = $false
        }
    }
}