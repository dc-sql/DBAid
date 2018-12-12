Param(
    [parameter(Mandatory=$true)]
    [string[]]$SQLServer
)

CD $PSScriptRoot

#region: Functions
function convertto-htmlList {
[cmdletbinding()]
    Param(            
        [parameter(Mandatory=$true)]
        [xml]$xml
    )
    $line = '<ul>'

    foreach($element in $xml.table.row) {
        $parts = @()

        $line = $line + '<li>'

        foreach ($attribute in $element.Attributes) {
            $line = $line + $attribute.Name.Replace('_','\_') + '=' + $attribute.'#text'.Replace('_','\_') + '; '
        }

        $line = $line + '</li>'

        if ($element.codeblock) {
            $line = $line + '<code>' + $element.codeblock.Replace("|","&#124;") + '</code>'
        }
    }
    $line = $line + '</ul>'

    $line.Replace("`n",' ').Replace("`r",' ')
}

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
        $md.Append("|:---") | Out-Null
    }

    $md.AppendLine("|") | Out-Null

    foreach ($row in $inputObject.Rows) {
        foreach ($col in $columns) {
            if ($row[$col] -ilike '<table>*<row*</table>*') { 
                $line = '| ' + (convertto-htmlList $row[$col]) + ' '
            }
            else {
                $line = '| ' + $row[$col] + ' '
            }

            $md.Append($line) | Out-Null
        }

        $md.AppendLine("|") | Out-Null
    }

    $md.ToString()
}
#endregion 

$scripts = Get-ChildItem -Path ".\scripts\"

foreach ($srv in $SQLServer) {
    $collection = @()

    foreach($script in $scripts) {
        [array]$result = @() 
        $test = @('heading', 'subheading', 'comment')

        $result = Invoke-Sqlcmd -ServerInstance "$SQLServer" -Database 'master' -InputFile $script.Fullname -OutputAs DataTables -MaxCharLength 100000
    
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

    $toc = [System.Text.StringBuilder]::new()
    $md = [System.Text.StringBuilder]::new()
    $group = $collection | Sort-Object -Property heading, subheading | Group-Object -Property heading

    foreach ($section in $group) { 
        $heading = $section.Group.heading | Sort-Object -Unique
        $toc.AppendLine("[$heading](#$($heading.Replace(' ','-').ToLower()))  ") | Out-Null
        $md.AppendLine("## $heading  ") | Out-Null

        $subGroups = $section.Group | Select subheading, comment, datatable | Sort-Object -Property subheading | Group-Object -Property subheading

        foreach ($subSection in $subGroups) {
            $subHeading = $subSection.Group.subheading | Sort-Object -Unique
        
            $toc.AppendLine("&nbsp;&nbsp;&nbsp;&nbsp;[$subHeading](#$($subHeading.Replace(' ','-').ToLower()))  ") | Out-Null
            $md.AppendLine("### $subHeading  ") | Out-Null

            $dataTables = $subSection.Group | Select comment, datatable

            foreach ($table in $dataTables) {
                $comment = $table.comment
                $datatable = $table.datatable

                if ($comment.Length -gt 0) {
                    $md.AppendLine("$comment  ") | Out-Null
                }
            
                $md.AppendLine("") | Out-Null #Blank line needed to render table

                $ret = convertto-markdownTable $datatable
                $md.Append($ret) | Out-Null
            }
        }
    }

    "# [$SQLServer]" | Out-File -Path ".\$($SQLServer.Replace('\','@'))" -Force
    '' | Out-File -Path ".\$($SQLServer.Replace('\','@'))" -Append
    $toc.ToString() | Out-File -Path ".\$($SQLServer.Replace('\','@'))" -Append
    '' | Out-File -Path ".\$($SQLServer.Replace('\','@'))" -Append
    $md.ToString() | Out-File -Path ".\$($SQLServer.Replace('\','@'))" -Append
}
