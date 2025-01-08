@{
    RootModule = 'PostgreSQLUtils.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f8d90f9e-9c2a-4e9d-b308-415398f12345'
    Author = 'Benjamin W'
    Description = 'PostgreSQL utility functions for data loading and querying'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'ConvertTo-PostgreSQLTable',
        'ConvertTo-PostgreSQLTable2',
        'Get-LastLoadDate',
        'Set-LastLoadDate', 
        'Get-TableColumn',
        'Initialize-PostgreSQLConnection',
        'Test-TableExists',
        'Test-ColumnExists',
        'Test-TableRowsEqual',
        'Test-ArrayOfRowsEqual',
        'Get-TableColumn',
        'Get-TableRowCount',
        'Get-TableDuplicates',
        'Merge-DeltaData',
        'Get-TableRow',
        'Get-TableRows',
        'Get-MostRecentRow',
        'Restore-TableState',
        'Get-DuplicateValuesFromColumn',
        'Remove-PostgreSQLTable'
        )
    PrivateData = @{
        PSData = @{
            Tags = @('PostgreSQL', 'Database', 'CSV')
        }
    }
}