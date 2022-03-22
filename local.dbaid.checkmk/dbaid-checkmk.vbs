Sub Main()
    ' define list of instances to connect to. Array elements should take the form of "MachineName" or "MachineName\InstanceName" (default & named instances respectively) where MachineName can be the hostname or IP address of the server . Optionally, add ",<TCPPort>".
    Dim v_SQLInstances
    v_SQLInstances = Array("localhost")

    ' declare variables
    Dim v_DB_Connect_String
    Dim v_DB_Connect_String_Base
    Dim v_DBAid_Database
    Dim v_SQL_Query 
    Dim v_IsClustered
    Dim v_InstanceName
    Dim v_NetBiosName
    Dim v_HostName
    ' NB - some of the v_SQLChecks variables get reused when processing procedures in the [chart] schema.
    Dim v_SQLChecks_Query
    Dim v_SQLChecks_StateCheck
    Dim v_SQLChecks_Status
    Dim v_SQLChecks_Message
    Dim v_SQLChecks_CheckName
    Dim v_SQLChecks_pnpData
    Dim v_SQLChecks_Row
    Dim v_SQLCharts_WarnExist
    Dim v_SQLCharts_CritExist
    Dim v_SQLCharts_Val
    Dim v_SQLCharts_Warn
    Dim v_SQLCharts_Crit
    Dim v_SQLCharts_AlertValue
    Set v_SQL_Conn = CreateObject("ADODB.Connection")
    Set v_RecordSet = CreateObject("ADODB.RecordSet")
    Set v_SQLChecks_RecordSet = CreateObject("ADODB.RecordSet")
    Set v_WSH_Shell = CreateObject("WScript.Shell")

    ' build base connection string; instance name will be appended
    v_DBAid_Database = "_dbaid"
    v_DB_Connect_String_Base = "Provider=SQLOLEDB.1;Initial Catalog=" & v_DBAid_Database & ";Integrated Security=SSPI;Application Name=Checkmk;Data Source="

    ' Loop through the array of SQL instance names. NB - array index is 0-based
    For x = 0 to UBound(v_SQLInstances)

        v_DB_Connect_String = v_DB_Connect_String_Base & v_SQLInstances(x)

        v_HostName = v_WSH_Shell.ExpandEnvironmentStrings("%COMPUTERNAME%")

        ' open conection to database
        v_SQL_Conn.Open v_DB_Connect_String

        ' query to check if SQL is clustered. Have to CAST to tinyint rather than bit as VBS doesn't understand bit
        ' NB - Machine account for each node needs to have its own login in SQL Server and rights to _dbaid database (admin & monitor roles).
        v_SQL_Query = "SELECT CAST(SERVERPROPERTY('IsClustered') AS tinyint) AS [IsClustered]"

        ' populate recordset
        ' parameters 3 & 4: 0=forward-only cursor (moot if only 1 row returned), 1=read-only records
        ' see https://docs.microsoft.com/en-us/sql/ado/reference/ado-api/open-method-ado-recordset?view=sql-server-2017
        v_RecordSet.Open v_SQL_Query, v_SQL_Conn, 0, 1
        If v_RecordSet.EOF Then
            WScript.Echo "3 mssql_" & v_InstanceName & " - Error occurred querying if instance is clustered."
        Else
            v_IsClustered = v_RecordSet.Fields.Item("IsClustered")
        End If
        ' close recordset so we can reuse
        v_RecordSet.Close

        ' get hostname as SQL Server sees it
        v_SQL_Query = "SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS [NetBIOSName]"
        v_RecordSet.Open v_SQL_Query, v_SQL_Conn, 0, 1
        If v_RecordSet.EOF Then
            WScript.Echo "3 mssql_" & v_InstanceName & " - Error occurred querying machine NetBIOS name."
        Else
            v_NetBiosName = v_RecordSet.Fields.Item("NetBIOSName")
        End If
        v_RecordSet.Close

        ' If computer name & NetBIOS name don't match and SQL instance is clustered, this script is running on the passive node for this SQL instance; so don't run the SQL checks, they'll be run on the active node.
        If UCase(v_NetBiosName) <> UCase(v_HostName) AND v_IsClustered = 1 Then
            Exit Sub
        End If

        ' Refresh check configuration (i.e. to pick up any new jobs or databases added since last check).
        v_SQL_Query = "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [" & v_DBAid_Database & "].[sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'maintenance' AND [name] LIKE N'check_config%'"
        v_RecordSet.Open v_SQL_Query, v_SQL_Conn, 0, 1
        If v_RecordSet.EOF Then
            WScript.Echo "3 mssql_" & v_InstanceName & " - Error occurred refreshing check configuration."
        Else
            Do While (Not v_RecordSet.EOF)
                v_SQLChecks_Query = "EXEC [" & v_DBAid_Database & "]." & v_RecordSet.Fields.Item("proc")
                ' using Conn.Execute method here rather than RecordSet.Open because the inventory procedures don't return a recordset; they just refresh configuration metadata
                v_SQL_Conn.Execute(v_SQLChecks_Query)
                v_RecordSet.MoveNext
        Loop
        End If
        v_RecordSet.Close

        ' get SQL instance name
        v_SQL_Query = "SELECT ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS [InstanceName]"
        v_RecordSet.Open v_SQL_Query, v_SQL_Conn, 0, 1
        If v_RecordSet.EOF Then
            WScript.Echo "3 mssql_INSTANCEUNKNOWN - Error occurred retrieving instance name."
        Else
            v_InstanceName = v_RecordSet.Fields.Item("InstanceName")
        End If
        v_RecordSet.Close

        ' output instance version details.
        v_SQL_Query = "SELECT * FROM [dbo].[get_instance_version](0)"
        v_RecordSet.Open v_SQL_Query, v_SQL_Conn, 0, 1
        If v_RecordSet.EOF Then
            WScript.Echo "3 mssql_" & v_InstanceName & " - Error occurred retrieving instance version details."
        Else
            WScript.Echo v_RecordSet.Fields.Item("string")
        End If
        v_RecordSet.Close


        ' get list of check procedures to loop through
        v_SQL_Query = "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [" & v_DBAid_Database & "].[sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'check'"
        v_RecordSet.Open v_SQL_Query, v_SQL_Conn, 0, 1
        If v_RecordSet.EOF Then
            WScript.Echo "3 mssql_" & v_InstanceName & " - Error occurred looping through checks."
        Else
            Do While (Not v_RecordSet.EOF)
                ' this loop executes each procedure in the [check] schema
                v_SQLChecks_Message = ""
                v_SQLChecks_Count = 0
                v_SQLChecks_CheckName = Replace(Mid(v_RecordSet.Fields.Item("proc"), 10), "]", "") ' gets procedure name sans schema & [] characters. E.g., final output is mssql_Instance_ValueFromThisVariablev_SQLChecks_CheckName
                v_SQLChecks_Query = "EXEC [" & v_DBAid_Database & "]." & v_RecordSet.Fields.Item("proc")
                v_SQLChecks_RecordSet.Open v_SQLChecks_Query, v_SQL_Conn, 0, 1
                v_SQLChecks_StateCheck = v_SQLChecks_RecordSet.Fields.Item("state")

                ' convert literal status to numeric value that Checkmk understands. This conversion could also be done in the stored procedure instead.
                Select Case v_SQLChecks_StateCheck
                    Case "NA" v_SQLChecks_Status = "0"
                    Case "OK" v_SQLChecks_Status = "0"
                    Case "WARNING" v_SQLChecks_Status = "1"
                    Case "CRITICAL" v_SQLChecks_Status = "2"
                    Case Else v_SQLChecks_Status = "3"
                End Select

                Do While (Not v_SQLChecks_RecordSet.EOF)
                    ' this loop concatenates row message data into one message. 
                    ' also capture the number of rows via incrementing count (since RecordSet.RecordCount doesn't work properly and returns -1)
                    ' NB - for backups & inventory, need to have data on one line otherwise it can't be pulled into DOME (only the first line comes through).
                    If (v_RecordSet.Fields.Item("proc") = "[check].[backup]") Or (v_RecordSet.Fields.Item("proc") = "[check].[inventory]") Then
                        v_SQLChecks_Message = v_SQLChecks_Message & v_SQLChecks_RecordSet.Fields.Item("message") & "|"
                        v_SQLChecks_Count = v_SQLChecks_Count + 1
                        v_SQLChecks_RecordSet.MoveNext
                    Else
                        v_SQLChecks_Message = v_SQLChecks_Message & v_SQLChecks_RecordSet.Fields.Item("message") & ";\n "
                        v_SQLChecks_Count = v_SQLChecks_Count + 1
                        v_SQLChecks_RecordSet.MoveNext
                    End If
                Loop
                
                ' If the top row returned has [state] value of "NA", then set count=0 (i.e. monitor doesn't apply, nothing wrong detected). If there's more than one row returned, there's probably a fault.
                Select Case v_SQLChecks_StateCheck
                    Case "NA" v_SQLChecks_Count = 0
                    Case Else v_SQLChecks_Count = v_SQLChecks_Count
                End Select

                ' Write output for Checkmk agent to consume.
                WScript.Echo v_SQLChecks_Status & " mssql_" & v_SQLChecks_CheckName & "_" & v_InstanceName & " count=" & CStr(v_SQLChecks_Count) & " " & v_SQLChecks_StateCheck & " - " & v_SQLChecks_Message

                v_SQLChecks_RecordSet.Close
                v_RecordSet.MoveNext
            Loop
        End If
        v_RecordSet.Close



        ' get list of chart procedures to loop through
        v_SQL_Query = "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [" & v_DBAid_Database & "].[sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'chart'"
        v_RecordSet.Open v_SQL_Query, v_SQL_Conn, 0, 1
        If v_RecordSet.EOF Then
            WScript.Echo "3 mssql_" & v_InstanceName & " - Error occurred looping through charts."
        Else
            Do While (Not v_RecordSet.EOF)
                ' this loop executes each procedure in the [chart] schema
                ' Variables to manage pnp chart data. Initialize for each row of data being processed (i.e. per procedure call).
                v_SQLChecks_pnpData = ""
                v_SQLChecks_Row = 0
                v_SQLChecks_StateCheck = ""
                v_SQLChecks_Status = 0
                v_SQLChecks_Message = ""
                v_SQLChecks_CheckName = Replace(Mid(v_RecordSet.Fields.Item("proc"), 10), "]", "") ' gets procedure name sans schema & [] characters. E.g., final output is mssql_Instance_ValueFromThisVariablev_SQLChecks_CheckName
                v_SQLChecks_Query = "EXEC [" & v_DBAid_Database & "]." & v_RecordSet.Fields.Item("proc")
                v_SQLChecks_RecordSet.Open v_SQLChecks_Query, v_SQL_Conn, 0, 1
                Do While (Not v_SQLChecks_RecordSet.EOF)
                    ' this loop manages the multiple rows of chart data
                    ' Variables to manage pnp chart data. Initialize for each row of data being processed (i.e. each database or performance monitor counter).
                    v_SQLCharts_WarnExist = 0
                    v_SQLCharts_CritExist = 0
                    v_SQLCharts_Val = 0.0
                    v_SQLCharts_Warn = 0.0
                    v_SQLCharts_Crit = 0.0

                    ' Check for current value, warning threshold, critical threshold, pnp chart data.
                    ' chart.capacity has different columns returned compared to anything else, so has its own code to handle data.
                    If IsNull(v_SQLChecks_RecordSet.Fields.Item("val")) Then
                        v_SQLCharts_Val = -1.0
                    Else
                        v_SQLCharts_Val = v_SQLChecks_RecordSet.Fields.Item("val")
                    End If

                    If IsNull(v_SQLChecks_RecordSet.Fields.Item("warn")) Then
                        v_SQLCharts_WarnExist = 0
                        v_SQLCharts_Warn = -1.0
                    Else
                        v_SQLCharts_WarnExist = 1
                        v_SQLCharts_Warn = v_SQLChecks_RecordSet.Fields.Item("warn")
                    End If

                    If IsNull(v_SQLChecks_RecordSet.Fields.Item("crit")) Then
                        v_SQLCharts_CritExist = 0
                        v_SQLCharts_Crit = -1.0
                    Else
                        v_SQLCharts_CritExist = 1
                        v_SQLCharts_Crit = v_SQLChecks_RecordSet.Fields.Item("crit")
                    End If

                    If IsNull(v_SQLChecks_RecordSet.Fields.Item("pnp")) Then
                        v_SQLChecks_pnpData = ""
                    Else
                        v_SQLChecks_pnpData = v_SQLChecks_RecordSet.Fields.Item("pnp")
                    End If

                    ' If there is no chart data, skip the rest and move to next row in the data set.
                    If v_SQLChecks_pnpData = "" Then
                        v_SQLChecks_RecordSet.MoveNext
                        Exit Do
                    End If

                    ' Check to see if warning and critical thresholds are defined, then check current value v_SQLCharts_Val against threshold values for warning v_SQLCharts_Warn and critical v_SQLCharts_Crit.
                    If v_SQLCharts_CritExist = 1 AND v_SQLCharts_WarnExist = 1 Then
                        If CDbl(v_SQLCharts_Crit) >= CDbl(v_SQLCharts_Warn) Then
                            If CDbl(v_SQLCharts_Val) >= CDbl(v_SQLCharts_Crit) Then
                                ' Split the pnp data at the '=' character to form a new array, take the first element of the new array [0] which amounts to the object exceeding a threshold (e.g. dbname_ROWS_used) and remove the single quote characters.
                                v_SQLCharts_AlertValue = Split(v_SQLChecks_pnpData, "=")
                                v_SQLCharts_AlertValue(0) = Replace(v_SQLCharts_AlertValue(0), "'", "")

                                v_SQLChecks_StateCheck = v_SQLChecks_StateCheck + "CRITICAL - " & v_SQLCharts_AlertValue & "; "
                                v_SQLChecks_Status = "2"
                            ElseIf CDbl(v_SQLCharts_Val) >= CDbl(v_SQLCharts_Warn) AND v_SQLChecks_Status < 2 Then
                                v_SQLCharts_AlertValue = Split(v_SQLChecks_pnpData, "=")
                                v_SQLCharts_AlertValue(0) = Replace(v_SQLCharts_AlertValue(0), "'", "")
                                v_SQLChecks_StateCheck = v_SQLChecks_StateCheck + "WARNING - " & v_SQLCharts_AlertValue & "; "
                                v_SQLChecks_Status = "1"
                            End If
                        End If
                    ElseIf CDbl(v_SQLCharts_Crit) < CDbl(v_SQLCharts_Warn) Then
                        If CDbl(v_SQLCharts_Val) <= CDbl(v_SQLCharts_Crit) Then
                            v_SQLCharts_AlertValue = Split(v_SQLChecks_pnpData, "=")
                            v_SQLCharts_AlertValue(0) = Replace(v_SQLCharts_AlertValue(0), "'", "")
                            v_SQLChecks_StateCheck = v_SQLChecks_StateCheck + "CRITICAL - " & v_SQLCharts_AlertValue & "; "
                            v_SQLChecks_Status = "2"
                        ElseIf CDbl(v_SQLCharts_Val) <= CDbl(v_SQLCharts_Warn) AND v_SQLChecks_Status < 2 Then
                            v_SQLCharts_AlertValue = Split(v_SQLChecks_pnpData, "=")
                            v_SQLCharts_AlertValue(0) = Replace(v_SQLCharts_AlertValue(0), "'", "")
                            v_SQLChecks_StateCheck = v_SQLChecks_StateCheck + "WARNING - " & v_SQLCharts_AlertValue & "; "
                            v_SQLChecks_Status = "1"
                        End If
                    End If 

                    ' Concatenate all the pnp data into one text string for Checkmk to consume. Use pipe separator for subsequent rows being concatenated.
                    If v_SQLChecks_Row = 0 Then
                        v_SQLChecks_Message = v_SQLChecks_Message & v_SQLChecks_pnpData
                    Else
                        v_SQLChecks_Message = v_SQLChecks_Message & "|" & v_SQLChecks_pnpData
                    End If

                    v_SQLChecks_Row = v_SQLChecks_Row + 1
                    v_SQLChecks_RecordSet.MoveNext
                Loop

				If v_SQLChecks_StateCheck = "" Then
					v_SQLChecks_StateCheck = "OK"
				End If
				
                ' Write output for Checkmk agent to consume.
                WScript.Echo v_SQLChecks_Status & " mssql_" & v_SQLChecks_CheckName & "_" & v_InstanceName & " " & v_SQLChecks_Message & " " & v_SQLChecks_StateCheck

                v_SQLChecks_RecordSet.Close
                v_RecordSet.MoveNext
            Loop
        End If
        v_RecordSet.Close
        v_SQL_Conn.Close
    Next

    ' cleanup
    Set v_RecordSet = Nothing
    Set v_SQLChecks_RecordSet = Nothing
    Set v_SQL_Conn = Nothing
    Set v_WSH_Shell = Nothing
    
End Sub

Call Main()    