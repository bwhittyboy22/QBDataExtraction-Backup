# C:\path\to\custom_query.ps1
$qbxmlRequest = @"
<?xml version="1.0" encoding="utf-8"?>
<?qbxml version="13.0"?>
<QBXML>
  <QBXMLMsgsRq onError="continueOnError">
    <JournalEntryQueryRq requestID="1">
      <TxnDateFilter>
        <FromTxnDate>2024-08-01</FromTxnDate>
        <ToTxnDate>2024-08-31</ToTxnDate>
      </TxnDateFilter>
      <IncludeLineItems>true</IncludeLineItems>
    </JournalEntryQueryRq>
  </QBXMLMsgsRq>
</QBXML>
"@
