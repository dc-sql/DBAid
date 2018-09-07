$getProcedureSql = "SELECT 'EXEC [configg].' + QUOTENAME([name]) AS [procedure] FROM sys.objects WHERE[type] = 'P' AND SCHEMA_NAME([schema_id]) = 'configg'"

#region: Example Stored Procedure code
<# This PowerShell script expects two datatables. The first must select heading, subheading, and comment. You can pass blank strings if you like " '' as [comment] ". The second is the datatable you want converted to a markdown table

CREATE PROCEDURE [configg].[get_instance_databases]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'Instance' AS [heading], 'Databases' AS [subheading], 'This is a list of databases on the instance' AS [comment]
    
    SELECT * FROM sys.databases
END
GO
#>
#endregion

#region: Functions

function convertto-markdownTable {
    [cmdletbinding()]
    Param(            
        [parameter(Mandatory=$true)]
        [system.Data.DataTable]$inputObject
    )

    $md = [System.Text.StringBuilder]::new()

    $columns = $inputObject.Columns.ColumnName

    # Output Headers
    foreach($col in $columns) {
        $md.Append("| $col ") | Out-Null
    }

    $md.AppendLine("|") | Out-Null

    foreach($col in $columns) {
        $md.Append("|---") | Out-Null
    }

    $md.AppendLine("|") | Out-Null

    foreach ($row in $inputObject.Rows) {
        foreach ($col in $columns) {
            $line = '| ' + $row[$col] + ' '
            $md.Append($line) | Out-Null
        }

        $md.AppendLine("|") | Out-Null
    }

    $md.ToString()
}
#endregion 

$procedures = Invoke-Sqlcmd -ServerInstance . -Database '_dbaid' -Query $getProcedureSql
$collection = @()

foreach($proc in $procedures) {
    [array]$result = @() 
    $test = @('heading', 'subheading', 'comment')

    $result = Invoke-Sqlcmd -ServerInstance . -Database '_dbaid' -Query $proc.procedure -OutputAs DataTables
    
    if ($result) {
        if ($result.Length -eq 2) {
            if (-not (Compare-Object -ReferenceObject $result[0].Columns.ColumnName -DifferenceObject $test)) {

                if ($result[1]) {
                    $row = New-Object PSObject -property @{heading = $result[0].heading;subheading = $result[0].subheading;comment = $result[0].comment;datatable = $result[1]}

                    $collection += $row
                }
            }
        }
    }
}

$md = [System.Text.StringBuilder]::new()
$group = $collection | Group-Object -Property heading

foreach ($section in $group) { 
    $heading = $section.Group.heading | Sort-Object -Unique
    $md.AppendLine("# $heading  ") | Out-Null

    $subGroups = $section.Group | Select subheading, comment, datatable | Group-Object -Property subheading

    foreach ($subSection in $subGroups) {
        $subHeading = $subSection.Group.subheading | Sort-Object -Unique
        $md.AppendLine("## $subHeading  ") | Out-Null

        $dataTables = $subSection.Group | Select comment, datatable

        foreach ($table in $dataTables) {
            $comment = $table.comment
            $datatable = $table.datatable

            if ($comment.Length -gt 0) {
                $md.AppendLine("$comment  ") | Out-Null
            }

            $ret = convertto-markdownTable $datatable
            $md.Append($ret) | Out-Null
        }
    }
}

$md.ToString()