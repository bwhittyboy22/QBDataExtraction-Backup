@{
    RootModule = 'PostgreSQLUtils.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f8d90f9e-9c2a-4e9d-b308-415398f12345'
    Author = 'Benjamin W'
    Description = 'PostgreSQL utility functions for data loading and querying'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'ConvertTo-PostgreSQLTable', 
        'Get-LastLoadDate',
        'Set-LastLoadDate', 
        'Get-TableColumn',
        'Initialize-PostgreSQLConnection',
        'Test-TableExists',
        'Test-ColumnExists',
        'Get-TableColumn',
        'Get-TableRow',
        'Get-DuplicateValuesFromColumn'
        )
    PrivateData = @{
        PSData = @{
            Tags = @('PostgreSQL', 'Database', 'CSV')
        }
    }
}