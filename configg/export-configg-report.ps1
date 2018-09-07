#region: functions
function Convert-MarkdownTable {
    [cmdletbinding()]
    Param(            
        [parameter(Mandatory=$true)]
        [system.Data.DataTable]$inputObject
    )

    $columns = $inputObject.Columns.ColumnName

    # Output Headers
    foreach($col in $columns) {
        $output += "| $col "
    }

    $output += "|`n"

    foreach($col in $columns) {
        $output += "|---"
    }

    $output += "|`n"
    
    # Output Row Data
    foreach ($row in $inputObject.Rows) {
        foreach ($col in $columns) {
            $output += "| " + $row[$col] + " "
        }

        $output += "|`n"
    }

    Write-Host $output
}
#endregion 

$getProcedureSql = "SELECT 'EXEC [configg].' + QUOTENAME([name]) AS [procedure] FROM sys.objects WHERE[type] = 'P' AND SCHEMA_NAME([schema_id]) = 'configg'"

$procedures = Invoke-Sqlcmd -ServerInstance . -Database '_dbaid' -Query $getProcedureSql
$collection = @()

foreach($proc in $procedures) {
    [array]$result = @() 
    $test = @('group', 'heading', 'comment')

    $result = Invoke-Sqlcmd -ServerInstance . -Database '_dbaid' -Query $proc.procedure -OutputAs DataTables
    
    if ($result) {
        if ($result.Length -eq 2) {
            if (-not (Compare-Object -ReferenceObject $result[0].Columns.ColumnName -DifferenceObject $test)) {

                if ($result[1]) {
                    $row = New-Object PSObject -property @{group = $result[0].group;heading = $result[0].heading;comment = $result[0].comment;datatable = $result[1]}

                    $collection += $row
                }
            }
        }
    }
}

$groups = $collection.group | Sort-Object -Property group, heading -Unique

foreach ($group in $groups) { 
    Write-Host "# $group  "
    
    $headings = $collection | Where { $_.group -eq $group } | Sort-Object -Property group, heading -Unique | Select heading, comment

    foreach ($block in $headings) {
            Write-Host "## $($block.heading)  "
            Write-Host "$($block.comment)  "
            Write-Host "  "

            $tables = $collection | Where { $_.group -eq $group -and $_.heading -eq $block.heading } | Sort-Object -Property group, heading | Select datatable

            foreach ($dt in $tables) {
                convertto-markdownTable $dt.datatable
            }
    }
}