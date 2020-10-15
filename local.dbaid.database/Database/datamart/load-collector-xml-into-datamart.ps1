<#



#>

$DestDataSource = '.\SQL2017'
$LoadDirectory = 'C:\temp\'

# Open connection to SQL Server destination
$cn = new-object System.Data.SqlClient.SqlConnection("Data Source=$DestDataSource;Integrated Security=SSPI;Initial Catalog=_dbaid");
$cn.Open()

# Loop each xml file to load into destination
Foreach ($file in (Get-ChildItem -Path $LoadDirectory -File -Filter '*.xml')) {
    $filePath = $File.FullName
    $fileName = $File.Name
    $tblName = 'datamart.stage_' + $fileName.Split('_')[1] + '_' + $fileName.Split('_')[2]

    # check if destination table exists 
    $tblExistsCmd = "SELECT [object_id] FROM sys.tables WHERE SCHEMA_NAME([schema_id]) + '.' + [name] = N'$tblName'"
    $tblExists = (New-Object System.Data.SqlClient.SqlCommand($tblExistsCmd, $cn)).ExecuteScalar()

    # read xml into datatable 
    $dt = New-Object System.Data.DataTable
    $dt.ReadXml($file.FullName) | Out-Null

    # if destination table does not esists, use the datatable definition to create the table in the destination sql server.
    if (-not $tblExists) {
        $tblCreate = ""
        $tblCreate += "IF NOT EXISTS (SELECT * FROM sys.objects WHERE [object_id]=OBJECT_ID(N'"+$tblName+"')) `n"
        $tblCreate += "BEGIN `n"
        $tblCreate += "CREATE TABLE " + $tblName + " ( `n"

        For ($i = 0; $i -lt $dt.Columns.Count; $i++) {
            # Mapping datatable types to sql types
            $dataType = switch ($dt.Columns[$i].DataType.Name)
                {
                    'String' { 'NVARCHAR(MAX)' }
                    'DateTimeOffset' { 'DATETIMEOFFSET' }
                    'DateTime' { 'DATETIME2' }
                    'Boolean' { 'BIT' }
                    'Xml' { 'XML' }
                    'Int32' { 'INT' }
                    'Int64' { 'BIGINT' }
                    'Decimal' { 'NUMERIC(18,4)' }
                    default { 'SQL_VARIANT' }
                }

            $tblCreate += $dt.Columns[$i].ColumnName + ' ' + $dataType

            if ($i -ne $dt.Columns.Count-1) {
                $tblCreate += ",`n"
            } 
        }

        $tblCreate += "); `n"
        $tblCreate += "END"

        try { # try to create the table, catch on error and continue loop with next file
            (New-Object System.Data.SqlClient.SqlCommand($tblCreate, $cn)).ExecuteNonQuery() | Out-Null
        } catch {
            $_.Exception | Write-Output
            continue;
        }
    }

    try { # try bulk copy data into destination table
        $bc = New-Object System.Data.SqlClient.SqlBulkCopy($cn)
        $bc.BatchSize = 10000
        $bc.BulkCopyTimeout = 1000
        $bc.DestinationTableName = $tblName
        $bc.WriteToServer($dt)

        Write-Host "Processed file: $fileName"
		Rename-Item -Path $filePath -NewName "$fileName.processed"

		$logInsert = "INSERT INTO [_dbaid].[datamart].[load_file_log] ([file_name]) VALUES (N'$filePath')"
		(New-Object System.Data.SqlClient.SqlCommand($logInsert, $cn)).ExecuteNonQuery() | Out-Null
        
    } catch {
        $_.Exception | Write-Output
    } finally {
        $bc.Close()
    }
}

$cn.Close()